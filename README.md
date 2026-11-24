# BlueFlame Gas Agency Manager

A responsive Flutter application for everyday gas-agency work: customers, products, orders, deliveries, cylinder stock, manually recorded payments, reports and staff profiles.

## Run the dummy-data application

```powershell
flutter pub get
flutter run -d chrome
```

Demo sign-in:

- Admin: `admin@gasagency.demo`
- Staff: `staff@gasagency.demo`
- Password: `demo123`

The local repository seeds 30 customers, 5 products, 40 orders, deliveries, stock movements and payments. Changes remain in memory for the current app run and are reset when it restarts.

## Supabase setup

1. Create a Supabase project and apply [`supabase/migrations/202611240001_initial_schema.sql`](./supabase/migrations/202611240001_initial_schema.sql).
2. Create an Auth user for the initial administrator in the Supabase dashboard.
3. Link that account to the administrator profile using the SQL editor, substituting the account email:

   ```sql
   insert into public.profiles (auth_user_id, full_name, email, role)
   select id, 'Agency Admin', email, 'Admin'
   from auth.users
   where email = 'admin@example.com'
   on conflict (email) do update
     set auth_user_id = excluded.auth_user_id, role = 'Admin', active = true;
   ```

4. Run the app with your project URL and publishable key:

   ```powershell
   flutter run -d chrome `
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
     --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
   ```

   The Supabase publishable/anon key is intended for client applications; never put a `service_role` key in Flutter Web.
5. Add initial products and stock after signing in. To enable a staff member, create or invite their account in Supabase Auth, then add a matching active staff profile in the app. A profile alone does not create an Auth account.

For `admin@gmail.com`, link the existing Auth account to the agency admin profile in the Supabase SQL Editor:

```sql
insert into public.profiles (auth_user_id, full_name, email, phone, role, active)
select id, 'Agency Admin', email, '', 'Admin', true
from auth.users
where email = 'admin@gmail.com'
on conflict (email) do update
set auth_user_id = excluded.auth_user_id,
    role = 'Admin',
    active = true,
    updated_at = now();
```

The app selects Supabase only when both compile-time values are set; otherwise it uses the dummy repository. Both implementations share `AgencyRepository`, leaving presentation and state management unchanged. Supabase order creation, editing/cancellation, delivery completion, payments and stock adjustments use database functions so related updates execute atomically. RLS is enabled on all application tables; database permissions are authoritative, with UI restrictions as a usability layer.

## Structure

- `lib/core/domain`: application models
- `lib/core/data`: repository contract and dummy/Supabase implementations
- `lib/core/providers.dart`: Riverpod application state and operations
- `lib/core/presentation`: app shell, login and reusable presentation widgets
- `lib/features/dashboard`: computed business dashboard
- `lib/features/operations`: customer, product, order, delivery, inventory, payment, report and staff workflows
- `supabase/migrations`: PostgreSQL schema, indexes, RLS policies and transactional functions

## Checks

```powershell
flutter analyze
flutter test
flutter build web
```
