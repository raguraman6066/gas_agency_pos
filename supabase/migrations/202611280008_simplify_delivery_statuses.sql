-- Keep existing deliveries and notes while simplifying the operational statuses.
update public.deliveries
set status = case
      when status in ('Assigned', 'Out for Delivery') and staff_id is not null then 'Assigned'
      else 'Pending'
    end,
    staff_id = case
      when status in ('Assigned', 'Out for Delivery') then staff_id
      else null
    end
where status not in ('Pending', 'Delivered')
   or (status = 'Pending' and staff_id is not null);

update public.orders o
set status = case when d.status = 'Assigned' then 'Assigned' else 'Ready for Delivery' end
from public.deliveries d
where d.order_id = o.id
  and o.status not in ('Delivered', 'Cancelled')
  and o.status <> case when d.status = 'Assigned' then 'Assigned' else 'Ready for Delivery' end;

alter table public.deliveries drop constraint deliveries_status_check;
alter table public.deliveries add constraint deliveries_status_check
  check (status in ('Pending', 'Assigned', 'Delivered'));

create or replace function public.cancel_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_status text;
  v_product_id uuid;
  v_quantity integer;
  v_order_number text;
begin
  if not public.is_agency_staff() then raise exception 'Not authorized'; end if;
  select o.status, o.order_number, i.product_id, i.quantity
    into v_status, v_order_number, v_product_id, v_quantity
  from public.orders o join public.order_items i on i.order_id = o.id
  where o.id = p_order_id for update of o;
  if not found then raise exception 'Order not found'; end if;
  if v_status = 'Delivered' then raise exception 'A delivered order cannot be cancelled'; end if;
  if v_status = 'Cancelled' then return; end if;
  if (select coalesce(sum(amount), 0) from public.payments where order_id = p_order_id) > 0 then
    raise exception 'An order with recorded payments cannot be cancelled';
  end if;
  update public.orders set status = 'Cancelled' where id = p_order_id;
  update public.inventory set booked = booked - v_quantity
    where product_id = v_product_id and booked >= v_quantity;
  if not found then raise exception 'Booked inventory is not available'; end if;
  update public.deliveries
    set status = 'Pending', staff_id = null
    where order_id = p_order_id and status <> 'Delivered';
  insert into public.inventory_movements(product_id, kind, booked_change, note)
    values (v_product_id, 'Order cancelled', -v_quantity, v_order_number);
end
$$;


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
  if p_status is null or p_status not in ('Pending', 'Assigned') then
    raise exception 'Use complete_delivery to mark a delivery complete';
  end if;
  select status into v_order_status from public.orders where id = p_order_id for update;
  if not found or v_order_status in ('Cancelled', 'Delivered') then
    raise exception 'Order is unavailable for delivery';
  end if;
  if p_status = 'Pending' then
    p_staff_id := null;
  elsif p_staff_id is null then
    raise exception 'Select delivery staff first';
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
    else 'Ready for Delivery'
  end;
  update public.orders set status = v_order_status where id = p_order_id and status <> 'Cancelled';
end
$$;


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
  v_delivery_status text;
  v_assigned_staff uuid;
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
  select status, staff_id into v_delivery_status, v_assigned_staff
    from public.deliveries where order_id = p_order_id for update;
  if not found or v_delivery_status <> 'Assigned' then
    raise exception 'Assign the delivery before marking it delivered';
  end if;
  p_staff_id := coalesce(p_staff_id, v_assigned_staff);
  if p_staff_id is null or not exists (
    select 1 from public.profiles where id = p_staff_id and active and role = 'Staff'
  ) then raise exception 'Delivery staff is unavailable'; end if;
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

create or replace function public.complete_delivery_with_counts(
  p_order_id uuid, p_staff_id uuid default null, p_notes text default '',
  p_delivered_quantity integer default null, p_returned_empty integer default null
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  perform public.complete_delivery_with_returns(
    p_order_id, p_staff_id, p_notes, p_delivered_quantity, p_returned_empty
  );
end
$$;
