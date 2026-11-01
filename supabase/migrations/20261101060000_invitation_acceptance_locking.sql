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
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  perform 1
    from public.workspaces as workspace
    where workspace.id = p_workspace_id
    for update;
  if not found then
    raise exception 'Workspace not found.';
  end if;

  select membership.role into v_caller_role
    from public.workspace_members as membership
    where membership.workspace_id = p_workspace_id
      and membership.user_id = auth.uid()
    for update;

  if v_caller_role is null
    or v_caller_role not in ('Owner', 'Admin') then
    raise exception 'Owner or Admin authorization is required.';
  end if;
  if p_role is null
    or p_role not in ('Admin', 'Manager', 'Salesperson', 'Cashier') then
    raise exception 'The requested role cannot be assigned.';
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
  v_token_hash text;
  v_invitation_id uuid;
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

  v_token_hash :=
    encode(extensions.digest(convert_to(p_token, 'UTF8'), 'sha256'), 'hex');

  select invitation.id, invitation.workspace_id, invitation.role
    into v_invitation_id, v_workspace_id, v_role
    from public.workspace_invitations as invitation
    where invitation.token_hash = v_token_hash
      and invitation.email = v_email
      and invitation.expires_at > now()
      and invitation.accepted_at is null;

  if v_invitation_id is null then
    raise exception 'Invitation is invalid, expired, or already accepted.';
  end if;

  perform 1
    from public.workspaces as workspace
    where workspace.id = v_workspace_id
    for update;
  if not found then
    raise exception 'Invitation is invalid, expired, or already accepted.';
  end if;

  update public.workspace_invitations as invitation
    set accepted_at = now()
    where invitation.id = v_invitation_id
      and invitation.token_hash = v_token_hash
      and invitation.email = v_email
      and invitation.expires_at > now()
      and invitation.accepted_at is null
    returning invitation.workspace_id, invitation.role
      into v_workspace_id, v_role;

  if not found then
    raise exception 'Invitation is invalid, expired, or already accepted.';
  end if;

  begin
    insert into public.workspace_members (workspace_id, user_id, role)
    values (v_workspace_id, v_user_id, v_role);
  exception
    when unique_violation then
      raise exception 'Invitation is invalid, expired, or already accepted.';
  end;

  return query select v_workspace_id, v_role;
end;
$$;

revoke all on function public.create_workspace_invitation(uuid, text, text)
  from public, anon;
revoke all on function public.accept_workspace_invitation(text)
  from public, anon;
grant execute on function public.create_workspace_invitation(uuid, text, text)
  to authenticated;
grant execute on function public.accept_workspace_invitation(text)
  to authenticated;
