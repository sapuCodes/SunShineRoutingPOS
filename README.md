# Sun Shine POS

Sun Shine POS is a Flutter application for Android and Windows. The application
is being built around shared personal and business workspaces, offline-first
point-of-sale workflows, and configurable workspace branding.

## Phase 1 foundation

The current foundation includes:

- A feature-first Flutter structure with Riverpod state management.
- GoRouter navigation and a responsive dashboard placeholder.
- A centralized steel-and-orange Material theme.
- Application defaults for Sri Lanka, LKR, and `Asia/Colombo`. Tax behavior is
  intentionally not configured.
- Versioned local SQLite initialization for Android and Windows.
- A small application metadata table for non-business app state only.
- An explicit startup error screen if local storage cannot be opened.

No Supabase project is connected. No credentials, workspace, business, product,
customer, sales, or sample transaction data are included. The reference
application at `reference/SunShine-Mobile.html` remains unchanged.

## Run and validate

From the `sunshinerpos` directory:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter run -d <android-device-id>
```

The app environment can be selected with a Dart define, for example:

```powershell
flutter run -d windows --dart-define=APP_ENV=development
```

Future Supabase client configuration may use `SUPABASE_URL` and
`SUPABASE_PUBLISHABLE_KEY` Dart defines. Phase 1 does not initialize Supabase.
Never provide a service-role key or other privileged secret to a client build.

## Local database

`LocalDatabase` owns SQLite opening, schema versioning, migrations, and closing.
Android uses the platform SQLite plugin; Windows uses SQLite FFI and stores the
database under the application's support directory. The initial schema contains
only `app_metadata`; workspace and business records are not created in Phase 1.

Future offline transactions should be stored in a workspace-scoped local cache
and durable outbox. Each operation should have a locally generated stable ID,
an idempotency key, retry state, server acknowledgement, and explicit conflict
state. Pending financial operations must survive restarts; synchronization
should retry on launch, foregrounding, and reconnection rather than depending
only on OS background scheduling.

Subscription entitlements should eventually be cached as server-signed
snapshots that can be verified offline using a public key. An expired
subscription must leave existing records viewable and exportable, while new
sales are restricted; pending operations still need reconciliation. The
provider, prices, trial length, grace period, and entitlement format are not
implemented or selected in Phase 1.

## Current scope

Phase 1 does not implement authentication, Supabase migrations/RLS, workspace
management, POS sales, inventory, payments, returns, subscriptions, printing,
or browser-data import. Existing browser data must be inspected and exported
before any migration is proposed; no data is modified by this foundation.
