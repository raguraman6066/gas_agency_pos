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
values
  ('e10a0f00-0000-4000-8000-000000000001', 'Suresh Rao', 'demo.staff1@blueflame.demo', '9876500002', 'Staff', true),
  ('e10a0f00-0000-4000-8000-000000000002', 'Kiran Das', 'demo.staff2@blueflame.demo', '9876500003', 'Staff', true),
  ('e10a0f00-0000-4000-8000-000000000003', 'Meera Nair', 'demo.staff3@blueflame.demo', '9876500004', 'Staff', true)
on conflict (id) do update
set full_name = excluded.full_name,
    email = excluded.email,
    phone = excluded.phone,
    role = excluded.role,
    active = true,
    updated_at = now();

insert into public.customers (
  id, name, consumer_number, phone, alternative_phone, address, area, active, created_at
)
select
  md5('blueflame-demo-customer-' || n)::uuid,
  (array['Aarav', 'Ananya', 'Vijay', 'Priya', 'Rahul', 'Meera', 'Arjun', 'Kavya', 'Rohan', 'Divya'])[((n - 1) % 10) + 1]
    || ' ' ||
  (array['Sharma', 'Patel', 'Kumar', 'Reddy', 'Nair', 'Singh', 'Joshi', 'Iyer', 'Das', 'Gupta'])[(((n - 1) * 3) % 10) + 1],
  'DEMO-CN-' || lpad(n::text, 4, '0'),
  '98' || lpad((10000000 + n * 17391)::text, 8, '0'),
  case when n % 3 = 0 then '97' || lpad((10000000 + n * 10111)::text, 8, '0') else '' end,
  (10 + n)::text || ' ' ||
    (array['Central', 'North Park', 'Lake View', 'Market Road', 'Green Valley', 'Old Town'])[ ((n - 1) % 6) + 1]
    || ' Main Road',
  (array['Central', 'North Park', 'Lake View', 'Market Road', 'Green Valley', 'Old Town'])[ ((n - 1) % 6) + 1],
  true,
  now() - make_interval(days => 60 + n)
from generate_series(1, 30) as series(n)
on conflict (consumer_number) do nothing;

insert into public.products (id, name, type, size_kg, price, active)
values
  ('e20a0f00-0000-4000-8000-000000000001', 'Domestic LPG', 'Domestic', 14, 980.00, true),
  ('e20a0f00-0000-4000-8000-000000000002', 'Commercial LPG', 'Commercial', 19, 1680.00, true),
  ('e20a0f00-0000-4000-8000-000000000003', 'Small LPG', 'Domestic', 5, 420.00, true),
  ('e20a0f00-0000-4000-8000-000000000004', 'Commercial LPG XL', 'Commercial', 47, 3920.00, true),
  ('e20a0f00-0000-4000-8000-000000000005', 'Domestic LPG 14.2 kg', 'Domestic', 14, 1010.00, true)
on conflict (id) do update
set name = excluded.name,
    type = excluded.type,
    size_kg = excluded.size_kg,
    price = excluded.price,
    active = true,
    updated_at = now();

create table if not exists public._blueflame_demo_orders (
  n integer primary key,
  order_number text not null unique,
  customer_id uuid not null,
  product_id uuid not null,
  quantity integer not null,
  status text not null,
  created_at timestamptz not null,
  notes text not null
);
alter table public._blueflame_demo_orders enable row level security;
revoke all on public._blueflame_demo_orders from public, anon, authenticated;
truncate table public._blueflame_demo_orders;
insert into public._blueflame_demo_orders (
  n, order_number, customer_id, product_id, quantity, status, created_at, notes
)
select
  n,
  'DEMO-' || lpad((1000 + n)::text, 4, '0') as order_number,
  md5('blueflame-demo-customer-' || (((n * 7 - 1) % 30) + 1))::uuid as customer_id,
  (array[
    'e20a0f00-0000-4000-8000-000000000001'::uuid,
    'e20a0f00-0000-4000-8000-000000000002'::uuid,
    'e20a0f00-0000-4000-8000-000000000003'::uuid,
    'e20a0f00-0000-4000-8000-000000000004'::uuid,
    'e20a0f00-0000-4000-8000-000000000005'::uuid
  ])[((n - 1) % 5) + 1] as product_id,
  1 + (n % 2) as quantity,
  case
    when n <= 8 then 'Pending'
    when n <= 12 then 'Confirmed'
    when n <= 16 then 'Assigned'
    when n <= 20 then 'Out for Delivery'
    when n <= 34 then 'Delivered'
    else 'Cancelled'
  end as status,
  case
    when n <= 7 then now() - make_interval(days => n - 1)
    when n = 21 then now() - interval '4 hours'
    else now() - make_interval(days => (n * 4) % 170, hours => n % 11)
  end as created_at,
  case when n % 6 = 0 then 'Please call before delivery' else '' end as notes
