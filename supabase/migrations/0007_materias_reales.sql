-- Textia · demo con las materias reales de cada curso
-- Fuente: listas de libros 2026-27 publicadas por los centros de Castilla y León (LOMLOE: Decretos 38/2022, 39/2022 y 40/2022).
-- prob = parte de los centros que pide libro de esa materia; grp = materias que van juntas (Latín y Griego);
-- clil_alt = versión en inglés de la materia en secciones bilingües.

create or replace function private.h01(t text) returns float8
language sql immutable as $$ select ('x' || substr(md5(t), 1, 8))::bit(32)::bigint / 4294967296.0 $$;

drop table if exists private.demo_plan;
create table private.demo_plan (stage public.stage, grades smallint[], subject text, prob real, grp text, clil_alt text, clil_p real, clil boolean default false);
insert into private.demo_plan(stage, grades, subject, prob, grp, clil_alt, clil_p) values
 ('INF','{1,2,3}','Proyecto globalizado',0.85,'glob',null,null),
 ('INF','{1,2,3}','Inglés',1,'ing',null,null),
 ('INF','{1,2,3}','Matemáticas',0.6,'mat',null,null),
 ('INF','{1,2,3}','Lengua',0.55,'len',null,null),
 ('PRI','{1,2,3,4,5,6}','Lengua',1,'len',null,null),
 ('PRI','{1,2,3,4,5,6}','Matemáticas',1,'mat',null,null),
 ('PRI','{1,2,3,4,5,6}','Inglés',1,'ing',null,null),
 ('PRI','{1,2,3,4,5,6}','Ciencias Naturales',1,'cn','Natural Science',0.9),
 ('PRI','{1,2,3,4,5,6}','Ciencias Sociales',1,'cs','Social Science',0.35),
 ('PRI','{1,2,3,4,5,6}','Plástica',0.55,'pla','Arts and Crafts',0.85),
 ('PRI','{1,2,3,4,5,6}','Música',0.4,'mus',null,null),
 ('PRI','{1,2,3,4,5,6}','Religión',0.4,'rel',null,null),
 ('PRI','{5}','Valores',0.35,'val',null,null),
 ('PRI','{5,6}','Francés',0.3,'fra',null,null),
 ('ESO','{1,2,3,4}','Lengua',1,'len',null,null),
 ('ESO','{1,2,3,4}','Matemáticas',1,'mat',null,null),
 ('ESO','{4}','Matemáticas A',0.8,'mata',null,null),
 ('ESO','{1,2,3,4}','Inglés',1,'ing',null,null),
 ('ESO','{1,2,3,4}','Geografía e Historia',1,'geh','Geography and History',0.6),
 ('ESO','{1,3,4}','Biología y Geología',1,'byg','Biology and Geology',0.4),
 ('ESO','{2,3,4}','Física y Química',1,'fyq',null,null),
 ('ESO','{1,3,4}','Tecnología',0.9,'tec','Technology',0.3),
 ('ESO','{1,2,3,4}','Francés',0.95,'fra',null,null),
 ('ESO','{1,2,3,4}','Alemán',0.12,'ale',null,null),
 ('ESO','{3}','Valores',0.6,'val',null,null),
 ('ESO','{4}','Digitalización',0.55,'dig',null,null),
 ('BAC','{1,2}','Lengua',1,'len',null,null),
 ('BAC','{1,2}','Inglés',1,'ing',null,null),
 ('BAC','{1}','Filosofía',1,'fil',null,null),
 ('BAC','{2}','Historia de la Filosofía',1,'hfil',null,null),
 ('BAC','{2}','Historia',1,'his',null,null),
 ('BAC','{1,2}','Matemáticas CCNN',1,'matn',null,null),
 ('BAC','{1,2}','Matemáticas CCSS',1,'mats',null,null),
 ('BAC','{1}','Física y Química',1,'fyq',null,null),
 ('BAC','{1}','Biología y Geología',1,'byg',null,null),
 ('BAC','{2}','Física',1,'fis',null,null),
 ('BAC','{2}','Química',1,'qui',null,null),
 ('BAC','{2}','Biología',1,'bio',null,null),
 ('BAC','{1}','Literatura Universal',0.95,'lu',null,null),
 ('BAC','{1}','Hª Mundo Contemporáneo',0.85,'hmc',null,null),
 ('BAC','{1,2}','Francés',0.9,'fra',null,null),
 ('BAC','{1,2}','Latín',0.25,'clas',null,null),
 ('BAC','{1,2}','Griego',0.25,'clas',null,null);
