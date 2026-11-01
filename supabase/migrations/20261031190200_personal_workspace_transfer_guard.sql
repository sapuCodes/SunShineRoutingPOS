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
  if exists (
    select 1
    from public.workspaces as source_workspace
    join public.workspaces as target_workspace
      on target_workspace.owner_id = p_new_owner_id
     and target_workspace.type = 'personal'
    where source_workspace.id = p_workspace_id
      and source_workspace.type = 'personal'
  ) then
    raise exception 'The new owner already owns a personal workspace.';
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

revoke all on function public.transfer_workspace_ownership(uuid, uuid)
  from public, anon;
grant execute on function public.transfer_workspace_ownership(uuid, uuid)
  to authenticated;
