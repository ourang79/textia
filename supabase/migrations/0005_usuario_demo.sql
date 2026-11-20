-- Usuario de demostración (contraseña pública: los datos son inventados) y reinicio de la demo
do $$
declare uid uuid;
begin
  select id into uid from auth.users where email = 'demo@textia.es';
  if uid is null then
    uid := gen_random_uuid();
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                            raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                            confirmation_token, recovery_token, email_change_token_new, email_change)
    values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', 'demo@textia.es',
            extensions.crypt('textia-demo', extensions.gen_salt('bf')), now(),
            '{"provider":"email","providers":["email"]}', '{"full_name":"Laura Gómez (demo)"}', now(), now(), '', '', '', '');
    insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), uid, uid::text, jsonb_build_object('sub', uid::text, 'email', 'demo@textia.es', 'email_verified', true), 'email', now(), now(), now());
  end if;
end $$;

-- Regenera la demo y vuelve a enlazar el usuario demo con la comercial Laura Gómez
create or replace function private.demo_reset() returns jsonb
language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  r := private.demo_seed('demo');
  update members m set user_id = u.id
  from auth.users u
  where u.email = 'demo@textia.es' and m.email = 'laura@demo.textia.es'
    and m.org_id = (select id from orgs where slug = 'demo');
  return r;
end $$;
revoke all on function private.demo_reset() from public, anon, authenticated;