-- Versiones bilingües (CLIL) como materias propias del catálogo
insert into private.demo_plan(stage, grades, subject, prob, grp, clil)
select stage, grades, clil_alt, 0, clil_alt, true from private.demo_plan where clil_alt is not null;
revoke all on private.demo_plan from public, anon, authenticated;

create or replace function private.area_of(subject text, kind public.material_kind) returns text
language sql immutable as $$
  select case
    when kind = 'diccionario' then 'Diccionarios'
    when kind = 'lectura' then 'Lecturas'
    when subject in ('Natural Science','Social Science','Arts and Crafts','Geography and History','Biology and Geology','Technology') then 'CLIL'
    when subject in ('Biología y Geología','Biología') then 'Biología'
    when subject in ('Física','Química') then 'Física y Química'
    when subject in ('Ciencias Naturales','Ciencias Sociales') then 'Ciencias (castellano)'
    when subject in ('Historia','Geografía') then 'Geografía e Historia'
    when subject = 'Historia de la Filosofía' then 'Filosofía'
    when subject in ('Matemáticas A','Matemáticas CCNN','Matemáticas CCSS') then 'Matemáticas'
    when subject = 'Proyecto globalizado' then 'Globalizado'
    else subject end
$$;

create or replace function private.demo_seed(p_slug text default 'demo') returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
#variable_conflict use_column
declare
  v_org uuid; v_z1 uuid; v_z2 uuid; v_z3 uuid;
  v_mgr uuid; v_rep1 uuid; v_rep2 uuid; v_rep3 uuid;
  v_year text := '2026-27';
  pubs uuid[] := '{}'; pub_names text[] := array['Tu Editorial','Ediciones Brezal','Grupo Lirio Educa','Kestrel Learning','Pórtico Editorial','Astrolabio Educación'];
  pub_w real[] := array[0.24, 0.22, 0.18, 0.14, 0.12, 0.10];
  first_f text[] := array['Lucía','Marta','Elena','Carmen','Laura','Isabel','Paula','Sara','Beatriz','Nuria','Pilar','Rocío','Cristina','Ana','Raquel','Silvia','Irene','Teresa','Alicia','Verónica','Noelia','Esther','Patricia','Inés','Begoña','Montse','Rosa','Julia'];
  first_m text[] := array['Javier','Daniel','Pablo','Alberto','Sergio','Jorge','Rubén','Óscar','Luis','Miguel','Andrés','Iñigo','Raúl','Fernando','David','Carlos','Álvaro','Ignacio','Víctor','Mario','Diego','Hugo','Gonzalo','Tomás'];
  surn text[] := array['Arranz','Benito','Calvo','Cuesta','del Olmo','Escudero','Fuentes','Gallego','Herrero','Ibáñez','Juárez','Lorenzo','Llorente','Manso','Marcos','Nieto','Ortega','Pastor','Peña','Prieto','Quintana','Rubio','Sanz','Tejedor','Urueña','Valverde','Velasco','Zamora','Aguado','Bermejo','Carrascal','Domingo','Encinas','Frutos','Garrido','Hidalgo','Izquierdo','Lobato','Mediavilla','Olmedo','Pardo','Recio','Salcedo','Toribio','Vaquero','Yagüe'];
  nat text[] := array['Los Almendros','La Vega','El Pinar','Las Acacias','Valle del Sol','Río Claro','Las Eras','El Soto','La Atalaya','Los Tilos','El Mirador','La Fuente','Las Lomas','Monte Alto','El Prado','La Ribera','Los Olmos','La Alameda','El Encinar','Cañada Real','Los Sauces','La Dehesa','El Molino','Las Viñas','Campo Verde','La Solana','El Cerro','Los Robles','La Huerta','El Arroyo','Las Moreras','La Colina','El Valle','Los Pinos','La Noria','Peña Blanca','Las Rozas Altas','El Puente','La Cañada','Los Fresnos'];
  saint text[] := array['Santa Inés','San Rafael','Nuestra Señora del Valle','San Gabriel','Santa Clara','San Ignacio','Santa Lucía','San Agustín','María Auxiliadora','La Anunciación','San Bernardo','Santa Teresa del Pilar','Sagrada Familia','San Juan Bosco','Santo Domingo','Virgen del Carmen','San José Obrero','La Milagrosa del Valle','San Benito','Santa Rita'];
  towns text[] := array['Valmayor','Valmayor','Valmayor','Valmayor','Arroyo del Valle','Villanueva de Campos','San Ginés del Monte','Torrecilla','Puenteseca','Fuentelaguna','Castrillo de la Vega'];
  town_lat real[] := array[41.205,41.205,41.205,41.205,41.168,41.262,41.152,41.297,41.231,41.118,41.276];
  town_lon real[] := array[-4.605,-4.605,-4.605,-4.605,-4.652,-4.571,-4.556,-4.688,-4.731,-4.598,-4.489];
  sch record; s_id uuid; n_sch int := 0; i int; g int; st public.stage; grp int; kind text; own public.school_ownership;
  t_idx int; t_name text; nm text; r real; acc real; pick_pub int; prod uuid; subj text; ren int;
  ser text[][] := array[
    -- INF, PRI, ESO, BAC, Inglés (INF, PRI, ESO, BAC)
    ['Pompas','Cometa','Faro','Zenit','Little Stars','Bright Path','Skyline','Next Level'],
    ['Semillas','Raíces','Senda','Ágora','Tiny Hands','Open Doors','Real Talk','Upgrade'],
    ['Burbujas','Mosaico','Prisma','Nexo','Hello Friends','Step Up','Way Ahead','Insight Plus'],
    ['Little Steps','Wonder Kids','Pathfinders','Key Skills','Little Steps','Wonder Kids','Pathfinders','Key Skills'],
    ['Nubes','Trazos','Brújula','Atlas','Sunny Days','High Five','Get Going','Focus On'],
    ['Garabatos','Vuela','Horizonte','Órbita','Rainbow','Spark','Next Stop','Advance']];
  w_en real[] := array[0.25, 0.12, 0.12, 0.33, 0.08, 0.10];
  w_es real[] := array[0.27, 0.25, 0.20, 0.00, 0.16, 0.12];
  w real[]; pl record; bil_pri boolean; bil_eso boolean; cyc text; si int; nprod int := 0; disp text;
  p_id uuid; p_role public.person_role; dept text; cnt int := 0; nvis int := 0;
  persons uuid[]; v_id uuid; d date; reps uuid[];
