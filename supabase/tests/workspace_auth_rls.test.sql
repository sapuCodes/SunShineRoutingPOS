begin;

select no_plan();

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  (
    '10000000-0000-4000-8000-000000000001',
    'authenticated', 'authenticated', 'owner@example.test', '',
    null, '{"provider":"email","providers":["email"]}',
    '{"display_name":"Workspace Owner"}', now(), now()
  ),
  (
    '20000000-0000-4000-8000-000000000002',
    'authenticated', 'authenticated', 'member@example.test', '',
    null, '{"provider":"email","providers":["email"]}',
    '{"display_name":"Workspace Member"}', now(), now()
  );

select is(
  (select count(*)::integer from public.profiles
   where id = '10000000-0000-4000-8000-000000000001'),
  0,
  'an unverified auth user has no profile'
);

update auth.users
  set email_confirmed_at = now()
  where id = '10000000-0000-4000-8000-000000000001';
update auth.users
  set email_confirmed_at = now()
  where id = '20000000-0000-4000-8000-000000000002';

insert into public.workspaces (id, name, type, owner_id)
values (
  '30000000-0000-4000-8000-000000000003',
  'Ownership transfer test fixture',
  'business',
  '10000000-0000-4000-8000-000000000001'
);
insert into public.workspace_members (workspace_id, user_id, role)
values (
  '30000000-0000-4000-8000-000000000003',
  '10000000-0000-4000-8000-000000000001',
  'Owner'
);

select set_config(
  'test.owner_workspace_id',
  (select id::text from public.workspaces
   where owner_id = '10000000-0000-4000-8000-000000000001'
     and type = 'business'),
  true
);
select set_config(
  'test.member_workspace_id',
  (select id::text from public.workspaces
   where owner_id = '20000000-0000-4000-8000-000000000002'
     and type = 'personal'),
  true
);
select set_config(
  'test.owner_personal_workspace_id',
  (select id::text from public.workspaces
   where owner_id = '10000000-0000-4000-8000-000000000001'
     and type = 'personal'),
  true
);

select is(
  (select count(*)::integer from public.profiles
   where id = '10000000-0000-4000-8000-000000000001'),
  1,
  'email verification creates one profile'
);
select is(
  (select display_name from public.profiles
   where id = '10000000-0000-4000-8000-000000000001'),
  'Workspace Owner',
  'profile display name comes from verified auth metadata'
);
select is(
  (select count(*)::integer from public.workspaces
   where owner_id = '10000000-0000-4000-8000-000000000001'
     and type = 'personal'),
  1,
  'email verification creates one personal workspace'
);
select is(
  (select membership.role
   from public.workspace_members as membership
   join public.workspaces as workspace
     on workspace.id = membership.workspace_id
   where workspace.owner_id = '10000000-0000-4000-8000-000000000001'
     and workspace.type = 'personal'
     and membership.user_id = '10000000-0000-4000-8000-000000000001'),
  'Owner',
  'personal workspace membership is Owner'
);
select is(
  (select count(*)::integer
   from public.workspace_settings as settings
   join public.workspaces as workspace on workspace.id = settings.workspace_id
   where workspace.owner_id = '10000000-0000-4000-8000-000000000001'
     and settings.currency = 'LKR'
     and settings.timezone = 'Asia/Colombo'
     and settings.settings ->> 'country_code' = 'LK'),
  1,
  'workspace settings use Sri Lanka defaults without tax rules'
);

update public.workspace_members
  set role = 'Manager'
  where workspace_id =
      current_setting('test.owner_personal_workspace_id')::uuid
    and user_id = '10000000-0000-4000-8000-000000000001';

update auth.users
  set email_confirmed_at = email_confirmed_at
  where id = '10000000-0000-4000-8000-000000000001';
