alter table public.customers add column customer_type text
  check (customer_type in ('Domestic', 'Commercial'));

create table public.agency_settings (
  id integer primary key default 1 check (id = 1),
  name text not null default 'BlueFlame' check (length(trim(name)) > 0),
  details text not null default '',
  delivery_charge numeric(12, 2) not null default 0 check (delivery_charge >= 0),
  payment_methods text[] not null default array['Cash', 'UPI', 'Bank Transfer', 'Other']
    check (cardinality(payment_methods) > 0 and array_position(payment_methods, null) is null
      and payment_methods <@ array['Cash', 'UPI', 'Bank Transfer', 'Other'])
);
insert into public.agency_settings default values;
alter table public.agency_settings enable row level security;
grant select, update on public.agency_settings to authenticated;
create policy "Agency staff read settings" on public.agency_settings
  for select to authenticated using (public.is_agency_staff());
create policy "Agency admins update settings" on public.agency_settings
  for update to authenticated using (public.is_agency_admin())
  with check (public.is_agency_admin());
