alter table public.orders
  add column delivery_charge numeric(12, 2) not null default 0 check (delivery_charge >= 0),
  add column discount numeric(12, 2) not null default 0 check (discount >= 0);

create or replace function public.create_priced_order(
  p_customer_id uuid, p_product_id uuid, p_quantity integer, p_notes text default '', p_delivery_charge numeric default 0, p_discount numeric default 0
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_order_id uuid;
  v_order_number text;
  v_price numeric(12, 2);
  v_available integer;
begin
  if not public.is_agency_staff() then raise exception 'Not authorized'; end if;
  if p_quantity <= 0 then raise exception 'Quantity must be greater than zero'; end if;
  if not exists (select 1 from public.customers where id = p_customer_id and active) then
    raise exception 'Customer is unavailable';
  end if;
  select price into v_price from public.products where id = p_product_id and active;
  if v_price is null then raise exception 'Product is unavailable'; end if;
  if p_delivery_charge is null or p_discount is null
      or p_delivery_charge::text = 'NaN' or p_discount::text = 'NaN'
      or p_delivery_charge < 0 or p_discount < 0
      or p_delivery_charge <> round(p_delivery_charge, 2) or p_discount <> round(p_discount, 2)
      or p_discount > (v_price * p_quantity + p_delivery_charge) then
    raise exception 'Enter valid charges and a discount within the booking total';
  end if;
  select filled - booked into v_available from public.inventory where product_id = p_product_id for update;
  if v_available is null or v_available < p_quantity then raise exception 'Not enough filled cylinders available'; end if;

  v_order_number := 'GA-' || to_char(now(), 'YYMMDD') || '-' ||
    lpad(nextval('public.order_number_seq')::text, 4, '0');
  insert into public.orders(order_number, customer_id, notes, delivery_charge, discount)
    values (v_order_number, p_customer_id, coalesce(p_notes, ''), p_delivery_charge, p_discount)
    returning id into v_order_id;
  insert into public.order_items(order_id, product_id, quantity, unit_price)
    values (v_order_id, p_product_id, p_quantity, v_price);
  update public.inventory set booked = booked + p_quantity where product_id = p_product_id;
  insert into public.inventory_movements(product_id, kind, booked_change, note)
    values (p_product_id, 'Order booked', p_quantity, v_order_number);
  insert into public.deliveries(order_id) values (v_order_id);
  return v_order_id;
end
$$;

create or replace function public.edit_priced_order(
  p_order_id uuid, p_customer_id uuid, p_product_id uuid, p_quantity integer,
  p_notes text default '', p_delivery_charge numeric default 0, p_discount numeric default 0
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_old_product uuid;
  v_old_quantity integer;
  v_old_customer uuid;
  v_paid numeric;
  v_status text;
  v_price numeric(12, 2);
  v_available integer;
  v_order_number text;
begin
  if not public.is_agency_staff() then raise exception 'Not authorized'; end if;
  if p_quantity <= 0 then raise exception 'Quantity must be greater than zero'; end if;
  select o.status, o.order_number, i.product_id, i.quantity, o.customer_id
    into v_status, v_order_number, v_old_product, v_old_quantity, v_old_customer
  from public.orders o join public.order_items i on i.order_id = o.id
  where o.id = p_order_id for update of o;
  if not found or v_status in ('Delivered', 'Cancelled') then raise exception 'Order cannot be edited'; end if;
  if not exists (select 1 from public.customers where id = p_customer_id and active) then
    raise exception 'Customer is unavailable';
  end if;
  select price into v_price from public.products where id = p_product_id and active;
  if v_price is null then raise exception 'Product is unavailable'; end if;
  if p_delivery_charge is null or p_discount is null
      or p_delivery_charge::text = 'NaN' or p_discount::text = 'NaN'
      or p_delivery_charge < 0 or p_discount < 0
      or p_delivery_charge <> round(p_delivery_charge, 2) or p_discount <> round(p_discount, 2)
      or p_discount > (v_price * p_quantity + p_delivery_charge) then
    raise exception 'Enter valid charges and a discount within the booking total';
  end if;
  select coalesce(sum(amount), 0) into v_paid from public.payments where order_id = p_order_id;
  if v_paid > 0 and (v_old_customer <> p_customer_id or
      v_paid > v_price * p_quantity + p_delivery_charge - p_discount) then
    raise exception 'The booking change conflicts with recorded payments';
  end if;

  perform 1 from public.inventory where product_id in (v_old_product, p_product_id)
    order by product_id for update;

  if v_old_product = p_product_id then
    select filled - booked + v_old_quantity into v_available
      from public.inventory where product_id = p_product_id for update;
  else
    update public.inventory set booked = booked - v_old_quantity where product_id = v_old_product;
    insert into public.inventory_movements(product_id, kind, booked_change, note)
      values (v_old_product, 'Order changed', -v_old_quantity, v_order_number);
    select filled - booked into v_available from public.inventory where product_id = p_product_id for update;
  end if;
  if v_available is null or v_available < p_quantity then raise exception 'Not enough filled cylinders available'; end if;
  if v_old_product = p_product_id then
    update public.inventory set booked = booked - v_old_quantity + p_quantity where product_id = p_product_id;
    insert into public.inventory_movements(product_id, kind, booked_change, note)
      values (p_product_id, 'Order changed', p_quantity - v_old_quantity, v_order_number);
  else
    update public.inventory set booked = booked + p_quantity where product_id = p_product_id;
    insert into public.inventory_movements(product_id, kind, booked_change, note)
      values (p_product_id, 'Order changed', p_quantity, v_order_number);
  end if;
  update public.order_items set product_id = p_product_id, quantity = p_quantity, unit_price = v_price
    where order_id = p_order_id;
  update public.orders
    set customer_id = p_customer_id, notes = coalesce(p_notes, ''),
        delivery_charge = p_delivery_charge, discount = p_discount
    where id = p_order_id;
end
$$;

create or replace function public.edit_order(
  p_order_id uuid, p_customer_id uuid, p_product_id uuid, p_quantity integer,
  p_notes text default ''
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_charge numeric;
  v_discount numeric;
begin
  select delivery_charge, discount into v_charge, v_discount
    from public.orders where id = p_order_id for update;
  perform public.edit_priced_order(p_order_id, p_customer_id, p_product_id,
    p_quantity, p_notes, v_charge, v_discount);
end
$$;
create or replace function public.record_payment(
  p_order_id uuid, p_amount numeric, p_method text, p_payment_date timestamptz default now(),
  p_reference text default '', p_notes text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_total numeric(12, 2);
  v_paid numeric(12, 2);
  v_status text;
  v_payment_id uuid;
begin
  if not public.is_agency_staff() then raise exception 'Not authorized'; end if;
  if p_amount is null or p_amount <= 0 or p_amount <> round(p_amount, 2) or p_amount::text = 'NaN' then raise exception 'Payment amount must be greater than zero'; end if;
  if not exists (select 1 from public.agency_settings where id = 1 and p_method = any(payment_methods)) then
    raise exception 'This payment method is disabled in Settings';
  end if;
  select o.status, i.quantity * i.unit_price + o.delivery_charge - o.discount into v_status, v_total
  from public.orders o join public.order_items i on i.order_id = o.id
  where o.id = p_order_id for update of o;
  if not found or v_status = 'Cancelled' then raise exception 'Order is unavailable for payment'; end if;
  select coalesce(sum(amount), 0) into v_paid from public.payments where order_id = p_order_id;
  if p_amount > v_total - v_paid then raise exception 'Payment exceeds the remaining order balance'; end if;
  insert into public.payments(order_id, amount, method, payment_date, reference, notes)
    values (p_order_id, p_amount, p_method, coalesce(p_payment_date, now()),
            coalesce(p_reference, ''), coalesce(p_notes, ''))
    returning id into v_payment_id;
  return v_payment_id;
end
$$;


revoke all on function public.create_priced_order(uuid, uuid, integer, text, numeric, numeric) from public, anon;
grant execute on function public.create_priced_order(uuid, uuid, integer, text, numeric, numeric) to authenticated;
revoke all on function public.edit_priced_order(uuid, uuid, uuid, integer, text, numeric, numeric) from public, anon;
grant execute on function public.edit_priced_order(uuid, uuid, uuid, integer, text, numeric, numeric) to authenticated;
