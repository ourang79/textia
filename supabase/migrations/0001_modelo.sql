-- Textia · modelo de datos inicial
-- Cada editorial cliente (org) ve solo sus filas. Seguridad por fila en todas las tablas.

create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;
create schema if not exists private;

-- ---------- Organización y usuarios ----------
create table public.orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null,
  school_year text not null default '2026-27',     -- curso de trabajo actual
  created_at timestamptz not null default now()
);

create table public.zones (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  name text not null
);

create type public.member_role as enum ('admin', 'manager', 'rep');

create table public.members (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  email text not null,
  full_name text not null,
  role public.member_role not null default 'rep',
  zone_id uuid references public.zones(id) on delete set null,
  crm_user_id text,                                   -- id del usuario en Salesforce
  created_at timestamptz not null default now(),
  unique (org_id, email)
);

-- Funciones de acceso (security definer para no recursar en RLS)
create or replace function private.my_orgs() returns setof uuid
language sql stable security definer set search_path = public as $$
  select org_id from members where user_id = auth.uid()
$$;

create or replace function private.my_role(o uuid) returns public.member_role
language sql stable security definer set search_path = public as $$
  select role from members where user_id = auth.uid() and org_id = o limit 1
$$;

create or replace function private.my_member_id(o uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select id from members where user_id = auth.uid() and org_id = o limit 1
$$;

-- ---------- Mercado: centros y alumnos ----------
create type public.school_ownership as enum ('publico', 'concertado', 'privado');
create type public.stage as enum ('INF', 'PRI', 'ESO', 'BAC', 'FP', 'OTR');

create table public.schools (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  code text,                                          -- código oficial del centro
  name text not null,
  kind text,                                          -- CEIP, IES, CEO, Colegio...
  ownership public.school_ownership,
  address text, city text, province text, postal_code text,
  lat double precision, lon double precision,
  phone text, email text, web text,
  zone_id uuid references public.zones(id) on delete set null,
  rep_id uuid references public.members(id) on delete set null,   -- comercial asignado
  previous_rep text,                                  -- quién lo llevaba antes
  crm_id text,                                        -- id de cuenta en Salesforce
  notes text,
  created_at timestamptz not null default now(),
  unique (org_id, code)
);
create index on public.schools (org_id);
create index schools_name_trgm on public.schools using gin (name gin_trgm_ops);

-- Horarios generales del centro (recreos, entrada, salida)
create table public.school_slots (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  stage public.stage,
  weekday smallint not null check (weekday between 1 and 7),   -- 1 = lunes
  starts time not null, ends time not null,
  kind text not null default 'recreo'                  -- recreo, entrada, salida, comida
);
create index on public.school_slots (school_id);

create table public.enrollment (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  school_year text not null,
  stage public.stage not null,
  grade smallint not null,                             -- 1..6 (INF: 1=3 años)
  groups smallint,
  students integer not null default 0,
  source text, source_date date,
  unique (school_id, school_year, stage, grade)
);

-- ---------- Catálogo: editoriales y materiales ----------
create table public.publishers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  name text not null,
  is_own boolean not null default false,               -- la editorial cliente
  unique (org_id, name)
);

create type public.material_kind as enum ('texto', 'cuaderno', 'lectura', 'diccionario', 'digital', 'otro');

create table public.products (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  publisher_id uuid not null references public.publishers(id) on delete cascade,
  title text not null,
  series text,                                         -- proyecto / serie
  subject text not null,                               -- materia normalizada
  stage public.stage not null,
  grades smallint[] not null default '{}',
  kind public.material_kind not null default 'texto',
  isbn text,
  launch_year smallint,
  unique (org_id, isbn)
);
create index on public.products (org_id, subject, stage);

-- ---------- Adopciones: qué libro usa cada centro en cada curso ----------
create table public.adoptions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  school_year text not null,
  stage public.stage not null,
  grade smallint not null,
  subject text not null,
  track text not null default 'ORD',                   -- ORD, BIL (bilingüe), DIV (diversificación), REF...
  product_id uuid references public.products(id) on delete set null,
  publisher_id uuid references public.publishers(id) on delete set null,
  title_raw text,                                       -- tal como venía si no se identificó el producto
  kind public.material_kind not null default 'texto',
  students integer,                                     -- alumnos que lo usan (si se sabe)
  adopted_year smallint,                                -- año de implantación
  renew_year smallint,                                  -- curso en que puede cambiar
  source text not null default 'manual',                -- lista web, excel, crm, manual
  source_date date,
  confidence real,                                      -- 0..1 para lecturas automáticas
  created_at timestamptz not null default now()
);
create index on public.adoptions (org_id, school_id, school_year);
create index on public.adoptions (org_id, subject, stage, grade);

-- ---------- Personas: decisores y profesorado ----------
create type public.person_role as enum ('direccion', 'jefe_estudios', 'secretaria', 'jefe_departamento', 'coordinador', 'tutor', 'profesor', 'orientacion', 'otro');

