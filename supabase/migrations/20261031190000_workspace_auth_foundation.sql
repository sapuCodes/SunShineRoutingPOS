create extension if not exists pgcrypto with schema extensions;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_not_blank
    check (display_name is null or length(btrim(display_name)) > 0)
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function public.set_updated_at() from public, anon, authenticated;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row
  execute function public.set_updated_at();

create table public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null,
  owner_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint workspaces_name_not_blank check (length(btrim(name)) > 0),
  constraint workspaces_type_valid check (type in ('personal', 'business'))
);

create unique index workspaces_one_personal_per_owner
  on public.workspaces (owner_id)
  where type = 'personal';
create index workspaces_owner_id_idx on public.workspaces (owner_id);

create table public.workspace_members (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null,
  joined_at timestamptz not null default now(),
  constraint workspace_members_role_valid
    check (role in ('Owner', 'Admin', 'Manager', 'Salesperson', 'Cashier')),
  constraint workspace_members_unique_user unique (workspace_id, user_id)
);

create unique index workspace_members_one_owner_per_workspace
  on public.workspace_members (workspace_id)
  where role = 'Owner';
create index workspace_members_user_id_idx
  on public.workspace_members (user_id, workspace_id);

create table public.workspace_invitations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  email text not null,
  role text not null,
  token_hash text not null unique,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  constraint workspace_invitations_email_normalized
    check (email = lower(btrim(email)) and position('@' in email) > 1),
  constraint workspace_invitations_role_valid
    check (role in ('Admin', 'Manager', 'Salesperson', 'Cashier')),
  constraint workspace_invitations_expiry_valid
    check (expires_at > created_at)
);

create unique index workspace_invitations_one_pending_email
  on public.workspace_invitations (workspace_id, email)
  where accepted_at is null;
create index workspace_invitations_workspace_id_idx
  on public.workspace_invitations (workspace_id);

create table public.workspace_settings (
  workspace_id uuid primary key
    references public.workspaces (id) on delete cascade,
  currency text not null default 'LKR',
  timezone text not null default 'Asia/Colombo',
  settings jsonb not null default '{"country_code":"LK"}'::jsonb,
  constraint workspace_settings_currency_valid
    check (currency ~ '^[A-Z]{3}$'),
  constraint workspace_settings_timezone_not_blank
    check (length(btrim(timezone)) > 0),
  constraint workspace_settings_settings_object
    check (jsonb_typeof(settings) = 'object')
);

create table public.workspace_branding (
  workspace_id uuid primary key
    references public.workspaces (id) on delete cascade,
  business_name text,
  logo_path text,
  primary_color text,
  constraint workspace_branding_name_not_blank
    check (business_name is null or length(btrim(business_name)) > 0),
  constraint workspace_branding_color_format
    check (primary_color is null or primary_color ~ '^#[0-9A-Fa-f]{6}$')
);