select is(
  (select count(*)::integer from public.workspaces
   where owner_id = '10000000-0000-4000-8000-000000000001'
     and type = 'personal'),
  1,
  'repeated verification is idempotent for personal workspaces'
);
select is(
  (select count(*)::integer from public.workspace_members
   where user_id = '10000000-0000-4000-8000-000000000001'
    and workspace_id =
      current_setting('test.owner_personal_workspace_id')::uuid),
  1,
  'repeated verification is idempotent for memberships'
);
select is(
  (select role from public.workspace_members
   where workspace_id =
     current_setting('test.owner_personal_workspace_id')::uuid
     and user_id = '10000000-0000-4000-8000-000000000001'),
  'Manager',
  'repeated email verification does not restore an existing membership role'
);
update public.workspace_members
  set role = 'Owner'
  where workspace_id =
      current_setting('test.owner_personal_workspace_id')::uuid
    and user_id = '10000000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);
select ok(
  not has_table_privilege('authenticated', 'public.workspaces', 'UPDATE'),
  'authenticated users have no table-wide workspace update privilege'
);
select ok(
  not has_column_privilege(
    'authenticated', 'public.workspaces', 'owner_id', 'UPDATE'
  ),
  'authenticated users cannot directly update workspace ownership'
);
select ok(
  has_column_privilege('authenticated', 'public.workspaces', 'name', 'UPDATE'),
  'authenticated users retain workspace name update permission'
);
select throws_ok(
  $$update public.workspaces
    set owner_id = '20000000-0000-4000-8000-000000000002'
    where id = current_setting('test.owner_workspace_id')::uuid$$,
  '42501',
  'permission denied for table workspaces',
  'an Owner cannot transfer ownership by directly updating owner_id'
);
update public.workspaces
  set name = 'Renamed workspace'
  where id = current_setting('test.owner_workspace_id')::uuid;
select is(
  (select name from public.workspaces
   where id = current_setting('test.owner_workspace_id')::uuid),
  'Renamed workspace',
  'an Owner can still update the workspace name'
);
select is(
  (select count(*)::integer from public.profiles),
  1,
  'users can read only their own profile'
);
select is(
  (select count(*)::integer from public.workspaces),
  2,
  'users can read their own workspaces'
);
select is(
  (select count(*)::integer from public.workspace_members
   where workspace_id = current_setting('test.owner_workspace_id')::uuid),
  1,
  'workspace members can read their workspace membership'
);
select throws_ok(
  $$select public.update_workspace_member_role(
    current_setting('test.owner_workspace_id')::uuid,
    '10000000-0000-4000-8000-000000000001',
    'Manager'
  )$$,
  'P0001',
  'You cannot change your own role.',
  'users cannot change their own role'
);
select throws_ok(
  $$select public.update_workspace_member_role(
    current_setting('test.owner_workspace_id')::uuid,
    '20000000-0000-4000-8000-000000000002',
    'Owner'
  )$$,
  'P0001',
  'The requested role cannot be assigned.',
  'Owner role cannot be assigned through member management'
);

select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  $$select public.create_workspace_invitation(
    current_setting('test.owner_workspace_id')::uuid,
    'unauthorized@example.test',
    'Cashier'
  )$$,
  'P0001',
  'Owner or Admin authorization is required.',
  'an authenticated non-member cannot create a workspace invitation'
);
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);

