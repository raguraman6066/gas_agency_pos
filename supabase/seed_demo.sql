begin;

do $$
begin
  if not exists (
    select 1
    from auth.users
    where lower(email) = lower('admin@gmail.com')
  ) then
    raise exception
      'Create and confirm admin@gmail.com in Supabase Auth before running this demo seed.';
  end if;
end
$$;

-- Run only on a demo project. Recognize the previous seed by its reserved IDs.
create temporary table legacy_demo_ids on commit drop as
select
  array(select 'DEMO-' || (1000 + n)::text from generate_series(1, 40) n) as orders,
  array(select md5('blueflame-demo-customer-' || n)::uuid from generate_series(1, 30) n) as customers,
  array(select ('e20a0f00-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
    from generate_series(1, 5) n) as products,
  array(select ('e10a0f00-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid
    from generate_series(1, 3) n) as staff;

lock table public.customers, public.products, public.orders, public.order_items,
  public.deliveries, public.payments, public.inventory, public.inventory_movements,
  public.profiles in share row exclusive mode;

do $$
declare
  seed pg_temp.legacy_demo_ids%rowtype;
  blockers text;
begin
  select * into seed from pg_temp.legacy_demo_ids;
  select string_agg(format('%s %s', total, label), ', ' order by label)
  into blockers
  from (
    select 'non-seed bookings linked to demo stock or customers being removed' as label,
      count(*) as total
    from public.orders o
    where o.order_number <> all(seed.orders)
      and (o.customer_id = any(seed.customers[3:30]) or exists (
        select 1 from public.order_items i
        where i.order_id = o.id and i.product_id = any(seed.products)
      ))
    union all
    select 'reserved demo booking numbers linked to non-seed customers', count(*)
    from public.orders
    where order_number = any(seed.orders) and customer_id <> all(seed.customers)
    union all
    select 'demo bookings using non-seed products', count(*)
    from public.order_items i join public.orders o on o.id = i.order_id
    where o.order_number = any(seed.orders) and i.product_id <> all(seed.products)
    union all
    select 'non-seed payments or refunds on demo bookings', count(*)
    from public.payments p join public.orders o on o.id = p.order_id
    where o.order_number = any(seed.orders)
      and p.id <> md5('blueflame-demo-payment-' || o.order_number)::uuid
    union all
    select 'non-seed stock movements for demo products', count(*)
    from public.inventory_movements m
    where m.product_id = any(seed.products)
      and m.id <> md5('blueflame-demo-opening-' || m.product_id::text)::uuid
      and (m.note <> all(seed.orders) or m.id not in (
        md5('blueflame-demo-movement-' || m.note)::uuid,
        md5('blueflame-demo-reservation-' || m.note)::uuid
      ))
    union all
    select 'reserved demo consumer numbers used by non-seed customers', count(*)
    from public.customers
    where consumer_number in ('DEMO-CN-0001', 'DEMO-CN-0002')
      and id <> case consumer_number
        when 'DEMO-CN-0001' then seed.customers[1]
        else seed.customers[2]
      end
  ) checks
  where total > 0;

  if blockers is not null then
    raise exception 'Demo reset stopped: %.', blockers
      using hint = 'The transaction was rolled back. Review the listed records before resetting the demo.';
  end if;

  delete from public.payments p using public.orders o
  where p.order_id = o.id and o.order_number = any(seed.orders)
    and p.id = md5('blueflame-demo-payment-' || o.order_number)::uuid
    and o.order_number <> 'DEMO-1002';
  delete from public.deliveries d using public.orders o
  where d.order_id = o.id and o.order_number = any(seed.orders[3:40]);
  delete from public.orders where order_number = any(seed.orders[3:40]);
  delete from public.inventory_movements m
  where m.id in (md5('blueflame-demo-movement-' || m.note)::uuid,
                 md5('blueflame-demo-reservation-' || m.note)::uuid)
    and m.note = any(seed.orders) and m.product_id = any(seed.products);
  delete from public.inventory_movements where product_id = any(seed.products[3:5]);
  delete from public.inventory where product_id = any(seed.products[3:5]);
  delete from public.products where id = any(seed.products[3:5]);
  delete from public.profiles p
  where p.id = any(seed.staff[2:3]) and p.auth_user_id is null
    and not exists (select 1 from public.deliveries d where d.staff_id = p.id);
end
$$;

update public.profiles p
set auth_user_id = u.id,
    full_name = 'Agency Admin',
    role = 'Admin',
    active = true,
    updated_at = now()
from auth.users u
where lower(u.email) = lower('admin@gmail.com')
  and lower(p.email) = lower(u.email);

insert into public.profiles (
  id, auth_user_id, full_name, email, phone, role, active
)
select
  u.id, u.id, 'Agency Admin', u.email, '', 'Admin', true
from auth.users u
where lower(u.email) = lower('admin@gmail.com')
  and not exists (
    select 1
    from public.profiles p
    where lower(p.email) = lower(u.email)
  )
on conflict (id) do update
set auth_user_id = excluded.auth_user_id,
    full_name = excluded.full_name,
    role = 'Admin',
    active = true,
    updated_at = now();

insert into public.profiles (id, full_name, email, phone, role, active)
values ('e10a0f00-0000-4000-8000-000000000001',
  'Suresh Rao', 'demo.staff1@blueflame.demo', '9876500002', 'Staff', true)
on conflict (id) do update set active = true;

insert into public.customers (id, name, consumer_number, phone, address, area, customer_type)
values
  (md5('blueflame-demo-customer-1')::uuid, 'Aarav Sharma', 'DEMO-CN-0001',
   '9810000000', '12 Central Main Road', 'Central', 'Domestic'),
  (md5('blueflame-demo-customer-2')::uuid, 'Ananya Reddy', 'DEMO-CN-0002',
   '9810017391', '13 North Park Main Road', 'North Park', 'Commercial')
on conflict (id) do nothing;

insert into public.products (id, name, type, size_kg, price, active)
values
  ('e20a0f00-0000-4000-8000-000000000001', 'Domestic LPG', 'Domestic', 14, 980, true),
  ('e20a0f00-0000-4000-8000-000000000002', 'Commercial LPG', 'Commercial', 19, 1680, true)
on conflict (id) do update
set name = excluded.name, type = excluded.type, size_kg = excluded.size_kg,
    price = excluded.price, active = excluded.active;

create temporary table demo_bookings on commit drop as
select * from (values
  ('DEMO-1001', md5('blueflame-demo-customer-1')::uuid,
   'e20a0f00-0000-4000-8000-000000000001'::uuid, 2, 'Ready for Delivery',
   'Please call before delivery'),
  ('DEMO-1002', md5('blueflame-demo-customer-2')::uuid,
   'e20a0f00-0000-4000-8000-000000000002'::uuid, 3, 'Delivered', '')
) as fixtures(order_number, customer_id, product_id, quantity, status, notes);

insert into public.orders (order_number, customer_id, status, notes, created_at)
select order_number, customer_id, status, notes, now() from pg_temp.demo_bookings
on conflict (order_number) do update
set customer_id = excluded.customer_id, status = excluded.status, notes = excluded.notes,
    delivery_charge = 0, discount = 0, created_at = excluded.created_at;

-- The two retained booking numbers used different customers in the larger demo.
delete from public.customers
where id in (select md5('blueflame-demo-customer-' || n)::uuid from generate_series(3, 30) n);

insert into public.order_items (order_id, product_id, quantity, unit_price)
select o.id, d.product_id, d.quantity, p.price
from pg_temp.demo_bookings d
join public.orders o using (order_number)
join public.products p on p.id = d.product_id
on conflict (order_id) do update
set product_id = excluded.product_id, quantity = excluded.quantity, unit_price = excluded.unit_price;

insert into public.deliveries (
  order_id, staff_id, status, delivered_at, delivered_quantity, returned_empty, damaged_empty, notes, created_at
)
select o.id,
  case when d.status = 'Delivered' then 'e10a0f00-0000-4000-8000-000000000001'::uuid end,
  case when d.status = 'Delivered' then 'Delivered' else 'Pending' end,
  case when d.status = 'Delivered' then now() end,
  case when d.status = 'Delivered' then d.quantity end,
  case when d.status = 'Delivered' then 1 end,
  case when d.status = 'Delivered' then 1 else 0 end,
  '', now()
from pg_temp.demo_bookings d join public.orders o using (order_number)
on conflict (order_id) do update
set staff_id = excluded.staff_id, status = excluded.status, delivered_at = excluded.delivered_at,
    delivered_quantity = excluded.delivered_quantity, returned_empty = excluded.returned_empty,
    damaged_empty = excluded.damaged_empty, notes = excluded.notes, created_at = excluded.created_at;

insert into public.payments (id, order_id, amount, method, payment_date, reference, notes)
select md5('blueflame-demo-payment-' || o.order_number)::uuid, o.id,
  i.quantity * i.unit_price / 2, 'UPI', now(), 'DEMO-UPI-2', 'Sample partial payment'
from public.orders o join public.order_items i on i.order_id = o.id
where o.order_number = 'DEMO-1002'
on conflict (id) do update
set order_id = excluded.order_id, amount = excluded.amount, method = excluded.method,
    payment_date = excluded.payment_date, reference = excluded.reference, notes = excluded.notes;

update public.inventory i
set filled = s.filled, empty = s.empty, booked = s.booked, delivered = s.delivered,
    damaged = s.damaged, minimum = 10
from (values
  ('e20a0f00-0000-4000-8000-000000000001'::uuid, 12, 4, 2, 0, 0),
  ('e20a0f00-0000-4000-8000-000000000002'::uuid, 7, 3, 0, 3, 1)
) as s(product_id, filled, empty, booked, delivered, damaged)
where i.product_id = s.product_id;

insert into public.inventory_movements (
  id, product_id, kind, filled_change, empty_change, booked_change, damaged_change, created_at
)
select md5('blueflame-demo-opening-' || i.product_id::text)::uuid, i.product_id,
  'Demo stock balance', i.filled, i.empty, i.booked, i.damaged, now()
from public.inventory i
join pg_temp.demo_bookings d using (product_id)
on conflict (id) do update
set kind = excluded.kind, filled_change = excluded.filled_change,
    empty_change = excluded.empty_change, booked_change = excluded.booked_change,
    damaged_change = excluded.damaged_change, note = '', created_at = excluded.created_at;

commit;
