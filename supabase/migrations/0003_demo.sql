-- Textia · generador de datos de demostración
-- Todo es inventado: provincia, centros, personas, editoriales y libros.
-- Uso:  select private.demo_seed('demo');   (borra y regenera la editorial 'demo')

create or replace function private.pick(a text[]) returns text
language sql volatile as $$ select a[1 + floor(random() * array_length(a, 1))::int] $$;

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
  subj_pri text[] := array['Lengua','Matemáticas','Ciencias de la Naturaleza','Ciencias Sociales','Inglés','Música','Religión'];
  subj_eso text[] := array['Lengua','Matemáticas','Inglés','Geografía e Historia','Biología y Geología','Física y Química','Francés','Música','Tecnología'];
  subj_bac text[] := array['Lengua','Matemáticas','Inglés','Historia de España','Filosofía','Física y Química','Biología y Geología'];
  series_w text[] := array['Horizonte','Brújula','Raíces','Trazos','Kite','Atlas Vivo','Ágora','Pixel','Nexo','Vuela','Puentes','Mosaico','Zenit','Faro','Senda','Origami','Prisma','Cometa'];
  eng_w text[] := array['Bright Path','Skyline','Open Doors','Step Up','High Five','Way Ahead','Spark','Next Level','Get Going','Wonder Kids','Real Talk','Pathfinders'];
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

  -- Catálogo: un proyecto por editorial, materia y etapa (+ lecturas y diccionarios de la propia)
  for i in 1..array_length(pubs, 1) loop
    foreach subj in array (subj_pri || subj_eso || subj_bac) loop
      for st in select unnest(array['PRI','ESO','BAC']::public.stage[]) loop
        if (st = 'PRI' and subj = any(subj_pri)) or (st = 'ESO' and subj = any(subj_eso)) or (st = 'BAC' and subj = any(subj_bac)) then
          if not exists (select 1 from products where org_id = v_org and publisher_id = pubs[i] and subject = subj and stage = st) then
            insert into products(org_id, publisher_id, title, series, subject, stage, grades, kind, isbn, launch_year)
            values (v_org, pubs[i],
                    case when subj = 'Inglés' then private.pick(eng_w) else subj || ' ' || private.pick(series_w) end,
                    case when subj = 'Inglés' then 'English' else private.pick(series_w) end,
                    subj, st, case st when 'PRI' then '{1,2,3,4,5,6}' when 'ESO' then '{1,2,3,4}' else '{1,2}' end::smallint[], 'texto',
                    '978-0-' || lpad((floor(random() * 99999))::text, 5, '0') || '-' || lpad((floor(random() * 999))::text, 3, '0') || '-' || i,
                    2022 + floor(random() * 4)::int);
          end if;
        end if;
      end loop;
    end loop;
    insert into products(org_id, publisher_id, title, subject, stage, grades, kind, isbn)
      values (v_org, pubs[i], 'Diccionario escolar ' || pub_names[i], 'Inglés', 'ESO', '{1,2,3,4}', 'diccionario', '978-0-D' || i),
             (v_org, pubs[i], 'Lecturas graduadas ' || pub_names[i], 'Inglés', 'PRI', '{3,4,5,6}', 'lectura', '978-0-L' || i);
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
        -- Adopciones
        foreach subj in array (case st when 'PRI' then subj_pri when 'ESO' then subj_eso when 'BAC' then subj_bac else array[]::text[] end) loop
          if st = 'BAC' and g = 2 and subj = 'Filosofía' then continue; end if;
          r := random(); acc := 0; pick_pub := 6;
          for t_idx in 1..6 loop acc := acc + pub_w[t_idx]; if r <= acc then pick_pub := t_idx; exit; end if; end loop;
          if random() < 0.06 and subj not in ('Inglés','Lengua','Matemáticas') then
            insert into adoptions(org_id, school_id, school_year, stage, grade, subject, title_raw, kind, students, source, source_date)
            values (v_org, s_id, v_year, st, g, subj, 'Sin libro de texto', 'otro', null, 'lista web', date '2026-07-10');
            continue;
          end if;
          select id into prod from products where org_id = v_org and publisher_id = pubs[pick_pub] and subject = subj and stage = st and kind = 'texto' limit 1;
          ren := 2027 + floor(random() * 4)::int;
          insert into adoptions(org_id, school_id, school_year, stage, grade, subject, track, product_id, publisher_id, kind, students,
                                adopted_year, renew_year, source, source_date, confidence)
          values (v_org, s_id, v_year, st, g, subj, 'ORD', prod, pubs[pick_pub], 'texto', grp * 22, ren - 4, ren,
                  case when random() < 0.7 then 'lista web' else 'excel' end, date '2026-07-10', 0.9 + random() * 0.1);
          -- Inglés: grupos bilingües y diversificación con otro libro
          if subj = 'Inglés' and st in ('ESO') and random() < 0.35 then
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
    if kind in ('IES') or (kind = 'Colegio' and exists (select 1 from enrollment where school_id = s_id and stage = 'ESO')) then
      foreach dept in array array['Inglés','Lengua','Matemáticas','Geografía e Historia','Biología y Geología','Física y Química','Francés','Música','Tecnología'] loop
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
      foreach dept in array array['Coordinación Infantil','Coordinación 1er ciclo','Coordinación 2º ciclo','Coordinación 3er ciclo','Inglés','Inglés'] loop
        insert into people(org_id, school_id, full_name, role, role_detail, department, stage, email, source, source_date)
        values (v_org, s_id, case when random() < 0.75 then private.pick(first_f) else private.pick(first_m) end || ' ' || private.pick(surn) || ' ' || private.pick(surn),
                case when dept like 'Coord%' then 'coordinador' else 'profesor' end::public.person_role,
                case when dept like 'Coord%' then dept else 'Maestra especialista de Inglés' end,
                case when dept like 'Coordinación Infantil' then 'Infantil' when dept like 'Coord%' then replace(dept, 'Coordinación ', '') else 'Inglés' end,
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
revoke all on function private.pick(text[]) from public, anon;