from generate_series(1, 40) as series(n);

insert into public.orders (order_number, customer_id, status, notes, created_at)
select order_number, customer_id, status, notes, created_at
from public._blueflame_demo_orders
on conflict (order_number) do update
set customer_id = excluded.customer_id,
    status = excluded.status,
    notes = excluded.notes,
    created_at = excluded.created_at,
    updated_at = now();

insert into public.order_items (order_id, product_id, quantity, unit_price)
select o.id, d.product_id, d.quantity, p.price
from public._blueflame_demo_orders d
join public.orders o on o.order_number = d.order_number
join public.products p on p.id = d.product_id
on conflict (order_id) do update
set product_id = excluded.product_id,
    quantity = excluded.quantity,
    unit_price = excluded.unit_price,
    updated_at = now();

insert into public.deliveries (
  order_id, staff_id, status, delivered_at, notes
)
select
  o.id,
  case when d.status in ('Assigned', 'Out for Delivery', 'Delivered')
    then case when d.n % 2 = 0
      then 'e10a0f00-0000-4000-8000-000000000001'::uuid
      else 'e10a0f00-0000-4000-8000-000000000002'::uuid
    end
    else null
  end,
  case
    when d.status = 'Cancelled' then 'Failed'
    when d.status in ('Pending', 'Confirmed') then 'Pending'
    else d.status
  end,
  case when d.status = 'Delivered' then d.created_at + interval '3 hours' else null end,
  case when d.status = 'Cancelled' then 'Demo cancelled order' else '' end
from public._blueflame_demo_orders d
join public.orders o on o.order_number = d.order_number
on conflict (order_id) do update
set staff_id = excluded.staff_id,
    status = excluded.status,
    delivered_at = excluded.delivered_at,
    notes = excluded.notes,
    updated_at = now();

insert into public.payments (
  id, order_id, amount, method, payment_date, reference, notes
)
select
  md5('blueflame-demo-payment-' || d.order_number)::uuid,
  o.id,
  round(i.quantity * i.unit_price * case when d.n % 3 = 1 then 1 else 0.5 end, 2),
  case when d.n % 3 = 1 then 'UPI' else 'Cash' end,
  d.created_at + interval '4 hours',
  case when d.n % 3 = 1 then 'DEMO-UPI-' || d.n else '' end,
  'Sample manually recorded payment'
from public._blueflame_demo_orders d
join public.orders o on o.order_number = d.order_number
join public.order_items i on i.order_id = o.id
where d.status = 'Delivered'
on conflict (id) do update
set order_id = excluded.order_id,
    amount = excluded.amount,
    method = excluded.method,
    payment_date = excluded.payment_date,
    reference = excluded.reference,
    notes = excluded.notes,
    updated_at = now();

update public.inventory inv
set filled = stock.opening_filled - stock.delivered_quantity,
    empty = stock.opening_empty + stock.delivered_quantity,
    booked = stock.booked_quantity,
    delivered = stock.delivered_quantity,
    minimum = stock.minimum,
    updated_at = now()