create or replace function public.is_workspace_member(p_workspace_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select auth.uid() is not null
    and exists (
      select 1
      from public.workspace_members as membership
      where membership.workspace_id = p_workspace_id
        and membership.user_id = auth.uid()
    );
$$;

create or replace function public.has_workspace_role(
  p_workspace_id uuid,
  p_roles text[]
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select auth.uid() is not null
    and exists (
      select 1
      from public.workspace_members as membership
      where membership.workspace_id = p_workspace_id
        and membership.user_id = auth.uid()
        and membership.role = any (p_roles)
    );
$$;

revoke all on function public.is_workspace_member(uuid) from public, anon;
revoke all on function public.has_workspace_role(uuid, text[]) from public, anon;
grant execute on function public.is_workspace_member(uuid) to authenticated;
grant execute on function public.has_workspace_role(uuid, text[]) to authenticated;

create or replace function public.handle_verified_auth_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_workspace_id uuid;
  v_display_name text;
begin
  if new.email_confirmed_at is null then
    return new;
  end if;

  v_display_name := nullif(
    btrim(coalesce(
      new.raw_user_meta_data ->> 'display_name',
      new.raw_user_meta_data ->> 'full_name'
    )),
    ''
  );

  insert into public.profiles (id, display_name)
  values (new.id, v_display_name)
  on conflict (id) do nothing;

  insert into public.workspaces (name, type, owner_id)
  values ('Personal workspace', 'personal', new.id)
  on conflict (owner_id) where type = 'personal' do nothing
  returning id into v_workspace_id;

  if v_workspace_id is null then
    select workspace.id
      into v_workspace_id
      from public.workspaces as workspace
      where workspace.owner_id = new.id
        and workspace.type = 'personal';
  end if;

  insert into public.workspace_settings (workspace_id)
  values (v_workspace_id)
  on conflict (workspace_id) do nothing;

  insert into public.workspace_branding (workspace_id)
  values (v_workspace_id)
  on conflict (workspace_id) do nothing;

  insert into public.workspace_members (workspace_id, user_id, role)
  values (v_workspace_id, new.id, 'Owner')
  on conflict (workspace_id, user_id)
  do update set role = 'Owner';

  return new;
end;
$$;

revoke all on function public.handle_verified_auth_user() from public, anon, authenticated;

create trigger on_auth_user_verified
  after insert or update of email_confirmed_at on auth.users
  for each row
  when (new.email_confirmed_at is not null)
  execute function public.handle_verified_auth_user();

create or replace function public.update_workspace_member_role(
  p_workspace_id uuid,
  p_user_id uuid,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_caller_role text;
  v_target_role text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;
  if p_role not in ('Admin', 'Manager', 'Salesperson', 'Cashier') then
    raise exception 'The requested role cannot be assigned.';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'You cannot change your own role.';
  end if;

  select membership.role into v_caller_role
    from public.workspace_members as membership
    where membership.workspace_id = p_workspace_id
      and membership.user_id = auth.uid();
  select membership.role into v_target_role
    from public.workspace_members as membership
    where membership.workspace_id = p_workspace_id
      and membership.user_id = p_user_id;

  if v_caller_role is null or v_target_role is null then
    raise exception 'Workspace membership not found.';
  end if;
  if v_target_role = 'Owner' then
    raise exception 'Ownership can only be changed by the owner transfer operation.';
  end if;
  if v_caller_role not in ('Owner', 'Admin') then
    raise exception 'Owner or Admin authorization is required.';
  end if;
  if v_caller_role = 'Admin' and p_role = 'Admin' then
    raise exception 'Admins cannot assign the Admin role.';
  end if;

  update public.workspace_members
    set role = p_role
    where workspace_id = p_workspace_id
      and user_id = p_user_id;
end;
$$;

create or replace function public.remove_workspace_member(
  p_workspace_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_caller_role text;
  v_target_role text;
begin
  select membership.role into v_caller_role
    from public.workspace_members as membership
    where membership.workspace_id = p_workspace_id
      and membership.user_id = auth.uid();
  select membership.role into v_target_role
    from public.workspace_members as membership
    where membership.workspace_id = p_workspace_id
      and membership.user_id = p_user_id;

  if v_caller_role is null
    or v_caller_role not in ('Owner', 'Admin')
    or v_target_role is null then
    raise exception 'Owner or Admin authorization is required.';
  end if;
  if v_target_role = 'Owner' then
    raise exception 'The workspace owner cannot be removed.';
  end if;
  if v_caller_role = 'Admin' and v_target_role = 'Admin' then
    raise exception 'Admins cannot remove another Admin.';
  end if;

  delete from public.workspace_members
    where workspace_id = p_workspace_id
      and user_id = p_user_id;
end;
$$;

create or replace function public.transfer_workspace_ownership(
  p_workspace_id uuid,
  p_new_owner_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null or not exists (
    select 1
    from public.workspaces as workspace
    where workspace.id = p_workspace_id
      and workspace.owner_id = auth.uid()
  ) then
    raise exception 'Only the current owner can transfer ownership.';
  end if;
  if p_new_owner_id = auth.uid() then
    raise exception 'The current owner is already the owner.';
  end if;
  if not exists (
    select 1
    from public.workspace_members as membership
    where membership.workspace_id = p_workspace_id
      and membership.user_id = p_new_owner_id
  ) then
    raise exception 'The new owner must already be a workspace member.';
  end if;

  update public.workspace_members
    set role = 'Admin'
    where workspace_id = p_workspace_id
      and user_id = auth.uid()
      and role = 'Owner';

  update public.workspace_members
    set role = 'Owner'
    where workspace_id = p_workspace_id
      and user_id = p_new_owner_id;

  update public.workspaces
    set owner_id = p_new_owner_id
    where id = p_workspace_id;
end;
$$;

create or replace function public.create_workspace_invitation(
  p_workspace_id uuid,
  p_email text,
  p_role text
)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $$
declare
  v_email text := lower(btrim(p_email));
  v_token text := encode(extensions.gen_random_bytes(32), 'hex');
  v_caller_role text;
begin
  select membership.role into v_caller_role
    from public.workspace_members as membership
    where membership.workspace_id = p_workspace_id
      and membership.user_id = auth.uid();

  if v_caller_role not in ('Owner', 'Admin') then
    raise exception 'Owner or Admin authorization is required.';
  end if;
  if p_role not in ('Admin', 'Manager', 'Salesperson', 'Cashier') then
    raise exception 'The requested invitation role cannot be assigned.';
  end if;
  if v_caller_role = 'Admin' and p_role = 'Admin' then
    raise exception 'Admins cannot invite another Admin.';
  end if;
  if v_email is null or position('@' in v_email) < 2 then
    raise exception 'A valid invitation email is required.';
  end if;
  if exists (
    select 1
    from public.workspace_members as membership
    join auth.users as invited_user on invited_user.id = membership.user_id
    where membership.workspace_id = p_workspace_id
      and lower(invited_user.email) = v_email
  ) then
    raise exception 'This user is already a workspace member.';
  end if;

  insert into public.workspace_invitations (
    workspace_id, email, role, token_hash, expires_at
  )
  values (
    p_workspace_id,
    v_email,
    p_role,
    encode(extensions.digest(convert_to(v_token, 'UTF8'), 'sha256'), 'hex'),
    now() + interval '7 days'
  )
  on conflict (workspace_id, email) where accepted_at is null
  do update set
    role = excluded.role,
    token_hash = excluded.token_hash,
    expires_at = excluded.expires_at,
    created_at = now();

  return v_token;
end;
$$;

create or replace function public.accept_workspace_invitation(p_token text)
returns table (workspace_id uuid, role text)
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_workspace_id uuid;
  v_role text;
begin
  if v_user_id is null or p_token is null or length(p_token) < 32 then
    raise exception 'Invitation is invalid, expired, or already accepted.';
  end if;

  select lower(auth_user.email) into v_email
    from auth.users as auth_user
    where auth_user.id = v_user_id;
  if v_email is null then
    raise exception 'Invitation is invalid, expired, or already accepted.';
  end if;

  update public.workspace_invitations as invitation
    set accepted_at = now()
    where invitation.token_hash =
      encode(extensions.digest(convert_to(p_token, 'UTF8'), 'sha256'), 'hex')
      and invitation.email = v_email
      and invitation.expires_at > now()
      and invitation.accepted_at is null
    returning invitation.workspace_id, invitation.role
      into v_workspace_id, v_role;

  if v_workspace_id is null then
    raise exception 'Invitation is invalid, expired, or already accepted.';
  end if;

  insert into public.workspace_members (workspace_id, user_id, role)
  values (v_workspace_id, v_user_id, v_role);

  return query select v_workspace_id, v_role;
end;
$$;

revoke all on function public.update_workspace_member_role(uuid, uuid, text)
  from public, anon;
revoke all on function public.remove_workspace_member(uuid, uuid)
  from public, anon;
revoke all on function public.transfer_workspace_ownership(uuid, uuid)
  from public, anon;
revoke all on function public.create_workspace_invitation(uuid, text, text)
  from public, anon;
revoke all on function public.accept_workspace_invitation(text)
  from public, anon;
grant execute on function public.update_workspace_member_role(uuid, uuid, text)
  to authenticated;
grant execute on function public.remove_workspace_member(uuid, uuid)
  to authenticated;
grant execute on function public.transfer_workspace_ownership(uuid, uuid)
  to authenticated;
grant execute on function public.create_workspace_invitation(uuid, text, text)
  to authenticated;
grant execute on function public.accept_workspace_invitation(text)
  to authenticated;

alter table public.profiles enable row level security;
alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.workspace_invitations enable row level security;
alter table public.workspace_settings enable row level security;
alter table public.workspace_branding enable row level security;

create policy profiles_select_own
  on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy profiles_update_own
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy workspaces_select_member
  on public.workspaces for select to authenticated
  using ((select public.is_workspace_member(id)));
create policy workspaces_update_owner
  on public.workspaces for update to authenticated
  using ((select public.has_workspace_role(id, array['Owner']::text[])))
  with check ((select public.has_workspace_role(id, array['Owner']::text[])));
create policy workspaces_delete_owner
  on public.workspaces for delete to authenticated
  using ((select public.has_workspace_role(id, array['Owner']::text[])));

create policy workspace_members_select_self_or_admin
  on public.workspace_members for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select public.has_workspace_role(
      workspace_id, array['Owner', 'Admin']::text[]
    ))
  );

create policy workspace_invitations_select_admin
  on public.workspace_invitations for select to authenticated
  using ((select public.has_workspace_role(
    workspace_id, array['Owner', 'Admin']::text[]
  )));

create policy workspace_settings_select_member
  on public.workspace_settings for select to authenticated
  using ((select public.is_workspace_member(workspace_id)));
create policy workspace_settings_insert_admin
  on public.workspace_settings for insert to authenticated
  with check ((select public.has_workspace_role(
    workspace_id, array['Owner', 'Admin']::text[]
  )));
create policy workspace_settings_update_admin
  on public.workspace_settings for update to authenticated
  using ((select public.has_workspace_role(
    workspace_id, array['Owner', 'Admin']::text[]
  )))
  with check ((select public.has_workspace_role(
    workspace_id, array['Owner', 'Admin']::text[]
  )));
create policy workspace_settings_delete_admin
  on public.workspace_settings for delete to authenticated
  using ((select public.has_workspace_role(
    workspace_id, array['Owner', 'Admin']::text[]
  )));

create policy workspace_branding_select_member
  on public.workspace_branding for select to authenticated
  using ((select public.is_workspace_member(workspace_id)));
create policy workspace_branding_insert_admin
  on public.workspace_branding for insert to authenticated
  with check ((select public.has_workspace_role(
    workspace_id, array['Owner', 'Admin']::text[]
  )));
create policy workspace_branding_update_admin
  on public.workspace_branding for update to authenticated
  using ((select public.has_workspace_role(
    workspace_id, array['Owner', 'Admin']::text[]
  )))
  with check ((select public.has_workspace_role(
    workspace_id, array['Owner', 'Admin']::text[]
  )));
create policy workspace_branding_delete_admin
  on public.workspace_branding for delete to authenticated
  using ((select public.has_workspace_role(
    workspace_id, array['Owner', 'Admin']::text[]
  )));

grant select on public.profiles to authenticated;
grant update (display_name) on public.profiles to authenticated;
grant select, update (name), delete on public.workspaces to authenticated;
grant select on public.workspace_members to authenticated;
grant select on public.workspace_invitations to authenticated;
grant select, insert, update, delete on public.workspace_settings to authenticated;
grant select, insert, update, delete on public.workspace_branding to authenticated;
