alter table public.orders drop constraint orders_status_check;
alter table public.orders add constraint orders_status_check
  check (status in ('Pending', 'Confirmed', 'Ready for Delivery', 'Assigned',
                    'Out for Delivery', 'Delivered', 'Cancelled'));
alter table public.deliveries drop constraint deliveries_status_check;
alter table public.deliveries add constraint deliveries_status_check
  check (status in ('Pending', 'Assigned', 'Out for Delivery', 'Delivered', 'Failed', 'Returned'));
alter table public.deliveries
  add column delivered_quantity integer check (delivered_quantity > 0),
  add column returned_empty integer check (returned_empty between 0 and delivered_quantity);

create function public.advance_booking(p_order_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_agency_staff() then raise exception 'Not authorized'; end if;
  update public.orders set status = p_status
  where id = p_order_id and (
    (status = 'Pending' and p_status = 'Confirmed') or
    (status = 'Confirmed' and p_status = 'Ready for Delivery')
  );
  if not found then raise exception 'Booking status has changed. Refresh and try again'; end if;
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
  if p_status not in ('Pending', 'Assigned', 'Out for Delivery', 'Failed', 'Returned') then
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
    else v_order_status
  end;
  update public.orders set status = v_order_status where id = p_order_id and status <> 'Cancelled';
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
      or v_empty < 0 or v_empty > v_quantity then
    raise exception 'Record the booked quantity and a valid empty count';
  end if;
  update public.inventory
    set filled = filled - v_quantity, empty = empty + v_empty,
        booked = booked - v_quantity, delivered = delivered + v_quantity
    where product_id = v_product_id and filled >= v_quantity and booked >= v_quantity;
  if not found then raise exception 'Booked inventory is not available'; end if;
  update public.orders set status = 'Delivered' where id = p_order_id;
  update public.deliveries set status = 'Delivered', staff_id = p_staff_id,
      delivered_at = now(), delivered_quantity = v_quantity, returned_empty = v_empty, notes = coalesce(p_notes, '')
    where order_id = p_order_id;
  insert into public.inventory_movements(product_id, kind, filled_change, empty_change, booked_change, note)
    values (v_product_id, 'Delivery', -v_quantity, v_empty, -v_quantity, v_order_number);
end
$$;

create or replace function public.complete_delivery(
  p_order_id uuid, p_staff_id uuid default null, p_notes text default ''
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  perform public.complete_delivery_with_counts(p_order_id, p_staff_id, p_notes);
end
$$;

revoke all on function public.advance_booking(uuid, text) from public, anon;
grant execute on function public.advance_booking(uuid, text) to authenticated;
revoke all on function public.complete_delivery_with_counts(uuid, uuid, text, integer, integer) from public, anon;
grant execute on function public.complete_delivery_with_counts(uuid, uuid, text, integer, integer) to authenticated;
