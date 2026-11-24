-- Textia · usuarios y roles: cada comercial ve solo los centros de su zona
-- Alcance (scope) de cada miembro: 'all' para dirección y jefes sin zona; el id de su zona para el resto

-- 1. Alcance de quien entra
create or replace function private.my_scope(o uuid) returns text
language sql stable security definer set search_path = public as $$
  select case when m.role = 'admin' or m.zone_id is null then 'all' else m.zone_id::text end
  from members m where m.user_id = auth.uid() and m.org_id = o limit 1
$$;
create or replace function private.school_ok(o uuid, sid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(private.my_scope(o) = 'all', false)
      or exists (select 1 from schools s where s.id = sid and s.zone_id::text = private.my_scope(o))
$$;
create or replace function private.code_ok(o uuid, c text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(private.my_scope(o) = 'all', false)
      or exists (select 1 from schools s where s.org_id = o and s.code = c and s.zone_id::text = private.my_scope(o))
$$;
revoke all on function private.my_scope(uuid), private.school_ok(uuid, uuid), private.code_ok(uuid, text) from public, anon;
grant execute on function private.my_scope(uuid), private.school_ok(uuid, uuid), private.code_ok(uuid, text) to authenticated;

-- 2. Tablas ligadas a un centro: lectura solo dentro del alcance
drop policy if exists schools_read on public.schools;
create policy schools_read on public.schools for select using (org_id in (select private.my_orgs()) and private.school_ok(org_id, id));
do $$
declare t text;
begin
  foreach t in array array['school_slots','enrollment','adoptions','people','visits','tasks'] loop
    execute format('drop policy if exists %I on public.%I', t || '_read', t);
    execute format('create policy %I on public.%I for select using (org_id in (select private.my_orgs()) and (school_id is null or private.school_ok(org_id, school_id)))', t || '_read', t);
  end loop;
  foreach t in array array['person_slots','person_contacts'] loop
    execute format('drop policy if exists %I on public.%I', t || '_read', t);
    execute format('create policy %I on public.%I for select using (org_id in (select private.my_orgs()) and exists (select 1 from public.people p where p.id = person_id and private.school_ok(p.org_id, p.school_id)))', t || '_read', t);
  end loop;
end $$;

-- 3. Datos que carga la app: uno por zona y otro completo ('all')
alter table public.datasets add column if not exists scope text not null default 'all';
alter table public.datasets drop constraint if exists datasets_pkey;
alter table public.datasets add primary key (org_id, name, scope);
drop policy if exists datasets_read on public.datasets;
create policy datasets_read on public.datasets for select using (
  org_id in (select private.my_orgs()) and (scope = private.my_scope(org_id) or (name = 'catalogo' and scope = 'all')));

-- 4. Lo que escribe cada uno: notas de centro por zona; planes y tareas, de cada persona
alter table public.docs add column if not exists member_id uuid references public.members(id) on delete cascade;
alter table public.docs add column if not exists school_code text;
update public.docs set school_code = id where coll in ('fichas','notas','visitas') and school_code is null;
drop policy if exists docs_read on public.docs;
drop policy if exists docs_write on public.docs;
drop policy if exists docs_update on public.docs;
drop policy if exists docs_delete on public.docs;
create policy docs_read on public.docs for select using (org_id in (select private.my_orgs()) and (
  member_id = private.my_member_id(org_id)
  or (member_id is null and (school_code is null or private.code_ok(org_id, school_code)))
  or (member_id is not null and private.my_scope(org_id) = 'all' and private.my_role(org_id) in ('admin','manager'))));
create policy docs_write on public.docs for insert with check (org_id in (select private.my_orgs())
  and (member_id is null or member_id = private.my_member_id(org_id)) and (school_code is null or private.code_ok(org_id, school_code)));
create policy docs_update on public.docs for update using (org_id in (select private.my_orgs())
  and (member_id is null or member_id = private.my_member_id(org_id)) and (school_code is null or private.code_ok(org_id, school_code)))
  with check (org_id in (select private.my_orgs()) and (member_id is null or member_id = private.my_member_id(org_id)) and (school_code is null or private.code_ok(org_id, school_code)));
create policy docs_delete on public.docs for delete using (org_id in (select private.my_orgs())
  and (member_id is null or member_id = private.my_member_id(org_id)) and (school_code is null or private.code_ok(org_id, school_code)));

-- 5. Quien entra: se enlaza por su correo la primera vez (invitación) y recibe su rol y alcance
create or replace function public.mi_editorial() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare r jsonb;
begin
  update members set user_id = auth.uid()
  where user_id is null and lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    and not exists (select 1 from members m2 where m2.user_id = auth.uid());
  select jsonb_build_object('org', m.org_id, 'member', m.id, 'nombre', m.full_name, 'rol', m.role,
                            'editorial', o.name, 'propia', coalesce((select name from publishers p where p.org_id = m.org_id and p.is_own limit 1), o.name),
                            'curso', o.school_year, 'zona', coalesce(z.name, 'todas las zonas'), 'scope', private.my_scope(m.org_id), 'demo', o.slug = 'demo')
  into r
  from members m join orgs o on o.id = m.org_id left join zones z on z.id = m.zone_id
  where m.user_id = auth.uid() limit 1;
  return r;
end $$;
revoke all on function public.mi_editorial() from public, anon;
grant execute on function public.mi_editorial() to authenticated;

-- 6. Equipo: lo ven todos los de la editorial (nombre, rol y zona); solo el admin lo cambia
create or replace view public.equipo with (security_invoker = on) as
  select m.id, m.org_id, m.full_name, m.email, m.role, m.zone_id, z.name zone_name, m.user_id is not null activo, m.created_at
  from members m left join zones z on z.id = m.zone_id;
grant select on public.equipo to authenticated;

-- 7. Datos de la app por zona
create or replace function private.build_datasets_scope(p_org uuid, p_zone uuid) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_centros text; v_contactos text; v_rutas text; v_cat text; own text; v_scope text := coalesce(p_zone::text, 'all');
begin
  select name into own from publishers where org_id = p_org and is_own limit 1;

  -- CENTROS
  with lib as (
    select a.school_id, a.stage::text etapa, a.subject materia, private.area_of(a.subject, a.kind) area,
           coalesce(pb.name, 'Sin libro') editorial,
           coalesce(pr.title, a.title_raw, 'Sin libro de texto') titulo, a.adopted_year implantado,
           string_agg(distinct (case when a.stage = 'INF' then a.grade + 2 else a.grade end)::text, ',' order by (case when a.stage = 'INF' then a.grade + 2 else a.grade end)::text) cursos, sum(coalesce(a.students, 0)) alum
    from adoptions a left join publishers pb on pb.id = a.publisher_id left join products pr on pr.id = a.product_id
    where a.org_id = p_org
    group by 1, 2, 3, 4, 5, 6, 7),
  agg as (
    select school_id,
           jsonb_agg(jsonb_strip_nulls(jsonb_build_object('etapa', etapa, 'materia', materia, 'area', area, 'editorial', editorial, 'titulo', titulo,
                                                           'implantado', implantado, 'cursos', cursos, 'alum', alum)) order by etapa, materia) libros,
           sum(alum) filter (where area not in ('Diccionarios', 'Lecturas') and editorial <> 'Sin libro') am,
           sum(alum) filter (where area not in ('Diccionarios', 'Lecturas') and editorial = own) usr
    from lib group by school_id),
  en as (select school_id, sum(students) st from enrollment group by school_id)
  select 'const CENTROS=' || coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
           'id', s.code, 'nombre', s.name, 'localidad', s.city, 'prov', s.province, 'cp', s.postal_code,
           'tipo', case s.ownership when 'publico' then 'Público' when 'concertado' then 'Concertado' else 'Privado' end,
           'clase', case s.kind when 'IES' then 'IES' when 'Colegio' then 'COL' else 'COLE' end,
           'tam', case when coalesce(en.st, 0) > 900 then 'A' when en.st > 600 then 'B' when en.st > 400 then 'C' when en.st > 250 then 'D' when en.st > 120 then 'E' else 'F' end,
           'zona', z.name, 'repAntes', s.previous_rep, 'alumnos', coalesce(en.st, 0),
           'mkt', coalesce(agg.am, 0), 'am', coalesce(agg.am, 0), 'usr', coalesce(agg.usr, 0),
           'cuota', case when coalesce(agg.am, 0) > 0 then round(100.0 * coalesce(agg.usr, 0) / agg.am, 1) else 0 end,
           'libros', coalesce(agg.libros, '[]'::jsonb))) order by s.name), '[]'::jsonb)::text || ';'
  into v_centros
  from schools s left join agg on agg.school_id = s.id left join en on en.school_id = s.id left join zones z on z.id = s.zone_id
  where s.org_id = p_org and (p_zone is null or s.zone_id = p_zone);

  -- CONTACTOS
  with ppl as (
    select p.*, s.code,
           (select string_agg(case ps.kind when 'atencion_familias' then 'familias ' else 'libre ' end
                              || (array['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'])[ps.weekday] || ' ' || to_char(ps.starts, 'HH24:MI'), ' · ' order by ps.weekday, ps.starts)
            from person_slots ps where ps.person_id = p.id) horario
    from people p join schools s on s.id = p.school_id
    where p.org_id = p_org and p.active),
  prof as (
    select code, k, jsonb_agg(jsonb_build_array(full_name, coalesce(role_detail, ''), coalesce(email, ''), coalesce(horario, '')) order by role <> 'jefe_departamento', full_name) arr
    from (select ppl.*, case
            when stage = 'PRI' and department = 'Inglés' then 'Inglés Primaria'
            when stage = 'INF' and department = 'Inglés' then 'Inglés Infantil'
            when department = 'Infantil' then 'Coord. Infantil'
            else department end k from ppl where department is not null) x
    group by code, k),
  pj as (select code, jsonb_object_agg(k, arr) profs from prof group by code),
  c as (
    select s.code,
      jsonb_strip_nulls(jsonb_build_object(
        'cod', s.code, 'tel', s.phone, 'geo', case when s.lat is not null then jsonb_build_array(round(s.lat::numeric, 5), round(s.lon::numeric, 5)) end,
        'dir', (select jsonb_agg(jsonb_build_array(case role when 'direccion' then 'Director' when 'jefe_estudios' then 'Jefe de estudios' else 'Secretario' end, full_name, coalesce(email, '')) order by role)
                from ppl where ppl.school_id = s.id and role in ('direccion', 'jefe_estudios', 'secretaria')),
        'jefes', (select jsonb_agg(jsonb_build_array(department, full_name, coalesce(email, ''))) from ppl where ppl.school_id = s.id and role = 'jefe_departamento'),
        'coord', (select jsonb_agg(jsonb_build_array(role_detail, full_name, coalesce(email, ''))) from ppl where ppl.school_id = s.id and role = 'coordinador'),
        'ing', (select jsonb_agg(jsonb_build_array(coalesce(role_detail, 'Maestra de Inglés'), full_name, coalesce(email, ''))) from ppl where ppl.school_id = s.id and stage in ('PRI', 'INF') and department = 'Inglés' and role <> 'coordinador'),
        'profs', pj.profs,
        'profs_curso', '2026-2027',
        'fuente', jsonb_build_array('web del centro (demo)'))) v
    from schools s left join pj on pj.code = s.code where s.org_id = p_org and (p_zone is null or s.zone_id = p_zone))
  select 'const CONTACTOS=' || coalesce(jsonb_object_agg(code, v), '{}'::jsonb)::text || ';' into v_contactos from c;

  -- RUTAS: grupos de 5-6 centros cercanos por zona
  with s as (
    select sc.code, sc.lat, sc.lon, z.name zona,
           row_number() over (partition by z.name order by round(sc.lat::numeric, 2), sc.lon) rn
    from schools sc left join zones z on z.id = sc.zone_id where sc.org_id = p_org and sc.lat is not null and (p_zone is null or sc.zone_id = p_zone)),
  g as (select zona, (rn - 1) / 6 grp, jsonb_agg(code order by rn) ids, avg(lat) lat, avg(lon) lon,
               ceil(sum(1) * 2.5 + 6)::int km from s group by zona, (rn - 1) / 6)
  select 'const RUTAS=' || coalesce(jsonb_agg(jsonb_build_object('zona', zona, 'ids', ids, 'km', km, 'soria', false, 'lat', lat, 'lon', lon, 'n', n) order by n), '[]'::jsonb)::text || ';'
  into v_rutas
  from (select g.*, row_number() over (order by zona, grp) n from g) x;

  -- CATÁLOGO de la editorial propia (lo que la app ofrece en cada hueco)
  with own_p as (
    select pr.* from products pr join publishers pb on pb.id = pr.publisher_id
    where pr.org_id = p_org and pb.is_own),
  d as (
    select jsonb_build_array(title, stage::text,
             case private.area_of(subject, kind) when 'Lengua' then 'Lengua y Literatura' when 'Biología' then 'Ciencias' when 'Física y Química' then 'Ciencias'
               when 'Ciencias (castellano)' then 'Ciencias' when 'Lecturas' then 'Lecturas en castellano' when 'Filosofía' then 'Valores y Filosofía'
               else private.area_of(subject, kind) end,
             case when stage = 'INF' then '3 a 5 años' when cardinality(grades) = 1 then grades[1] || 'º'
                  when cardinality(grades) = 2 then grades[1] || 'º y ' || grades[2] || 'º'
                  else grades[1] || 'º a ' || grades[cardinality(grades)] || 'º' end,
             'Proyecto de ' || subject || ' de ' || own || ' (catálogo de demostración, cursos ' || array_to_string(grades, ', ') || ').', '#', case when launch_year >= 2025 then 1 end) j,
           title, stage, private.area_of(subject, kind) area
    from own_p)
  select 'const D=' || coalesce(jsonb_agg(j order by stage, area), '[]'::jsonb)::text || ';' || E'\n' ||
         'const INFO={};const COVERKEY={};const COVERS={};const DETAIL={};const NEWPRI=[];' || E'\n' ||
         'const CMP=' || coalesce(jsonb_object_agg(title, jsonb_build_array(area, '[]'::jsonb)), '{}'::jsonb)::text || ';' || E'\n' ||
         'const PRIO=' || coalesce((select jsonb_object_agg(stage, m) from (select stage, jsonb_object_agg(area, ts) m from (select stage::text stage, area, jsonb_agg(title) ts from d group by 1, 2) y group by stage) z), '{}'::jsonb)::text || ';'
  into v_cat from d;

  insert into datasets(org_id, name, scope, js) values
    (p_org, 'centros', v_scope, v_centros), (p_org, 'contactos', v_scope, v_contactos), (p_org, 'rutas', v_scope, v_rutas)
  on conflict (org_id, name, scope) do update set js = excluded.js, updated_at = now();
  if p_zone is null then
    insert into datasets(org_id, name, scope, js) values (p_org, 'catalogo', 'all', v_cat)
    on conflict (org_id, name, scope) do update set js = excluded.js, updated_at = now();
  end if;

  return jsonb_build_object('catalogo', length(v_cat), 'centros', length(v_centros), 'contactos', length(v_contactos), 'rutas', length(v_rutas));
