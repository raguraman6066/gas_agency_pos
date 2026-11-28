alter table public.inventory add column damaged integer not null default 0 check (damaged >= 0);
alter table public.inventory_movements add column damaged_change integer not null default 0;

create function public.record_stock_movement(
  p_product_id uuid, p_filled_change integer, p_empty_change integer,
  p_note text, p_kind text, p_damaged_change integer
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_agency_admin() then raise exception 'Administrator access required'; end if;
  if coalesce(trim(p_note), '') = '' or not coalesce(case p_kind
    when 'Adjustment' then p_damaged_change = 0 and (p_filled_change <> 0 or p_empty_change <> 0)
    when 'Distributor receipt' then p_filled_change >= 0 and p_empty_change >= 0
      and (p_filled_change > 0 or p_empty_change > 0) and p_damaged_change = 0
    when 'Exchange' then p_filled_change < 0 and p_empty_change = -p_filled_change
      and p_damaged_change = 0
    when 'Damage' then p_filled_change <= 0 and p_empty_change <= 0
      and p_damaged_change > 0 and p_damaged_change = -p_filled_change - p_empty_change
    else false end, false) then raise exception 'Invalid stock movement or missing reason'; end if;
  update public.inventory
    set filled = filled + p_filled_change, empty = empty + p_empty_change,
        damaged = damaged + p_damaged_change
    where product_id = p_product_id and filled + p_filled_change >= booked
      and empty + p_empty_change >= 0 and damaged + p_damaged_change >= 0;
  if not found then raise exception 'Adjustment would create negative or already-booked stock'; end if;
  insert into public.inventory_movements(product_id, kind, filled_change, empty_change, damaged_change, note)
    values (p_product_id, p_kind, p_filled_change, p_empty_change, p_damaged_change, p_note);
end
$$;

alter table public.payments add column refund_of uuid references public.payments(id);
alter table public.payments drop constraint payments_amount_check;
alter table public.payments add constraint payments_amount_check check (
  (amount > 0 and refund_of is null) or (amount < 0 and refund_of is not null)
);
create index payments_refund_of_idx on public.payments (refund_of) where refund_of is not null;

create function public.record_refund(p_payment_id uuid, p_amount numeric, p_notes text)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_original public.payments%rowtype;
  v_refunded numeric;
  v_id uuid;
begin
  if not public.is_agency_staff() then raise exception 'Not authorized'; end if;
  if p_amount is null or p_amount <= 0 or p_amount <> round(p_amount, 2)
      or p_amount::text = 'NaN' or coalesce(trim(p_notes), '') = '' then
    raise exception 'Enter a positive refund amount and a reason';
  end if;
  select * into v_original from public.payments where id = p_payment_id and refund_of is null;
  if not found then raise exception 'Original payment not found'; end if;
  perform 1 from public.orders where id = v_original.order_id for update;
  select coalesce(-sum(amount), 0) into v_refunded from public.payments where refund_of = p_payment_id;
  if p_amount > v_original.amount - v_refunded then raise exception 'Refund exceeds refundable amount'; end if;
  insert into public.payments(order_id, amount, method, refund_of, notes)
    values (v_original.order_id, -p_amount, v_original.method, p_payment_id, trim(p_notes))
    returning id into v_id;
  return v_id;
end
$$;

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
  update public.inventory set booked = booked - v_quantity where product_id = v_product_id;
  update public.deliveries
    set status = 'Failed', notes = 'Order cancelled'
    where order_id = p_order_id and status <> 'Delivered';
  insert into public.inventory_movements(product_id, kind, booked_change, note)
    values (v_product_id, 'Order cancelled', -v_quantity, v_order_number);
end
$$;


revoke all on function public.record_stock_movement(uuid, integer, integer, text, text, integer) from public, anon;
grant execute on function public.record_stock_movement(uuid, integer, integer, text, text, integer) to authenticated;
revoke all on function public.record_refund(uuid, numeric, text) from public, anon;
grant execute on function public.record_refund(uuid, numeric, text) to authenticated;