select set_config(
  'test.invitation_token',
  public.create_workspace_invitation(
    current_setting('test.owner_workspace_id')::uuid,
    'member@example.test',
    'Manager'
  ),
  true
);
select isnt(
  (select token_hash from public.workspace_invitations
   where workspace_id = current_setting('test.owner_workspace_id')::uuid),
  current_setting('test.invitation_token'),
  'database stores only a hash of the invitation token'
);
select throws_ok(
  $$select public.create_workspace_invitation(
    current_setting('test.owner_workspace_id')::uuid,
    'another@example.test',
    'Owner'
  )$$,
  'P0001',
  'The requested role cannot be assigned.',
  'invitation cannot assign the Owner role'
);
select throws_ok(
  $$select public.accept_workspace_invitation(
    current_setting('test.invitation_token')
  )$$,
  'P0001',
  'Invitation is invalid, expired, or already accepted.',
  'an invitation cannot be accepted by a different email identity'
);
select throws_ok(
  $$select public.accept_workspace_invitation(repeat('x', 64))$$,
  'P0001',
  'Invitation is invalid, expired, or already accepted.',
  'an unknown invitation token is rejected'
);
select set_config(
  'test.expired_invitation_token',
  public.create_workspace_invitation(
    current_setting('test.owner_workspace_id')::uuid,
    'expired@example.test',
    'Cashier'
  ),
  true
);

reset role;
update public.workspace_invitations
  set created_at = now() - interval '8 days',
      expires_at = now() - interval '1 minute'
  where email = 'expired@example.test';
set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-4000-8000-000000000002',
  true
);
select is(
  (select count(*)::integer from public.workspace_settings
   where workspace_id =
     current_setting('test.owner_personal_workspace_id')::uuid),
  0,
  'members cannot read another workspace settings'
);
select is(
  (select count(*)::integer from public.workspace_branding
   where workspace_id =
     current_setting('test.owner_personal_workspace_id')::uuid),
  0,
  'members cannot read another workspace branding'
);
update public.workspace_settings
  set currency = 'USD'
  where workspace_id =
    current_setting('test.owner_personal_workspace_id')::uuid;
update public.workspace_branding
  set business_name = 'Unauthorized change',
      primary_color = '#000000'
  where workspace_id =
    current_setting('test.owner_personal_workspace_id')::uuid;
