-- Vistas y funciones que usa la app. Todas respetan la seguridad por fila (security_invoker).

-- Resumen por centro: alumnos, cuota, qué defender y qué ganar el próximo curso, visitas y decisores
create or replace view public.school_summary with (security_invoker = on) as
with nxt as (select id org_id, split_part(school_year, '-', 1)::int + 1 as y from public.orgs),
ad as (
  select a.school_id,
         sum(a.students) filter (where pb.is_own) own_students,
         sum(a.students) market_students,
         sum(a.students) filter (where pb.is_own and a.renew_year <= n.y) defend,
         sum(a.students) filter (where not pb.is_own and a.renew_year <= n.y) win,
         count(*) filter (where pb.is_own) own_titles
  from public.adoptions a
  join public.publishers pb on pb.id = a.publisher_id
  join nxt n on n.org_id = a.org_id
  where a.kind = 'texto'
  group by a.school_id),
en as (select school_id, sum(students) students, array_agg(distinct stage) stages from public.enrollment group by school_id),
vi as (select school_id, max(visited_at) last_visit, count(*) visits from public.visits group by school_id),
pe as (
  select p.school_id,
         count(*) filter (where p.role in ('jefe_departamento', 'coordinador', 'direccion', 'jefe_estudios')) decision_makers,
         count(*) filter (where p.role in ('jefe_departamento', 'coordinador', 'direccion', 'jefe_estudios')
                          and exists (select 1 from public.person_contacts c where c.person_id = p.id)) decision_makers_seen
  from public.people p where p.active group by p.school_id)
select s.id, s.org_id, s.code, s.name, s.kind, s.ownership, s.city, s.lat, s.lon, s.phone, s.zone_id, s.rep_id, s.previous_rep,
       z.name zone_name, m.full_name rep_name, en.stages,
       coalesce(en.students, 0) students,
       coalesce(ad.own_students, 0) own_students,
       coalesce(ad.market_students, 0) market_students,
       case when coalesce(ad.market_students, 0) > 0 then round(100.0 * coalesce(ad.own_students, 0) / ad.market_students, 1) else 0 end share,
       coalesce(ad.defend, 0) defend, coalesce(ad.win, 0) win,
       vi.last_visit, coalesce(vi.visits, 0) visits,
       coalesce(pe.decision_makers, 0) decision_makers, coalesce(pe.decision_makers_seen, 0) decision_makers_seen
from public.schools s
left join public.zones z on z.id = s.zone_id
left join public.members m on m.id = s.rep_id
left join en on en.school_id = s.id
left join ad on ad.school_id = s.id
left join vi on vi.school_id = s.id
left join pe on pe.school_id = s.id;

-- Distancia aproximada por carretera (km): haversine x 1,25
create or replace function public.km_between(lat1 float8, lon1 float8, lat2 float8, lon2 float8) returns float8
language sql immutable as $$
  select 2 * 6371 * asin(sqrt(power(sin(radians(lat2 - lat1) / 2), 2) + cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lon2 - lon1) / 2), 2))) * 1.25
$$;

-- "Tengo X minutos": a quién puedo ver cerca que esté libre al llegar
create or replace function public.free_now(p_lat float8, p_lon float8, p_minutes int default 25, p_at timestamptz default now())
returns table (school_id uuid, school_name text, city text, km numeric, travel_min int,
               person_id uuid, full_name text, role public.person_role, role_detail text, department text,
               slot_kind text, starts time, ends time, seen boolean)
language sql stable security invoker set search_path = public as $$
  with t as (select (p_at at time zone 'Europe/Madrid') lt),
  near as (
    select s.id, s.name, s.city, km_between(p_lat, p_lon, s.lat, s.lon) km
    from schools s where s.lat is not null
  ),
  reach as (
    select n.*, ceil(n.km / 30.0 * 60 + 5)::int travel   -- 30 km/h de media en ciudad + 5 min de aparcar
    from near n
  )
  select r.id, r.name, r.city, round(r.km::numeric, 1), r.travel,
         p.id, p.full_name, p.role, p.role_detail, p.department,
         x.kind, x.starts, x.ends,
         exists (select 1 from person_contacts c where c.person_id = p.id)
  from reach r
  cross join t
  join people p on p.school_id = r.id and p.active
  join lateral (
    select ps.kind, ps.starts, ps.ends from person_slots ps
      where ps.person_id = p.id and ps.weekday = extract(isodow from t.lt)
    union all
    select 'recreo', ss.starts, ss.ends from school_slots ss
      where ss.school_id = r.id and ss.weekday = extract(isodow from t.lt) and ss.kind = 'recreo'
        and p.role in ('jefe_departamento', 'coordinador', 'profesor', 'tutor')
  ) x on true
  where r.travel + 10 <= p_minutes                                                -- llego y me quedan al menos 10 minutos
    and x.starts <= (t.lt + make_interval(mins => r.travel))::time              -- ya está libre cuando llego
    and x.ends >= (t.lt + make_interval(mins => r.travel + 10))::time           -- y sigue libre 10 minutos más
  order by (p.role in ('jefe_departamento', 'coordinador', 'direccion')) desc,
           exists (select 1 from person_contacts c where c.person_id = p.id),     -- primero los no vistos
           r.km
  limit 40
$$;
