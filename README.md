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

The local demo starts with two customers, two products, two bookings and deliveries, two staff profiles, and one sample payment. Changes remain in memory for the current app run and are reset when it restarts.

## Supabase setup

1. Apply the files in [`supabase/migrations`](./supabase/migrations) in filename order, starting with the initial schema.
2. Create and confirm an Auth user for the administrator. The demo seed currently targets `admin@gmail.com`; edit that email in [`supabase/seed_demo.sql`](./supabase/seed_demo.sql) if using another account.
3. Run [`supabase/seed_demo.sql`](./supabase/seed_demo.sql) in the SQL Editor. This demo-only reset links the admin Auth account and installs the small demo dataset. It trims records from the previous seed, preserves unrelated records and linked staff accounts, and reports any bookings, payments, or stock movements that prevent a safe reset.
4. Run the app with your project URL and publishable key:

   ```powershell
   flutter run -d chrome `
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
     --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
   ```

   The Supabase publishable/anon key is intended for client applications; never put a `service_role` key in Flutter Web.
5. The seeded staff profile can be assigned deliveries. To give a staff member login access, also create/confirm their account in Supabase Auth with the same email. A profile alone is not an Auth account.

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
