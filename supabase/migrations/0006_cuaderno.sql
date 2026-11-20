-- Textia · capa de la app de campo (el antiguo Cuaderno, ahora multieditorial)
-- datasets: lo que carga la app al entrar (centros, contactos, rutas, catálogo), uno por editorial
-- docs: lo que escribe el comercial (fichas, notas, visitas, tareas, rivales...), por editorial

create table if not exists public.datasets (
  org_id uuid not null references public.orgs(id) on delete cascade,
  name text not null,
  js text not null,
  updated_at timestamptz not null default now(),
  primary key (org_id, name)
);
create table if not exists public.docs (
  org_id uuid not null references public.orgs(id) on delete cascade,
  coll text not null,
  id text not null,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  primary key (org_id, coll, id)
);
alter table public.datasets enable row level security;
alter table public.docs enable row level security;
create policy datasets_read on public.datasets for select using (org_id in (select private.my_orgs()));
create policy datasets_admin on public.datasets for all using (private.my_role(org_id) = 'admin') with check (private.my_role(org_id) = 'admin');
create policy docs_read on public.docs for select using (org_id in (select private.my_orgs()));
create policy docs_write on public.docs for insert with check (org_id in (select private.my_orgs()));
create policy docs_update on public.docs for update using (org_id in (select private.my_orgs())) with check (org_id in (select private.my_orgs()));
create policy docs_delete on public.docs for delete using (org_id in (select private.my_orgs()));
alter publication supabase_realtime add table public.docs;

-- Lo que la app necesita saber de quien entra
create or replace function public.mi_editorial() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('org', m.org_id, 'member', m.id, 'nombre', m.full_name, 'rol', m.role,
                            'editorial', o.name, 'propia', coalesce((select name from publishers p where p.org_id = m.org_id and p.is_own limit 1), o.name),
                            'curso', o.school_year, 'zona', z.name)
  from members m join orgs o on o.id = m.org_id left join zones z on z.id = m.zone_id
  where m.user_id = auth.uid() limit 1
$$;
revoke all on function public.mi_editorial() from public, anon;
grant execute on function public.mi_editorial() to authenticated;

create or replace function public.es_miembro() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from members where user_id = auth.uid())
$$;
revoke all on function public.es_miembro() from public, anon;
grant execute on function public.es_miembro() to authenticated;

-- Área de trabajo de cada materia (la que agrupa decisores y oferta)
create or replace function private.area_of(subject text, kind public.material_kind) returns text
language sql immutable as $$
  select case
    when kind = 'diccionario' then 'Diccionarios'
    when kind = 'lectura' then 'Lecturas'
    when subject = 'Biología y Geología' then 'Biología'
    when subject in ('Ciencias de la Naturaleza', 'Ciencias Sociales') then 'Ciencias (castellano)'
    when subject = 'Historia de España' then 'Geografía e Historia'
    else subject end
$$;

-- Construye los datasets de la app a partir de las tablas de una editorial
create or replace function private.build_datasets(p_org uuid) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_centros text; v_contactos text; v_rutas text; v_cat text; own text;
begin
  select name into own from publishers where org_id = p_org and is_own limit 1;

  -- CENTROS
  with lib as (
    select a.school_id, a.stage::text etapa, a.subject materia, private.area_of(a.subject, a.kind) area,
           coalesce(pb.name, 'Sin libro') editorial,
           coalesce(pr.title, a.title_raw, 'Sin libro de texto') titulo, a.adopted_year implantado,
           string_agg(distinct a.grade::text, ',' order by a.grade::text) cursos, sum(coalesce(a.students, 0)) alum
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
  where s.org_id = p_org;

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
        'ing', (select jsonb_agg(jsonb_build_array(coalesce(role_detail, 'Maestra de Inglés'), full_name, coalesce(email, ''))) from ppl where ppl.school_id = s.id and stage in ('PRI', 'INF') and department = 'Inglés'),
        'profs', pj.profs,
        'profs_curso', '2026-2027',
        'fuente', jsonb_build_array('web del centro (demo)'))) v
    from schools s left join pj on pj.code = s.code where s.org_id = p_org)
  select 'const CONTACTOS=' || coalesce(jsonb_object_agg(code, v), '{}'::jsonb)::text || ';' into v_contactos from c;

  -- RUTAS: grupos de 5-6 centros cercanos por zona
  with s as (
    select sc.code, sc.lat, sc.lon, z.name zona,
           row_number() over (partition by z.name order by round(sc.lat::numeric, 2), sc.lon) rn
    from schools sc left join zones z on z.id = sc.zone_id where sc.org_id = p_org and sc.lat is not null),
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
             case stage when 'PRI' then '1º a 6º' when 'ESO' then '1º a 4º' when 'BAC' then '1º y 2º' else '' end,
             'Proyecto de ' || subject || ' de ' || own || ' (catálogo de demostración).', '#', case when launch_year >= 2025 then 1 end) j,
           title, stage, private.area_of(subject, kind) area
    from own_p)
  select 'const D=' || coalesce(jsonb_agg(j order by stage, area), '[]'::jsonb)::text || ';' || E'\n' ||
         'const INFO={};const COVERKEY={};const COVERS={};const DETAIL={};const NEWPRI=[];' || E'\n' ||
         'const CMP=' || coalesce(jsonb_object_agg(title, jsonb_build_array(area, '[]'::jsonb)), '{}'::jsonb)::text || ';' || E'\n' ||
         'const PRIO=' || coalesce((select jsonb_object_agg(stage, m) from (select stage, jsonb_object_agg(area, ts) m from (select stage::text stage, area, jsonb_agg(title) ts from d group by 1, 2) y group by stage) z), '{}'::jsonb)::text || ';'
  into v_cat from d;

  insert into datasets(org_id, name, js) values
    (p_org, 'catalogo', v_cat), (p_org, 'centros', v_centros), (p_org, 'contactos', v_contactos), (p_org, 'rutas', v_rutas)
  on conflict (org_id, name) do update set js = excluded.js, updated_at = now();

  return jsonb_build_object('catalogo', length(v_cat), 'centros', length(v_centros), 'contactos', length(v_contactos), 'rutas', length(v_rutas));
end $$;
revoke all on function private.build_datasets(uuid) from public, anon, authenticated;

-- La demo: regenerar tablas, datasets y una campaña a medias en las notas de la app
create or replace function private.demo_reset() returns jsonb
language plpgsql security definer set search_path = public as $$
declare r jsonb; v_org uuid;
begin
  r := private.demo_seed('demo');
  select id into v_org from orgs where slug = 'demo';
  update members m set user_id = u.id from auth.users u
  where u.email = 'demo@textia.es' and m.email = 'laura@demo.textia.es' and m.org_id = v_org;
  r := r || private.build_datasets(v_org);
  -- recreos en la ficha y última visita de cada centro visitado
  insert into docs(org_id, coll, id, data)
  select v_org, 'fichas', s.code, jsonb_build_object('recreo', to_char(min(ss.starts), 'HH24:MI') || '-' || to_char(min(ss.ends), 'HH24:MI'))
  from schools s join school_slots ss on ss.school_id = s.id and ss.kind = 'recreo' where s.org_id = v_org group by s.code
  on conflict do nothing;
  insert into docs(org_id, coll, id, data)
  select v_org, 'visitas', s.code, jsonb_build_object('centro', s.code, 'fecha', to_char(max(v.visited_at), 'YYYY-MM-DD'))
  from schools s join visits v on v.school_id = s.id where s.org_id = v_org group by s.code
  on conflict do nothing;
  return r;
end $$;
revoke all on function private.demo_reset() from public, anon, authenticated;
