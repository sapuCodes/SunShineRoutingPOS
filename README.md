# Sun Shine POS

Sun Shine POS is a Flutter application for Android and Windows. It is built
around shared personal and business workspaces, offline-first point-of-sale
workflows, and configurable workspace branding.

## Phase 1 foundation

- Feature-first Flutter structure with Riverpod and GoRouter.
- Centralized steel-and-orange Material theme and Sri Lanka defaults.
- Versioned local SQLite storage for Android and Windows.
- Application metadata is separate from cached workspace details.
- Startup errors are shown explicitly; no business or sample transaction data
  is created.

The reference application at `reference/SunShine-Mobile.html` is unchanged.

## Local Supabase only

This project is configured for the local Supabase stack only. Do not run
`supabase link`, `supabase db push`, or deploy functions/migrations. App
configuration rejects hosted URLs and accepts only the local API host on port
54321.

1. Start the local stack from this directory:

   ```powershell
   supabase start
   ```

   Local services use API `http://127.0.0.1:54321`, Studio
   `http://127.0.0.1:54323`, Mailpit `http://127.0.0.1:54324`, and PostgreSQL
   `127.0.0.1:54322`.
2. Copy `local_config.example.json` to the ignored `local_config.json`. Obtain
   the **local publishable key only** from the local Supabase Studio/API
   settings and put it in `SUPABASE_PUBLISHABLE_KEY`. Never use or copy a
   secret/service-role key. The example intentionally contains no key.
3. Use `http://127.0.0.1:54321` on Windows. For an Android emulator, set the
   URL to `http://10.0.2.2:54321`. The local configuration file is ignored by
   Git.
4. Run the app:

   ```powershell
   flutter run -d windows --dart-define-from-file=local_config.json
   flutter run -d <android-device-id> --dart-define-from-file=local_config.json
   ```

Without a local publishable key and API URL, the app displays a configuration
message and does not pretend authentication is working. Supabase client code
accepts only a key with Supabase's `sb_publishable_` prefix; no private key is
required by Flutter.

## Migrations and database security

The reviewed SQL migrations under `supabase/migrations/` create profiles,
workspaces, memberships, invitations, settings, and branding. A database
trigger creates the profile, personal workspace, default settings/branding,
and Owner membership atomically when an Auth user's email becomes verified. A
partial unique index and conflict-safe writes make this initialization
idempotent. Follow-up migrations tighten function authorization and prevent a
personal-workspace ownership transfer from violating the one-personal-workspace
per-owner constraint. The authorization hardening migration prevents direct
`owner_id` writes, preserves workspace-name updates, avoids changing existing
membership roles during repeated verification, and serializes concurrent
ownership/member-management operations.
The invitation follow-up migration rejects missing workspace roles and locks
the workspace before conditionally accepting a pending invitation; membership
insertion failure rolls back acceptance.

Email confirmations are enabled for the local stack. The local confirmation
and password-recovery templates send six-digit codes that are entered in the
app; inspect test emails in Mailpit. Profile/workspace creation happens in the
database, not as a sequence of client requests.

Apply migrations only to the local database:

```powershell
supabase migration up --local
```

RLS is enabled on every user-facing table. Membership helper functions avoid
recursive RLS checks. Direct membership writes are not granted to authenticated
clients; authorized role changes, member removal, ownership transfer, invite
creation, and invite acceptance go through authorization-checked PostgreSQL
functions. Invitation tokens are returned only when created, stored as
SHA-256 hashes, matched to the authenticated email, expire after seven days,
and can be accepted once. The app does not yet send workspace invitation
emails.

Flutter role permissions are centralized for UI behavior only. PostgreSQL RLS
and checked database functions are authoritative; cached workspace roles are
display-only and never confer server authorization. Only the Owner can transfer
ownership or delete a workspace, and Owner is never an assignable invitation or
member-management role.

## Authentication and workspace behavior

The app supports email/password registration and sign-in, email verification,
password reset by email code, session restoration, sign-out, and protected
workspace/dashboard routes. A verified session loads membership from Supabase
before workspace selection or dashboard entry. The selected workspace ID and
workspace display details are cached in SQLite; unavailable network access is
shown explicitly and cached roles are labeled unverified. Sign-out clears only
authentication-related workspace cache/selection, not unrelated POS data.

Business workspace creation UI, invitation delivery UI, POS data, tax
configuration, and synchronization are not part of this phase.

## Testing and builds

Run Flutter checks from this directory:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --debug
flutter build apk --debug
```

Run the database RLS/trigger tests against the local Supabase database:

```powershell
supabase db test --local supabase/tests/workspace_auth_rls.test.sql
```

These tests verify email-verification initialization, idempotency, RLS
cross-workspace restrictions, role escalation prevention, and invitation
identity/hash/single-use behavior, including non-member invitation rejection
and acceptance rollback. They must not be run against a linked or
hosted project. The SQL test fixture creates a temporary business workspace
inside a transaction and rolls it back; it does not leave sample business data
in the local database.