select throws_ok(
  $$insert into public.workspace_members (workspace_id, user_id, role)
    values (
      current_setting('test.owner_workspace_id')::uuid,
      '20000000-0000-4000-8000-000000000002',
      'Owner'
    )$$,
  '42501',
  'permission denied for table workspace_members',
  'ordinary members cannot directly insert Owner memberships'
);
select throws_ok(
  $$update public.workspace_members set role = 'Owner'
    where workspace_id = current_setting('test.owner_workspace_id')::uuid
      and user_id = '20000000-0000-4000-8000-000000000002'$$,
  '42501',
  'permission denied for table workspace_members',
  'ordinary members cannot directly change membership roles'
);
select throws_ok(
  $$insert into public.workspace_invitations (
      workspace_id, email, role, token_hash, expires_at
    ) values (
      current_setting('test.owner_workspace_id')::uuid,
      'direct@example.test',
      'Cashier',
      repeat('a', 64),
      now() + interval '1 day'
    )$$,
  '42501',
  'permission denied for table workspace_invitations',
  'ordinary members cannot directly create invitations'
);
select throws_ok(
  $$update public.workspace_invitations
    set role = 'Admin'
    where workspace_id = current_setting('test.owner_workspace_id')::uuid$$,
  '42501',
  'permission denied for table workspace_invitations',
  'ordinary members cannot directly modify invitations'
);
select throws_ok(
  $$delete from public.workspace_invitations
    where workspace_id = current_setting('test.owner_workspace_id')::uuid$$,
  '42501',
  'permission denied for table workspace_invitations',
  'ordinary members cannot directly delete invitations'
);
select set_config('request.jwt.claim.sub', '', true);
select throws_ok(
  $$select public.remove_workspace_member(
    current_setting('test.owner_workspace_id')::uuid,
    '20000000-0000-4000-8000-000000000002'
  )$$,
  'P0001',
  'Authentication required.',
  'remove_workspace_member explicitly rejects unauthenticated callers'
);
reset role;
set local role anon;
select throws_ok(
  $$select public.remove_workspace_member(
    current_setting('test.owner_workspace_id')::uuid,
    '20000000-0000-4000-8000-000000000002'
  )$$,
  '42501',
  'permission denied for function remove_workspace_member',
  'anon cannot execute remove_workspace_member'
);
reset role;
select is(
  (select currency from public.workspace_settings
   where workspace_id =
     current_setting('test.owner_personal_workspace_id')::uuid),
  'LKR',
  'cross-workspace settings update changes no data'
);
select is(
  (select business_name from public.workspace_branding
   where workspace_id =
     current_setting('test.owner_personal_workspace_id')::uuid),
  null,
  'cross-workspace branding update changes no data'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-4000-8000-000000000002',
  true
);
select is(
  (select count(*)::integer from public.workspaces),
  1,
  'users cannot read another workspace before joining it'
);
select is(
  (select count(*)::integer from public.profiles),
  1,
  'users cannot read another user profile'
);
select is(
  (select count(*)::integer from public.workspace_invitations),
  0,
  'invitation token is not exposed by table reads'
);
select throws_ok(
  $$select public.accept_workspace_invitation(
    current_setting('test.expired_invitation_token')
  )$$,
  'P0001',
  'Invitation is invalid, expired, or already accepted.',
  'an expired invitation is rejected'
);
select is(
  (select workspace_id
   from public.accept_workspace_invitation(
     current_setting('test.invitation_token')
   )),
  current_setting('test.owner_workspace_id')::uuid,
  'invite acceptance validates the recipient identity and token'
);
select is(
  (select role from public.workspace_members
   where workspace_id = current_setting('test.owner_workspace_id')::uuid
     and user_id = '20000000-0000-4000-8000-000000000002'),
  'Manager',
  'acceptance creates membership with the invited role'
);
select throws_ok(
  $$update public.workspace_members set role = 'Owner'
    where workspace_id = current_setting('test.owner_workspace_id')::uuid
      and user_id = '20000000-0000-4000-8000-000000000002'$$,
  '42501',
  'permission denied for table workspace_members',
  'a member cannot directly promote themselves to Owner'
);
select throws_ok(
  $$delete from public.workspace_members
    where workspace_id = current_setting('test.owner_workspace_id')::uuid
      and user_id = '20000000-0000-4000-8000-000000000002'$$,
  '42501',
  'permission denied for table workspace_members',
  'a member cannot directly delete their membership'
);
select is(
  (select role from public.workspace_members
   where workspace_id = current_setting('test.owner_workspace_id')::uuid
     and user_id = '20000000-0000-4000-8000-000000000002'),
  'Manager',
  'direct membership writes do not change the authorized role'
);
select is(
  (select count(*)::integer from public.workspaces),
  2,
  'an accepted invite grants access to the joined workspace'
);
select throws_ok(
  $$select public.accept_workspace_invitation(
    current_setting('test.invitation_token')
  )$$,
  'P0001',
  'Invitation is invalid, expired, or already accepted.',
  'an invitation token is single-use'
);
select throws_ok(
  $$select public.create_workspace_invitation(
    current_setting('test.owner_workspace_id')::uuid,
    'unauthorized@example.test',
    'Cashier'
  )$$,
  'P0001',
  'Owner or Admin authorization is required.',
  'a non-admin member cannot create workspace invitations'
);
select throws_ok(
  $$select public.transfer_workspace_ownership(
    current_setting('test.owner_workspace_id')::uuid,
    '20000000-0000-4000-8000-000000000002'
  )$$,
  'P0001',
  'Only the current owner can transfer ownership.',
  'a non-owner cannot transfer ownership'
);