create table public.people (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  full_name text not null,
  role public.person_role not null default 'profesor',
  role_detail text,                                     -- "Jefa de departamento de Inglés"
  department text,                                      -- Inglés, Lengua... o ciclo en primaria
  stage public.stage,
  grades smallint[],
  email text, phone text,
  source text not null default 'manual',
  source_date date,
  crm_id text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index on public.people (org_id, school_id);
create index people_name_trgm on public.people using gin (full_name gin_trgm_ops);

-- Cuándo se puede hablar con cada persona (atención a familias, horas libres, guardias)
create table public.person_slots (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  person_id uuid not null references public.people(id) on delete cascade,
  weekday smallint not null check (weekday between 1 and 7),
  starts time not null, ends time not null,
  kind text not null default 'libre'                   -- libre, atencion_familias, guardia
);
create index on public.person_slots (person_id);

-- ---------- Trabajo de campo ----------
create table public.visits (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  school_id uuid not null references public.schools(id) on delete cascade,
  rep_id uuid references public.members(id) on delete set null,
  visited_at timestamptz not null default now(),
  people uuid[] not null default '{}',                  -- con quién habló
  summary text,
  next_step text,
  next_date date,
  crm_id text, synced_at timestamptz,                   -- actividad creada en Salesforce
  created_at timestamptz not null default now()
);
create index on public.visits (org_id, school_id, visited_at desc);

-- Quién ha visto a quién (el "visto" por persona)
create table public.person_contacts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  person_id uuid not null references public.people(id) on delete cascade,
  rep_id uuid references public.members(id) on delete set null,
  seen_on date not null default current_date,
  visit_id uuid references public.visits(id) on delete set null
);
create index on public.person_contacts (person_id);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  rep_id uuid references public.members(id) on delete set null,
  school_id uuid references public.schools(id) on delete cascade,
  person_id uuid references public.people(id) on delete set null,
  title text not null,
  due date,
  done_at timestamptz,
  created_at timestamptz not null default now()
);

-- ---------- Importación ----------
create table public.import_templates (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  name text not null,
  target text not null,                                 -- schools, adoptions, people, enrollment...
  header_signature text not null,                       -- cabeceras normalizadas, para reconocer el formato
  mapping jsonb not null,                               -- columna origen -> campo destino + transformaciones
  created_by uuid references public.members(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (org_id, target, header_signature)
);

create table public.import_jobs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs(id) on delete cascade,
  file_name text not null,
  target text,
  template_id uuid references public.import_templates(id) on delete set null,
  status text not null default 'nuevo',                 -- nuevo, mapeado, cargado, error
  mapping jsonb,
  stats jsonb,
  errors jsonb,
  created_by uuid references public.members(id) on delete set null,
  created_at timestamptz not null default now()
);

-- ---------- Registro de accesos y cambios ----------
create table public.audit_log (
  id bigint generated always as identity primary key,
  org_id uuid references public.orgs(id) on delete cascade,
  user_id uuid,
  action text not null,
  entity text, entity_id uuid,
  detail jsonb,
  at timestamptz not null default now()
);

-- ---------- Seguridad por fila ----------
do $$
declare t text;
begin
  foreach t in array array['zones','members','schools','school_slots','enrollment','publishers','products','adoptions',
                           'people','person_slots','visits','person_contacts','tasks','import_templates','import_jobs','audit_log']
  loop
    execute format('alter table public.%I enable row level security', t);
    -- leer: cualquier miembro de la editorial
    execute format('create policy %I on public.%I for select using (org_id in (select private.my_orgs()))', t || '_read', t);
  end loop;
end $$;

alter table public.orgs enable row level security;
create policy orgs_read on public.orgs for select using (id in (select private.my_orgs()));

-- Escritura de datos de trabajo: cualquier miembro (comercial incluido)
do $$
declare t text;
begin
  foreach t in array array['visits','person_contacts','tasks','people','person_slots','school_slots','import_jobs']
  loop
    execute format('create policy %I on public.%I for insert with check (org_id in (select private.my_orgs()))', t || '_ins', t);
    execute format('create policy %I on public.%I for update using (org_id in (select private.my_orgs())) with check (org_id in (select private.my_orgs()))', t || '_upd', t);
  end loop;
  -- Datos maestros y borrados: solo admin y jefe de zona
  foreach t in array array['zones','schools','enrollment','publishers','products','adoptions','import_templates',
                           'visits','person_contacts','tasks','people','person_slots','school_slots','import_jobs']
  loop
    execute format('create policy %I on public.%I for all using (private.my_role(org_id) in (''admin'',''manager'')) with check (private.my_role(org_id) in (''admin'',''manager''))', t || '_admin', t);
  end loop;
end $$;

-- Miembros: solo el admin gestiona el equipo
create policy members_admin on public.members for all
  using (private.my_role(org_id) = 'admin') with check (private.my_role(org_id) = 'admin');

-- Registro: insertar desde la app, nunca editar
create policy audit_ins on public.audit_log for insert with check (org_id in (select private.my_orgs()));