begin
  perform setseed(0.4242);
  delete from orgs where slug = p_slug;
  insert into orgs(name, slug, school_year) values ('Tu Editorial (demo)', p_slug, v_year) returning id into v_org;
  insert into zones(org_id, name) values (v_org, 'Valmayor capital') returning id into v_z1;
  insert into zones(org_id, name) values (v_org, 'Alfoz norte') returning id into v_z2;
  insert into zones(org_id, name) values (v_org, 'Campiña sur') returning id into v_z3;
  insert into members(org_id, email, full_name, role, zone_id) values (v_org, 'jefa.zona@demo.textia.es', 'Marta Ibáñez', 'manager', null) returning id into v_mgr;
  insert into members(org_id, email, full_name, role, zone_id) values (v_org, 'laura@demo.textia.es', 'Laura Gómez', 'rep', v_z1) returning id into v_rep1;
  insert into members(org_id, email, full_name, role, zone_id) values (v_org, 'pablo@demo.textia.es', 'Pablo Ruiz', 'rep', v_z2) returning id into v_rep2;
  insert into members(org_id, email, full_name, role, zone_id) values (v_org, 'nuria@demo.textia.es', 'Nuria Sastre', 'rep', v_z3) returning id into v_rep3;
  reps := array[v_rep1, v_rep2, v_rep3];

  for i in 1..array_length(pub_names, 1) loop
    insert into publishers(org_id, name, is_own) values (v_org, pub_names[i], i = 1) returning id into prod;
    pubs := pubs || prod;
  end loop;

  -- Catálogo: cada editorial publica un proyecto por etapa y materia, con los cursos en que existe la materia
  -- (Kestrel Learning es especialista en inglés: solo Inglés y materias bilingües)
  for i in 1..array_length(pubs, 1) loop
    for pl in select p.stage, p.subject, array_agg(distinct gg order by gg) grades from private.demo_plan p, unnest(p.grades) gg
              where i <> 4 or p.subject in ('Inglés') or p.clil group by 1, 2 loop
      si := case pl.stage when 'INF' then 1 when 'PRI' then 2 when 'ESO' then 3 else 4 end;
      disp := case pl.subject when 'Lengua' then case pl.stage when 'INF' then 'Lectoescritura' when 'PRI' then 'Lengua Castellana' else 'Lengua Castellana y Literatura' end
                when 'Proyecto globalizado' then 'Proyecto' when 'Valores' then 'Valores Cívicos y Éticos' when 'Plástica' then 'Educación Plástica'
                when 'Matemáticas CCNN' then 'Matemáticas' when 'Matemáticas CCSS' then 'Matemáticas Aplicadas a las CC. SS.'
                when 'Hª Mundo Contemporáneo' then 'Historia del Mundo Contemporáneo' when 'Historia' then 'Historia de España'
                when 'Matemáticas A' then 'Matemáticas A' else pl.subject end;
      nprod := nprod + 1;
      insert into products(org_id, publisher_id, title, series, subject, stage, grades, kind, isbn, launch_year)
      values (v_org, pubs[i],
              case when pl.subject = 'Inglés' then ser[i][4 + si] else disp || ' · ' || ser[i][si] end,
              case when pl.subject = 'Inglés' then ser[i][4 + si] else ser[i][si] end,
              pl.subject, pl.stage, pl.grades, 'texto', '978-84-' || lpad(nprod::text, 5, '0'), 2022 + floor(random() * 4)::int);
    end loop;
    insert into products(org_id, publisher_id, title, subject, stage, grades, kind, isbn)
      values (v_org, pubs[i], 'Diccionario escolar ' || pub_names[i], 'Inglés', 'ESO', '{1,2,3,4}', 'diccionario', '978-84-D' || i),
             (v_org, pubs[i], 'Lecturas graduadas ' || pub_names[i], 'Inglés', 'PRI', '{3,4,5,6}', 'lectura', '978-84-L' || i);
  end loop;

  -- Centros
  for i in 1..92 loop
    r := random();
    if i <= 40 then kind := 'CEIP'; own := 'publico';
    elsif i <= 56 then kind := 'IES'; own := 'publico';
    elsif i <= 84 then kind := 'Colegio'; own := 'concertado';
    elsif i <= 89 then kind := 'Colegio'; own := 'privado';
    else kind := 'CEO'; own := 'publico'; end if;
    t_idx := 1 + floor(random() * array_length(towns, 1))::int;
    t_name := towns[t_idx];
    nm := case when own = 'publico' then kind || ' ' || nat[1 + ((i * 7) % array_length(nat, 1))]
               else 'Colegio ' || saint[1 + ((i * 3) % array_length(saint, 1))] end;
    if exists (select 1 from schools where org_id = v_org and name = nm) then nm := nm || ' (' || t_name || ')'; end if;
    insert into schools(org_id, code, name, kind, ownership, address, city, province, postal_code, lat, lon, phone, email,
                        zone_id, rep_id, previous_rep)
    values (v_org, 'DEMO' || lpad(i::text, 4, '0'), nm, kind, own,
            'Calle ' || private.pick(nat) || ', ' || (1 + floor(random() * 60))::int, t_name, 'Valmayor', '49' || lpad((100 + i)::text, 3, '0'),
            town_lat[t_idx] + (random() - 0.5) * case when t_name = 'Valmayor' then 0.05 else 0.012 end,
            town_lon[t_idx] + (random() - 0.5) * case when t_name = 'Valmayor' then 0.07 else 0.016 end,
            '9' || (10000000 + floor(random() * 89999999))::bigint, 'centro' || i || '@demo.textia.es',
            case when t_name = 'Valmayor' then v_z1 when t_idx in (6, 8, 9, 11) then v_z2 else v_z3 end,
            case when t_name = 'Valmayor' then v_rep1 when t_idx in (6, 8, 9, 11) then v_rep2 else v_rep3 end,
            case when random() < 0.4 then private.pick(first_m) || ' ' || private.pick(surn) else null end)
    returning id into s_id;
    n_sch := n_sch + 1;
    bil_pri := private.h01(s_id::text || 'bilpri') < 0.45;
    bil_eso := private.h01(s_id::text || 'bileso') < 0.40;

    -- Etapas que imparte
    for st in select unnest(case
        when kind = 'CEIP' then array['INF','PRI']
        when kind = 'IES' then array['ESO','BAC']
        when kind = 'CEO' then array['INF','PRI','ESO']
        when own = 'privado' or random() < 0.45 then array['INF','PRI','ESO','BAC']
        else array['INF','PRI','ESO'] end::public.stage[]) loop
      grp := case when kind = 'IES' then 2 + floor(random() * 4)::int when t_name = 'Valmayor' then 1 + floor(random() * 3)::int else 1 + floor(random() * 2)::int end;
      for g in 1..(case st when 'INF' then 3 when 'PRI' then 6 when 'ESO' then 4 else 2 end) loop
        insert into enrollment(org_id, school_id, school_year, stage, grade, groups, students, source, source_date)
        values (v_org, s_id, v_year, st, g, grp, grp * (19 + floor(random() * 7))::int, 'demo', date '2026-10-01');
        -- Adopciones: materias reales de cada curso (LOMLOE en Castilla y León, según las listas de libros publicadas por los centros)
        for pl in select * from private.demo_plan p where p.stage = st and g = any(p.grades) and not p.clil loop
          if private.h01(s_id::text || pl.grp) >= pl.prob then continue; end if;
          subj := pl.subject;
          -- Secciones bilingües: algunas materias se dan en inglés con su propio libro (CLIL)
          if pl.clil_alt is not null and ((st = 'PRI' and bil_pri) or (st = 'ESO' and bil_eso))
             and private.h01(s_id::text || pl.clil_alt) < pl.clil_p then subj := pl.clil_alt; end if;
          if random() < 0.05 and subj not in ('Inglés','Lengua','Matemáticas','Proyecto globalizado') then
            insert into adoptions(org_id, school_id, school_year, stage, grade, subject, title_raw, kind, students, source, source_date)
            values (v_org, s_id, v_year, st, g, subj, 'Sin libro de texto', 'otro', null, 'lista web', date '2026-07-10');
            continue;
          end if;
          -- La misma editorial en todo el ciclo (a veces cambia de un ciclo a otro)
          cyc := case st when 'PRI' then ((g + 1) / 2)::text when 'ESO' then case when g <= 2 then '1' else '2' end else '1' end;
          w := case when subj = 'Inglés' or exists (select 1 from private.demo_plan x where x.subject = subj and x.clil) then w_en else w_es end;
          r := private.h01(s_id::text || st::text || subj || cyc); acc := 0; pick_pub := 6;
          for t_idx in 1..6 loop acc := acc + w[t_idx]; if r <= acc then pick_pub := t_idx; exit; end if; end loop;
          select id into prod from products where org_id = v_org and publisher_id = pubs[pick_pub] and subject = subj and stage = st and kind = 'texto' limit 1;
          ren := 2027 + floor(private.h01(s_id::text || subj || cyc || 'ren') * 4)::int;
          insert into adoptions(org_id, school_id, school_year, stage, grade, subject, track, product_id, publisher_id, kind, students,
                                adopted_year, renew_year, source, source_date, confidence)
          values (v_org, s_id, v_year, st, g, subj, 'ORD', prod, pubs[pick_pub], 'texto', grp * 22, ren - 4, ren,
                  case when random() < 0.7 then 'lista web' else 'excel' end, date '2026-07-10', 0.9 + random() * 0.1);
          -- Inglés: grupos de sección bilingüe y de diversificación con otro libro
          if subj = 'Inglés' and st = 'ESO' and bil_eso and random() < 0.6 then
            insert into adoptions(org_id, school_id, school_year, stage, grade, subject, track, product_id, publisher_id, kind, students, adopted_year, renew_year, source, source_date)
            select v_org, s_id, v_year, st, g, subj, 'BIL', p.id, p.publisher_id, 'texto', 25, ren - 4, ren, 'lista web', date '2026-07-10'
            from products p where p.org_id = v_org and p.subject = 'Inglés' and p.stage = st and p.kind = 'texto' and p.publisher_id <> pubs[pick_pub] order by random() limit 1;
          end if;
          if subj = 'Inglés' and st = 'ESO' and g in (3, 4) and kind = 'IES' and random() < 0.5 then
            insert into adoptions(org_id, school_id, school_year, stage, grade, subject, track, product_id, publisher_id, kind, students, adopted_year, renew_year, source, source_date)
            select v_org, s_id, v_year, st, g, subj, 'DIV', p.id, p.publisher_id, 'texto', 12, ren - 4, ren, 'lista web', date '2026-07-10'
            from products p where p.org_id = v_org and p.subject = 'Inglés' and p.stage = st and p.kind = 'texto' order by random() limit 1;
          end if;
        end loop;
        if st = 'ESO' and g in (1, 3) and random() < 0.3 then
          insert into adoptions(org_id, school_id, school_year, stage, grade, subject, product_id, publisher_id, kind, students, source, source_date)
          select v_org, s_id, v_year, st, g, 'Inglés', p.id, p.publisher_id, 'diccionario', null, 'lista web', date '2026-07-10'
          from products p where p.org_id = v_org and p.kind = 'diccionario' order by random() limit 1;
        end if;
      end loop;
    end loop;

    -- Recreos
    for g in 1..5 loop
      insert into school_slots(org_id, school_id, stage, weekday, starts, ends, kind)
      values (v_org, s_id, case when kind = 'IES' then 'ESO' else 'PRI' end::public.stage, g,
              case when kind = 'IES' then time '11:05' else time '11:30' end, case when kind = 'IES' then time '11:35' else time '12:00' end, 'recreo');
    end loop;

    -- Personas
    persons := '{}';
    foreach dept in array array['direccion','jefe_estudios','secretaria'] loop
      insert into people(org_id, school_id, full_name, role, role_detail, source, source_date)
      values (v_org, s_id, case when random() < 0.6 then private.pick(first_f) else private.pick(first_m) end || ' ' || private.pick(surn) || ' ' || private.pick(surn),
              dept::public.person_role, case dept when 'direccion' then 'Dirección' when 'jefe_estudios' then 'Jefatura de estudios' else 'Secretaría' end, 'web del centro', date '2026-09-20')
      returning id into p_id; persons := persons || p_id;
    end loop;
    if kind in ('IES') or (kind in ('Colegio','CEO') and exists (select 1 from enrollment where school_id = s_id and stage = 'ESO')) then
      foreach dept in array array['Inglés','Lengua','Matemáticas','Geografía e Historia','Biología y Geología','Física y Química','Francés','Tecnología','Música','Dibujo','Educación Física','Filosofía','Latín y Griego','Orientación']
                           || case when kind = 'IES' then array['Economía','Alemán'] when exists (select 1 from adoptions where school_id = s_id and subject = 'Alemán') then array['Alemán'] else array[]::text[] end loop
        if kind <> 'IES' and dept in ('Latín y Griego','Filosofía') and not exists (select 1 from enrollment where school_id = s_id and stage = 'BAC') then continue; end if;
        for g in 0..(case when kind = 'IES' and dept in ('Inglés','Lengua','Matemáticas') then 3 when kind = 'IES' then 1 else 0 end) loop
          insert into people(org_id, school_id, full_name, role, role_detail, department, stage, email, source, source_date)
          values (v_org, s_id, case when random() < 0.6 then private.pick(first_f) else private.pick(first_m) end || ' ' || private.pick(surn) || ' ' || private.pick(surn),
                  case when g = 0 then 'jefe_departamento' else 'profesor' end::public.person_role,
                  case when g = 0 then 'Jefatura de departamento de ' || dept else 'Profesorado de ' || dept end, dept, 'ESO',
                  case when random() < 0.5 then 'profe' || floor(random() * 99999)::int || '@demo.textia.es' end, 'web del centro', date '2026-09-20')
          returning id into p_id; persons := persons || p_id;
        end loop;
      end loop;
    end if;
    if kind in ('CEIP','CEO','Colegio') then
      foreach dept in array array['Coordinación Infantil','Coordinación 1er ciclo','Coordinación 2º ciclo','Coordinación 3er ciclo','Inglés','Inglés Infantil']
                           || case when bil_pri then array['Coordinación de la sección bilingüe'] else array[]::text[] end
                           || case when exists (select 1 from adoptions where school_id = s_id and stage = 'PRI' and subject = 'Francés') then array['Maestra de Francés'] else array[]::text[] end loop
        insert into people(org_id, school_id, full_name, role, role_detail, department, stage, email, source, source_date)
        values (v_org, s_id, case when random() < 0.75 then private.pick(first_f) else private.pick(first_m) end || ' ' || private.pick(surn) || ' ' || private.pick(surn),
                case when dept like 'Coord%' or dept like 'Maestra%' then 'coordinador' else 'profesor' end::public.person_role,
                case when dept like 'Coord%' or dept like 'Maestra%' then dept when dept = 'Inglés Infantil' then 'Maestra de Inglés de Infantil' else 'Maestra de Inglés de Primaria' end,
                case when dept = 'Coordinación Infantil' then 'Infantil' when dept like 'Coordinación de la sección%' then 'Bilingüismo' when dept like 'Coord%' then replace(dept, 'Coordinación ', '') when dept like 'Maestra%' then 'Francés' else 'Inglés' end,
                case when dept like '%Infantil' then 'INF' else 'PRI' end::public.stage,
                case when random() < 0.4 then 'maestra' || floor(random() * 99999)::int || '@demo.textia.es' end, 'web del centro', date '2026-09-20')
        returning id into p_id; persons := persons || p_id;
      end loop;
    end if;
    -- Huecos de cada persona: 1-3 horas libres y, a veces, atención a familias
    insert into person_slots(org_id, person_id, weekday, starts, ends, kind)
    select v_org, pid, 1 + floor(random() * 5)::int, h, h + interval '55 minutes', case when random() < 0.25 then 'atencion_familias' else 'libre' end
    from unnest(persons) pid, lateral (select (array[time '09:00', time '09:55', time '10:50', time '12:00', time '12:55', time '13:50'])[1 + floor(random() * 6)::int] h, generate_series(1, 1 + floor(random() * 3)::int)) x;
    cnt := cnt + array_length(persons, 1);

    -- Campaña a medias: visitas de octubre-noviembre a algo menos de la mitad de los centros
    if random() < 0.45 then
      for g in 1..(1 + floor(random() * 3)::int) loop
        d := date '2026-10-01' + floor(random() * 50)::int;
        insert into visits(org_id, school_id, rep_id, visited_at, people, summary, next_step, next_date)
        select v_org, s_id, sc.rep_id, d + time '10:00' + (floor(random() * 5) || ' hours')::interval,
               (select array_agg(x) from (select x from unnest(persons) x order by random() limit 1 + floor(random() * 2)::int) y),
               private.pick(array['Presentación de novedades de Inglés','Entrega de muestras a Lengua','Reunión con jefatura de estudios','Charla en el recreo con el departamento','Formación digital al claustro']),
               private.pick(array['Llevar muestra de 3º','Volver tras la reunión de departamento','Enviar acceso a la plataforma','Proponer formación en enero','Nada pendiente']),
               d + 14 + floor(random() * 30)::int
        from schools sc where sc.id = s_id
        returning id into v_id;
        insert into person_contacts(org_id, person_id, rep_id, seen_on, visit_id)
        select v_org, x, vv.rep_id, vv.visited_at::date, vv.id from visits vv, unnest(vv.people) x where vv.id = v_id;
        nvis := nvis + 1;
      end loop;
    end if;
  end loop;

  insert into tasks(org_id, rep_id, school_id, title, due)
  select v_org, s.rep_id, s.id, private.pick(array['Llevar muestra a Inglés','Llamar a jefatura de estudios','Confirmar formación','Preguntar por el cambio de libro de 3º']), current_date + floor(random() * 20)::int
  from schools s where s.org_id = v_org order by random() limit 25;

  return jsonb_build_object('org', v_org, 'centros', n_sch, 'personas', cnt, 'visitas', nvis,
    'adopciones', (select count(*) from adoptions where org_id = v_org), 'productos', (select count(*) from products where org_id = v_org));
end $$;

revoke all on function private.demo_seed(text) from public, anon, authenticated;

-- Infantil se muestra como 3, 4 y 5 años; el rango de cursos del catálogo sale de los cursos reales de la materia
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
        'ing', (select jsonb_agg(jsonb_build_array(coalesce(role_detail, 'Maestra de Inglés'), full_name, coalesce(email, ''))) from ppl where ppl.school_id = s.id and stage in ('PRI', 'INF') and department = 'Inglés' and role <> 'coordinador'),
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

  insert into datasets(org_id, name, js) values
    (p_org, 'catalogo', v_cat), (p_org, 'centros', v_centros), (p_org, 'contactos', v_contactos), (p_org, 'rutas', v_rutas)
  on conflict (org_id, name) do update set js = excluded.js, updated_at = now();

  return jsonb_build_object('catalogo', length(v_cat), 'centros', length(v_centros), 'contactos', length(v_contactos), 'rutas', length(v_rutas));
end $$;
revoke all on function private.build_datasets(uuid) from public, anon, authenticated;