from (
  select
    p.id as product_id,
    case p.id
      when 'e20a0f00-0000-4000-8000-000000000001'::uuid then 68
      when 'e20a0f00-0000-4000-8000-000000000002'::uuid then 32
      when 'e20a0f00-0000-4000-8000-000000000003'::uuid then 45
      when 'e20a0f00-0000-4000-8000-000000000004'::uuid then 18
      else 52
    end as opening_filled,
    case p.id
      when 'e20a0f00-0000-4000-8000-000000000001'::uuid then 18
      when 'e20a0f00-0000-4000-8000-000000000002'::uuid then 10
      when 'e20a0f00-0000-4000-8000-000000000003'::uuid then 15
      when 'e20a0f00-0000-4000-8000-000000000004'::uuid then 7
      else 16
    end as opening_empty,
    coalesce(sum(i.quantity) filter (where d.status = 'Delivered'), 0)::integer as delivered_quantity,
    coalesce(sum(i.quantity) filter (where d.status not in ('Delivered', 'Cancelled')), 0)::integer as booked_quantity,
    case when p.id = 'e20a0f00-0000-4000-8000-000000000004'::uuid then 5 else 10 end as minimum
  from public.products p
  left join public.order_items i on i.product_id = p.id
  left join public.orders o on o.id = i.order_id and o.order_number like 'DEMO-%'
  left join public._blueflame_demo_orders d on d.order_number = o.order_number
  where p.id in (
    'e20a0f00-0000-4000-8000-000000000001'::uuid,
    'e20a0f00-0000-4000-8000-000000000002'::uuid,
    'e20a0f00-0000-4000-8000-000000000003'::uuid,
    'e20a0f00-0000-4000-8000-000000000004'::uuid,
    'e20a0f00-0000-4000-8000-000000000005'::uuid
  )
  group by p.id
) stock
where inv.product_id = stock.product_id;

insert into public.inventory_movements (
  id, product_id, kind, filled_change, empty_change, booked_change, note, created_at
)
select
  md5('blueflame-demo-opening-' || p.id::text)::uuid,
  p.id, 'Opening stock',
  case p.id
    when 'e20a0f00-0000-4000-8000-000000000001'::uuid then 68
    when 'e20a0f00-0000-4000-8000-000000000002'::uuid then 32
    when 'e20a0f00-0000-4000-8000-000000000003'::uuid then 45
    when 'e20a0f00-0000-4000-8000-000000000004'::uuid then 18
    else 52
  end,
  case p.id
    when 'e20a0f00-0000-4000-8000-000000000001'::uuid then 18
    when 'e20a0f00-0000-4000-8000-000000000002'::uuid then 10
    when 'e20a0f00-0000-4000-8000-000000000003'::uuid then 15
    when 'e20a0f00-0000-4000-8000-000000000004'::uuid then 7
    else 16
  end,
  0, 'DEMO OPENING STOCK', now() - interval '30 days'
from public.products p
where p.id in (
  'e20a0f00-0000-4000-8000-000000000001'::uuid,
  'e20a0f00-0000-4000-8000-000000000002'::uuid,
  'e20a0f00-0000-4000-8000-000000000003'::uuid,
  'e20a0f00-0000-4000-8000-000000000004'::uuid,
  'e20a0f00-0000-4000-8000-000000000005'::uuid
)
on conflict (id) do nothing;

insert into public.inventory_movements (
  id, product_id, kind, filled_change, empty_change, booked_change, note, created_at
)
select
  md5('blueflame-demo-movement-' || d.order_number)::uuid,
  i.product_id,
  case
    when d.status = 'Delivered' then 'Delivery'
    when d.status = 'Cancelled' then 'Order cancelled'
    else 'Order booked'
  end,
  case when d.status = 'Delivered' then -i.quantity else 0 end,
  case when d.status = 'Delivered' then i.quantity else 0 end,
  case
    when d.status = 'Delivered' then -i.quantity
    when d.status = 'Cancelled' then 0
    else i.quantity
  end,
  d.order_number,
  d.created_at
from public._blueflame_demo_orders d
join public.orders o on o.order_number = d.order_number
join public.order_items i on i.order_id = o.id
on conflict (id) do nothing;

commit;
