alter table public.orders alter column status set default 'Ready for Delivery';
update public.orders set status = 'Ready for Delivery' where status in ('Pending', 'Confirmed');

alter table public.deliveries
  add column damaged_empty integer not null default 0 check (damaged_empty >= 0),
  add constraint deliveries_empty_return_total_check
    check (damaged_empty = 0 or (
      returned_empty is not null and delivered_quantity is not null
      and returned_empty + damaged_empty <= delivered_quantity
    ));

create or replace function public.complete_delivery_with_returns(
  p_order_id uuid, p_staff_id uuid default null, p_notes text default '',
  p_delivered_quantity integer default null, p_returned_empty integer default null,
  p_damaged_empty integer default 0
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_order_status text;
  v_product_id uuid;
  v_quantity integer;
  v_order_number text;
  v_empty integer;
begin
  if not public.is_agency_staff() then raise exception 'Not authorized'; end if;
  select o.status, o.order_number, i.product_id, i.quantity
    into v_order_status, v_order_number, v_product_id, v_quantity
  from public.orders o join public.order_items i on i.order_id = o.id
  where o.id = p_order_id for update of o;
  if not found or v_order_status = 'Cancelled' then raise exception 'Order is unavailable for delivery'; end if;
  if v_order_status = 'Delivered' then raise exception 'Delivery already completed'; end if;
  if p_staff_id is not null and not exists (
    select 1 from public.profiles where id = p_staff_id and active and role = 'Staff'
  ) then raise exception 'Delivery staff is unavailable'; end if;
  if p_delivered_quantity is not null and v_order_status in ('Pending', 'Confirmed') then
    raise exception 'Mark the booking ready for delivery first';
  end if;
  v_empty := coalesce(p_returned_empty, v_quantity);
  if coalesce(p_delivered_quantity, v_quantity) <> v_quantity
      or v_empty < 0 or p_damaged_empty is null or p_damaged_empty < 0
      or v_empty + p_damaged_empty > v_quantity then
    raise exception 'Record the booked quantity and a valid empty count';
  end if;
  update public.inventory
    set filled = filled - v_quantity, empty = empty + v_empty, damaged = damaged + p_damaged_empty,
        booked = booked - v_quantity, delivered = delivered + v_quantity
    where product_id = v_product_id and filled >= v_quantity and booked >= v_quantity;
  if not found then raise exception 'Booked inventory is not available'; end if;
  update public.orders set status = 'Delivered' where id = p_order_id;
  update public.deliveries set status = 'Delivered', staff_id = p_staff_id,
      delivered_at = now(), delivered_quantity = v_quantity, returned_empty = v_empty, damaged_empty = p_damaged_empty, notes = coalesce(p_notes, '')
    where order_id = p_order_id;
  if not found then raise exception 'Delivery not found'; end if;
  insert into public.inventory_movements(product_id, kind, filled_change, empty_change, damaged_change, booked_change, note)
    values (v_product_id, 'Delivery', -v_quantity, v_empty, p_damaged_empty, -v_quantity, v_order_number);
end
$$;

create function public.record_empty_returns(
  p_order_id uuid, p_serviceable integer, p_damaged integer
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_order public.orders%rowtype;
  v_delivery public.deliveries%rowtype;
  v_product_id uuid;
  v_serviceable_delta integer;
  v_damaged_delta integer;
begin
  if not public.is_agency_staff() then raise exception 'Not authorized'; end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if not found or v_order.status <> 'Delivered' then raise exception 'Order is not delivered'; end if;
  select * into v_delivery from public.deliveries where order_id = p_order_id for update;
  if not found or v_delivery.status <> 'Delivered' or v_delivery.returned_empty is null
      or v_delivery.delivered_quantity is null or p_serviceable is null or p_damaged is null
      or p_serviceable < v_delivery.returned_empty or p_damaged < v_delivery.damaged_empty
      or p_serviceable + p_damaged > v_delivery.delivered_quantity then
    raise exception 'Enter valid return totals within the delivered quantity';
  end if;
  v_serviceable_delta := p_serviceable - v_delivery.returned_empty;
  v_damaged_delta := p_damaged - v_delivery.damaged_empty;
  if v_serviceable_delta = 0 and v_damaged_delta = 0 then return; end if;
  select product_id into v_product_id from public.order_items where order_id = p_order_id;
  update public.inventory set empty = empty + v_serviceable_delta,
      damaged = damaged + v_damaged_delta where product_id = v_product_id;
  if not found then raise exception 'Inventory record not found'; end if;
  update public.deliveries set returned_empty = p_serviceable, damaged_empty = p_damaged
    where order_id = p_order_id;
  insert into public.inventory_movements(product_id, kind, empty_change, damaged_change, note)
    values (v_product_id, 'Empty return', v_serviceable_delta, v_damaged_delta, v_order.order_number);
end
$$;

revoke all on function public.complete_delivery_with_returns(uuid, uuid, text, integer, integer, integer) from public, anon;
grant execute on function public.complete_delivery_with_returns(uuid, uuid, text, integer, integer, integer) to authenticated;
revoke all on function public.record_empty_returns(uuid, integer, integer) from public, anon;
grant execute on function public.record_empty_returns(uuid, integer, integer) to authenticated;

create or replace function public.update_delivery_status(
  p_order_id uuid, p_status text, p_staff_id uuid default null, p_notes text default ''
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_current text;
  v_order_status text;
begin
  if not public.is_agency_staff() then raise exception 'Not authorized'; end if;
  if p_status is null or p_status not in ('Pending', 'Assigned', 'Out for Delivery', 'Failed', 'Returned') then
    raise exception 'Use complete_delivery to mark a delivery complete';
  end if;
  select status into v_order_status from public.orders where id = p_order_id for update;
  if not found or v_order_status in ('Cancelled', 'Delivered') then
    raise exception 'Order is unavailable for delivery';
  end if;
  if p_status <> 'Pending' and v_order_status in ('Pending', 'Confirmed') then
    raise exception 'Mark the booking ready for delivery first';
  end if;
  if p_status in ('Assigned', 'Out for Delivery') and p_staff_id is null then
    raise exception 'Select delivery staff first';
  end if;
  if p_status in ('Failed', 'Returned') and coalesce(trim(p_notes), '') = '' then
    raise exception 'Enter a reason for the delivery outcome';
  end if;
  select status into v_current from public.deliveries where order_id = p_order_id for update;
  if not found then raise exception 'Delivery not found'; end if;
  if v_current = 'Delivered' then raise exception 'A completed delivery cannot be moved back'; end if;
  if p_staff_id is not null and not exists (
    select 1 from public.profiles where id = p_staff_id and active and role = 'Staff'
  ) then raise exception 'Delivery staff is unavailable'; end if;
  update public.deliveries set status = p_status, staff_id = p_staff_id, notes = coalesce(p_notes, '')
    where order_id = p_order_id;
  v_order_status := case p_status
    when 'Assigned' then 'Assigned'
    when 'Out for Delivery' then 'Out for Delivery'
    when 'Failed' then 'Ready for Delivery'
    when 'Returned' then 'Ready for Delivery'
    else 'Ready for Delivery'
  end;
  update public.orders set status = v_order_status where id = p_order_id and status <> 'Cancelled';
end
$$;

