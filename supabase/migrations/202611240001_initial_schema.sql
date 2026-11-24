create extension if not exists pgcrypto;
create sequence if not exists public.order_number_seq start with 1;

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  full_name text not null,
  email text not null unique,
  phone text not null default '',
  role text not null default 'Staff' check (role in ('Admin', 'Staff')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  consumer_number text not null unique,
  phone text not null,
  alternative_phone text not null default '',
  address text not null,
  area text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null check (type in ('Domestic', 'Commercial')),
  size_kg integer not null check (size_kg > 0),
  price numeric(12, 2) not null check (price > 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  customer_id uuid not null references public.customers(id),
  status text not null default 'Pending'
    check (status in ('Pending', 'Confirmed', 'Assigned', 'Out for Delivery', 'Delivered', 'Cancelled')),
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity integer not null check (quantity > 0),
  unit_price numeric(12, 2) not null check (unit_price > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (order_id)
);

create table if not exists public.deliveries (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id),
  staff_id uuid references public.profiles(id) on delete set null,
  status text not null default 'Pending'
    check (status in ('Pending', 'Assigned', 'Out for Delivery', 'Delivered', 'Failed')),
  delivered_at timestamptz,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory (
  product_id uuid primary key references public.products(id),
  filled integer not null default 0 check (filled >= 0),
  empty integer not null default 0 check (empty >= 0),
  booked integer not null default 0 check (booked >= 0 and booked <= filled),
  delivered integer not null default 0 check (delivered >= 0),
  minimum integer not null default 10 check (minimum >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  kind text not null,
  filled_change integer not null default 0,
  empty_change integer not null default 0,
  booked_change integer not null default 0,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id),
  amount numeric(12, 2) not null check (amount > 0),
  method text not null check (method in ('Cash', 'UPI', 'Bank Transfer', 'Other')),
  payment_date timestamptz not null default now(),
  reference text not null default '',
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists customers_name_idx on public.customers (name);
create index if not exists customers_phone_idx on public.customers (phone);
create unique index if not exists profiles_email_lower_idx on public.profiles (lower(email));
create index if not exists orders_customer_date_idx on public.orders (customer_id, created_at desc);
create index if not exists orders_status_date_idx on public.orders (status, created_at desc);
create index if not exists deliveries_status_idx on public.deliveries (status);
create index if not exists payments_order_date_idx on public.payments (order_id, payment_date desc);
create index if not exists payments_date_idx on public.payments (payment_date desc);
create index if not exists inventory_movements_product_date_idx on public.inventory_movements (product_id, created_at desc);

create or replace function public.current_agency_role()
returns text
language sql
stable
security definer
set search_path = public, auth
as $$
  select p.role
  from public.profiles p
  where p.active
    and lower(p.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  limit 1
$$;

create or replace function public.is_agency_staff()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select public.current_agency_role() in ('Admin', 'Staff')
$$;

create or replace function public.is_agency_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select public.current_agency_role() = 'Admin'
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end
$$;

create or replace function public.create_product_inventory()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.inventory(product_id) values (new.id)
  on conflict (product_id) do nothing;
  return new;
end
$$;

create or replace function public.attach_auth_user_to_profile()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if new.auth_user_id is null then
    update public.profiles
      set auth_user_id = (
        select u.id from auth.users u where lower(u.email) = lower(new.email) limit 1
      )
      where id = new.id and exists (
        select 1 from auth.users u where lower(u.email) = lower(new.email)
      );
  end if;
  return new;
end
$$;

create or replace function public.attach_profile_to_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
    set auth_user_id = new.id
    where lower(email) = lower(new.email) and auth_user_id is null;
  return new;
end
$$;

drop trigger if exists create_inventory_for_product on public.products;
create trigger create_inventory_for_product
  after insert on public.products
  for each row execute function public.create_product_inventory();
drop trigger if exists attach_auth_user_to_profile on public.profiles;
create trigger attach_auth_user_to_profile
  after insert or update of email on public.profiles
  for each row execute function public.attach_auth_user_to_profile();
drop trigger if exists attach_profile_to_auth_user on auth.users;
create trigger attach_profile_to_auth_user
  after insert or update of email on auth.users
  for each row execute function public.attach_profile_to_auth_user();

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles', 'customers', 'products', 'orders', 'order_items', 'deliveries',
    'inventory', 'inventory_movements', 'payments'
  ]
  loop
    execute format('drop trigger if exists set_updated_at on public.%I', table_name);
    execute format(
      'create trigger set_updated_at before update on public.%I for each row execute function public.set_updated_at()',
      table_name
    );
  end loop;
end
$$;

alter table public.profiles enable row level security;
alter table public.customers enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.deliveries enable row level security;
alter table public.inventory enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.payments enable row level security;

create policy "Profiles visible to account or admins" on public.profiles
  for select to authenticated
  using (
    lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    or public.is_agency_staff()
  );
create policy "Admins manage profiles" on public.profiles
  for all to authenticated
  using (public.is_agency_admin())
  with check (public.is_agency_admin());

create policy "Agency staff read customers" on public.customers
  for select to authenticated using (public.is_agency_staff());
create policy "Agency staff add customers" on public.customers
  for insert to authenticated with check (public.is_agency_staff());
create policy "Agency staff update customers" on public.customers
  for update to authenticated using (public.is_agency_staff()) with check (public.is_agency_staff());
create policy "Admins delete customers" on public.customers
  for delete to authenticated using (public.is_agency_admin());

create policy "Agency staff read products" on public.products
  for select to authenticated using (public.is_agency_staff());
create policy "Admins manage products" on public.products
  for all to authenticated using (public.is_agency_admin()) with check (public.is_agency_admin());

create policy "Agency staff read orders" on public.orders
  for select to authenticated using (public.is_agency_staff());
create policy "Agency staff read order items" on public.order_items
  for select to authenticated using (public.is_agency_staff());
create policy "Agency staff read deliveries" on public.deliveries
  for select to authenticated using (public.is_agency_staff());
create policy "Agency staff read inventory" on public.inventory
  for select to authenticated using (public.is_agency_staff());
create policy "Agency staff read movements" on public.inventory_movements
  for select to authenticated using (public.is_agency_staff());
create policy "Agency staff read payments" on public.payments
  for select to authenticated using (public.is_agency_staff());

grant usage on schema public to authenticated;
grant select on public.profiles, public.customers, public.products, public.orders,
  public.order_items, public.deliveries, public.inventory, public.inventory_movements,
  public.payments to authenticated;
grant insert, update on public.profiles, public.customers, public.products to authenticated;

create or replace function public.create_order(
  p_customer_id uuid, p_product_id uuid, p_quantity integer, p_notes text default ''
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
  select filled - booked into v_available from public.inventory where product_id = p_product_id for update;
  if v_available is null or v_available < p_quantity then raise exception 'Not enough filled cylinders available'; end if;

  v_order_number := 'GA-' || to_char(now(), 'YYMMDD') || '-' ||
    lpad(nextval('public.order_number_seq')::text, 4, '0');
  insert into public.orders(order_number, customer_id, notes)
    values (v_order_number, p_customer_id, coalesce(p_notes, ''))
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
  if exists (select 1 from public.payments where order_id = p_order_id) then
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
  v_old_product uuid;
  v_old_quantity integer;
  v_status text;
  v_price numeric(12, 2);
  v_available integer;
  v_order_number text;
begin
  if not public.is_agency_staff() then raise exception 'Not authorized'; end if;
  if p_quantity <= 0 then raise exception 'Quantity must be greater than zero'; end if;
  select o.status, o.order_number, i.product_id, i.quantity
    into v_status, v_order_number, v_old_product, v_old_quantity
  from public.orders o join public.order_items i on i.order_id = o.id
  where o.id = p_order_id for update of o;
  if not found or v_status in ('Delivered', 'Cancelled') then raise exception 'Order cannot be edited'; end if;
  if not exists (select 1 from public.customers where id = p_customer_id and active) then
    raise exception 'Customer is unavailable';
  end if;
  select price into v_price from public.products where id = p_product_id and active;
  if v_price is null then raise exception 'Product is unavailable'; end if;

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
    set customer_id = p_customer_id, notes = coalesce(p_notes, '')
    where id = p_order_id;
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
  if p_status not in ('Pending', 'Assigned', 'Out for Delivery', 'Failed') then
    raise exception 'Use complete_delivery to mark a delivery complete';
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
    when 'Failed' then 'Confirmed'
    else 'Pending'
  end;
  update public.orders set status = v_order_status where id = p_order_id and status <> 'Cancelled';
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
declare
  v_order_status text;
  v_product_id uuid;
  v_quantity integer;
  v_order_number text;
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
  update public.inventory
    set filled = filled - v_quantity, empty = empty + v_quantity,
        booked = booked - v_quantity, delivered = delivered + v_quantity
    where product_id = v_product_id and filled >= v_quantity and booked >= v_quantity;
  if not found then raise exception 'Booked inventory is not available'; end if;
  update public.orders set status = 'Delivered' where id = p_order_id;
  update public.deliveries set status = 'Delivered', staff_id = p_staff_id,
      delivered_at = now(), notes = coalesce(p_notes, '')
    where order_id = p_order_id;
  insert into public.inventory_movements(product_id, kind, filled_change, empty_change, booked_change, note)
    values (v_product_id, 'Delivery', -v_quantity, v_quantity, -v_quantity, v_order_number);
end
$$;

create or replace function public.adjust_inventory(
  p_product_id uuid, p_filled_change integer, p_empty_change integer, p_note text
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_agency_admin() then raise exception 'Administrator access required'; end if;
  update public.inventory
    set filled = filled + p_filled_change, empty = empty + p_empty_change
    where product_id = p_product_id and filled + p_filled_change >= booked
      and empty + p_empty_change >= 0;
  if not found then raise exception 'Adjustment would create negative or already-booked stock'; end if;
  insert into public.inventory_movements(product_id, kind, filled_change, empty_change, note)
    values (p_product_id, 'Adjustment', p_filled_change, p_empty_change, coalesce(p_note, ''));
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
  if p_amount <= 0 then raise exception 'Payment amount must be greater than zero'; end if;
  select o.status, i.quantity * i.unit_price into v_status, v_total
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

grant execute on function public.create_order(uuid, uuid, integer, text) to authenticated;
grant execute on function public.cancel_order(uuid) to authenticated;
grant execute on function public.edit_order(uuid, uuid, uuid, integer, text) to authenticated;
grant execute on function public.update_delivery_status(uuid, text, uuid, text) to authenticated;
grant execute on function public.complete_delivery(uuid, uuid, text) to authenticated;
grant execute on function public.adjust_inventory(uuid, integer, integer, text) to authenticated;
grant execute on function public.record_payment(uuid, numeric, text, timestamptz, text, text) to authenticated;

revoke all on function public.create_order(uuid, uuid, integer, text) from public, anon;
revoke all on function public.cancel_order(uuid) from public, anon;
revoke all on function public.edit_order(uuid, uuid, uuid, integer, text) from public, anon;
revoke all on function public.update_delivery_status(uuid, text, uuid, text) from public, anon;
revoke all on function public.complete_delivery(uuid, uuid, text) from public, anon;
revoke all on function public.adjust_inventory(uuid, integer, integer, text) from public, anon;
revoke all on function public.record_payment(uuid, numeric, text, timestamptz, text, text) from public, anon;
revoke all on function public.create_product_inventory() from public, anon, authenticated;
revoke all on function public.attach_auth_user_to_profile() from public, anon, authenticated;
revoke all on function public.attach_profile_to_auth_user() from public, anon, authenticated;
revoke all on function public.current_agency_role() from public, anon;
revoke all on function public.is_agency_staff() from public, anon;
revoke all on function public.is_agency_admin() from public, anon;
grant execute on function public.current_agency_role() to authenticated;
grant execute on function public.is_agency_staff() to authenticated;
grant execute on function public.is_agency_admin() to authenticated;
revoke all on sequence public.order_number_seq from public, anon, authenticated;