end $$;
revoke all on function private.build_datasets_scope(uuid, uuid) from public, anon, authenticated;

create or replace function private.build_datasets(p_org uuid) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare z record; r jsonb;
begin
  delete from datasets where org_id = p_org;
  r := private.build_datasets_scope(p_org, null);
  for z in select id from zones where org_id = p_org loop
    perform private.build_datasets_scope(p_org, z.id);
  end loop;
  return r;
end $$;
revoke all on function private.build_datasets(uuid) from public, anon, authenticated;

-- 8. Demo con dos accesos: comercial (demo@textia.es, Laura Gómez, Valmayor capital) y dirección (direccion@textia.es, Carmen Velasco)
--    El usuario direccion@textia.es se crea igual que demo@textia.es en 0005 (contraseña pública textia-demo).
create or replace function private.demo_reset() returns jsonb
language plpgsql security definer set search_path = public as $$
declare r jsonb; v_org uuid;
begin
  r := private.demo_seed('demo');
  select id into v_org from orgs where slug = 'demo';
  insert into members(org_id, email, full_name, role, zone_id) values (v_org, 'direccion@demo.textia.es', 'Carmen Velasco', 'admin', null);
  update members m set user_id = u.id from auth.users u
  where m.org_id = v_org and ((u.email = 'demo@textia.es' and m.email = 'laura@demo.textia.es') or (u.email = 'direccion@textia.es' and m.email = 'direccion@demo.textia.es'));
  r := r || private.build_datasets(v_org);
  insert into docs(org_id, coll, id, data, school_code)
  select v_org, 'fichas', s.code, jsonb_build_object('recreo', to_char(min(ss.starts), 'HH24:MI') || '-' || to_char(min(ss.ends), 'HH24:MI')), s.code
  from schools s join school_slots ss on ss.school_id = s.id and ss.kind = 'recreo' where s.org_id = v_org group by s.code
  on conflict do nothing;
  insert into docs(org_id, coll, id, data, school_code)
  select v_org, 'visitas', s.code, jsonb_build_object('centro', s.code, 'fecha', to_char(max(v.visited_at), 'FMDD/FMMM/YYYY')), s.code
  from schools s join visits v on v.school_id = s.id where s.org_id = v_org group by s.code
  on conflict do nothing;
  return r;
end $$;
revoke all on function private.demo_reset() from public, anon, authenticated;
