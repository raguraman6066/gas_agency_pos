alter table public.customers
  add column if not exists gst_number text not null default '',
  add column if not exists identity_document_type text not null default '',
  add column if not exists identity_document_number text not null default '',
  add column if not exists gas_provider text not null default '';

do $migration$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.customers'::regclass
      and conname = 'customers_identity_document_type_check'
  ) then
    alter table public.customers
      add constraint customers_identity_document_type_check
        check (identity_document_type in ('', 'PAN', 'Aadhaar'));
  end if;
end
$migration$;