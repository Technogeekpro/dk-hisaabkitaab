# D.K. Mobiles Profit

A simple Flutter app for tracking skin and wrap sales at D.K. Mobiles.

## How it works

1. Add products with a name, buying price, and usual selling price.
2. Record a sale by selecting a product, entering the actual selling price and quantity.
3. Add dated expenses with a short note in Sales & expenses.
4. View net profit for today, this week, this month, lifetime, or the average per active day.
5. See the 50/50 profit share for each partner.
6. Record payments from your brother with the actual amount received, date, and Cash or UPI method. The Dues screen shows the remaining balance and when it was cleared.

Net profit is total sales minus buying cost minus other expenses. Your share is 50% of net profit; amount due is your lifetime share minus payments received. A rounded payment above the due amount is carried as paid ahead. A sale saves the prices used at the time, so changing a product later does not change historical profit. All amounts are in INR.

With Case Point Supabase configured, sign in with email and password to keep these records in the cloud. The app opens the protected home screen only while a Supabase session exists, responds to sign-in and sign-out events, and restores the signed-in view when a saved session is available. The database also restricts each account to its own records with row-level security. Existing records saved on this device are imported once on first sign-in. Cloud writes require an internet connection; the app shows an error and leaves the entry unchanged if a write fails. Without cloud configuration, the app continues to store records on this device with `shared_preferences`.

## Case Point Supabase setup

1. Select the **Case Point** project with reference `kmibtvrlbcyrxoaasdeq`. Do not use another project's URL or key.
2. The migration in `supabase/migrations/20261011064729_dk_mobiles_cloud_data.sql` has already been applied to Case Point. It created only the new `dk_products`, `dk_sales`, `dk_expenses`, and `dk_payments` tables, their policies, indexes, and grants.
3. In Supabase Auth, enable email/password sign-in. If email confirmation is enabled, confirm the account before signing in.
4. Copy `config/supabase.example.json` to `config/supabase.local.json` and set the project URL and **publishable** key. Never put a service role or secret key in the Flutter app. The local file is gitignored.
5. Run `flutter run --dart-define-from-file=config/supabase.local.json`.

The migration was applied to Case Point through its SQL editor on 11 October 2026 and verified to create four `dk_` tables with RLS enabled. The current Codex app Supabase connector still points to another account, so the project-scoped `case_point_supabase` MCP connection and the Supabase CLI were configured separately. Do not run this migration again with `supabase db push`; SQL editor execution does not add a CLI migration-history entry. The **D.K Mobiles POS** project was untouched.

## Run

```bash
flutter pub get
flutter run --dart-define-from-file=config/supabase.local.json
```

## Check

```bash
flutter analyze
flutter test
```
