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
  if p_role is null
    or p_role not in ('Admin', 'Manager', 'Salesperson', 'Cashier') then
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
      and exists (
        select 1
        from public.workspace_members as owner_membership
        where owner_membership.workspace_id = workspace.id
          and owner_membership.user_id = auth.uid()
          and owner_membership.role = 'Owner'
      )
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

  if v_caller_role is null or v_caller_role not in ('Owner', 'Admin') then
    raise exception 'Owner or Admin authorization is required.';
  end if;
  if p_role is null
    or p_role not in ('Admin', 'Manager', 'Salesperson', 'Cashier') then
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

revoke all on function public.update_workspace_member_role(uuid, uuid, text)
  from public, anon;
revoke all on function public.transfer_workspace_ownership(uuid, uuid)
  from public, anon;
revoke all on function public.create_workspace_invitation(uuid, text, text)
  from public, anon;
grant execute on function public.update_workspace_member_role(uuid, uuid, text)
  to authenticated;
grant execute on function public.transfer_workspace_ownership(uuid, uuid)
  to authenticated;
grant execute on function public.create_workspace_invitation(uuid, text, text)
  to authenticated;