reset role;
insert into public.workspace_invitations (
  workspace_id, email, role, token_hash, expires_at
)
values (
  current_setting('test.owner_workspace_id')::uuid,
  'owner@example.test',
  'Cashier',
  encode(
    extensions.digest(convert_to(repeat('f', 64), 'UTF8'), 'sha256'),
    'hex'
  ),
  now() + interval '1 day'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$select public.accept_workspace_invitation(repeat('f', 64))$$,
  'P0001',
  'Invitation is invalid, expired, or already accepted.',
  'failed membership insertion rejects invitation acceptance'
);
reset role;
select is(
  (select accepted_at from public.workspace_invitations
   where email = 'owner@example.test'
     and workspace_id = current_setting('test.owner_workspace_id')::uuid),
  null,
  'failed membership insertion rolls back the invitation acceptance'
);

reset role;
insert into public.workspace_members (workspace_id, user_id, role)
values (
  current_setting('test.owner_personal_workspace_id')::uuid,
  '20000000-0000-4000-8000-000000000002',
  'Manager'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);
select throws_ok(
  $$select public.transfer_workspace_ownership(
    current_setting('test.owner_personal_workspace_id')::uuid,
    '20000000-0000-4000-8000-000000000002'
  )$$,
  'P0001',
  'The new owner already owns a personal workspace.',
  'a personal workspace cannot create a duplicate owner personal workspace'
);
select public.update_workspace_member_role(
  current_setting('test.owner_workspace_id')::uuid,
  '20000000-0000-4000-8000-000000000002',
  'Admin'
);
select is(
  (select role from public.workspace_members
   where workspace_id = current_setting('test.owner_workspace_id')::uuid
     and user_id = '20000000-0000-4000-8000-000000000002'),
  'Admin',
  'the Owner can use the authorized membership-management function'
);
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-4000-8000-000000000002',
  true
);
select throws_ok(
  $$select public.update_workspace_member_role(
    current_setting('test.owner_workspace_id')::uuid,
    '10000000-0000-4000-8000-000000000001',
    'Manager'
  )$$,
  'P0001',
  'Ownership can only be changed by the owner transfer operation.',
  'an Admin cannot change the Owner membership'
);
select throws_ok(
  $$select public.update_workspace_member_role(
    current_setting('test.owner_workspace_id')::uuid,
    '10000000-0000-4000-8000-000000000001',
    'Owner'
  )$$,
  'P0001',
  'The requested role cannot be assigned.',
  'an Admin cannot assign the Owner role'
);
select throws_ok(
  $$select public.transfer_workspace_ownership(
    current_setting('test.owner_workspace_id')::uuid,
    '20000000-0000-4000-8000-000000000002'
  )$$,
  'P0001',
  'Only the current owner can transfer ownership.',
  'an Admin cannot transfer ownership'
);
delete from public.workspaces
  where id = current_setting('test.owner_workspace_id')::uuid;
select is(
  (select count(*)::integer from public.workspaces
   where id = current_setting('test.owner_workspace_id')::uuid),
  1,
  'an Admin cannot delete a workspace'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-4000-8000-000000000001',
  true
);
select public.transfer_workspace_ownership(
  current_setting('test.owner_workspace_id')::uuid,
  '20000000-0000-4000-8000-000000000002'
);
select is(
  (select owner_id from public.workspaces
   where id = current_setting('test.owner_workspace_id')::uuid),
  '20000000-0000-4000-8000-000000000002'::uuid,
  'the Owner can atomically transfer workspace ownership'
);
select is(
  (select count(*)::integer from public.workspace_members
   where workspace_id = current_setting('test.owner_workspace_id')::uuid
     and ((user_id = '10000000-0000-4000-8000-000000000001'
           and role = 'Admin')
       or (user_id = '20000000-0000-4000-8000-000000000002'
           and role = 'Owner'))),
  2,
  'ownership transfer updates both Owner memberships'
);
select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-4000-8000-000000000002',
  true
);
delete from public.workspaces
  where id = current_setting('test.owner_workspace_id')::uuid;
select is(
  (select count(*)::integer from public.workspaces
   where id = current_setting('test.owner_workspace_id')::uuid),
  0,
  'the current Owner can delete the workspace'
);

reset role;
select * from finish();
rollback;
