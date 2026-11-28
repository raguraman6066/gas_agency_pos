-- Permanently clear agency business records in the selected Supabase project.
-- Existing logins, staff profiles, agency settings, and booking numbering are retained.
begin;

truncate table
  public.payments,
  public.deliveries,
  public.order_items,
  public.orders,
  public.inventory_movements,
  public.inventory,
  public.products,
  public.customers;

commit;
