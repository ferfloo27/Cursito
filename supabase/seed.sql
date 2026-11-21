-- Cursito · Semilla de la demo (§13.7, Datos de demo y arranque local, Q-CU-RES-02/06, Q-CU-GEN-10/11)
-- Datos sintéticos. Todas las cuentas de demo usan la contraseña: cursito2026
-- Fechas relativas a la carga: el Día de la Madre cae el miércoles siguiente (con 3 días de margen) a las 10:00
-- (hora de Bolivia), así la asistencia sigue abierta y la cuota no sale vencida. Recargar antes del pitch.
-- Los alumnos no tienen cuenta: la vinculación por QR se hace en vivo (Q-CU-GEN-11).
-- Las imágenes de comprobantes, facturas y QR de cobro las sube `supabase/semilla/subir_imagenes.mjs`.

do $$
declare
  c_curso   constant uuid := '22222222-0000-4000-8000-000000000001';
  c_inst    constant uuid := '00000000-0000-0000-0000-000000000000';
  v_clave   text := extensions.crypt('cursito2026', extensions.gen_salt('bf'));
  v_fecha   timestamptz;
  v_act     uuid;
  v_cuota   uuid;
  v_tarjetas uuid;
  v_arreglos uuid;
  v_pago    uuid;
  r         record;
begin
  -- Miércoles siguiente con al menos 3 días de margen, 10:00 en Bolivia
  v_fecha := ((current_date + 3 + ((3 - extract(isodow from current_date + 3)::int + 7) % 7))::timestamp
              + time '10:00') at time zone 'America/La_Paz';

  -- ------------------------------------------------------------ Cuentas (Auth)
  create temporary table semilla_personas (id uuid, nombre text, correo text) on commit drop;
  insert into semilla_personas values
    ('11111111-0000-4000-8000-000000000001', 'Prof. Rocío Mamani',  'rocio.mamani@cursito.test'),
    ('11111111-0000-4000-8000-000000000002', 'Prof. Carlos Quispe', 'carlos.quispe@cursito.test'),
    ('11111111-0000-4000-8000-000000000003', 'Prof. Ana Villca',    'ana.villca@cursito.test'),
    ('11111111-0000-4000-8000-000000000004', 'Prof. Jorge Choque',  'jorge.choque@cursito.test'),
    ('11111111-0000-4000-8000-000000000005', 'Prof. Luis Rojas',    'luis.rojas@cursito.test'),
    ('11111111-0000-4000-8000-000000000006', 'Prof. Elena Flores',  'elena.flores@cursito.test'),
    ('11111111-0000-4000-8000-000000000011', 'Javier Gutiérrez',    'javier.gutierrez@cursito.test'),
    ('11111111-0000-4000-8000-000000000012', 'Marta Condori',       'marta.condori@cursito.test'),
    ('11111111-0000-4000-8000-000000000013', 'Silvia Rojas',        'silvia.rojas@cursito.test'),
    ('11111111-0000-4000-8000-000000000014', 'Óscar Mamani',        'oscar.mamani@cursito.test'),
    ('11111111-0000-4000-8000-000000000015', 'Lucía Torrez',        'lucia.torrez@cursito.test'),
    ('11111111-0000-4000-8000-000000000016', 'Rosa Huanca',         'rosa.huanca@cursito.test'),
    ('11111111-0000-4000-8000-000000000017', 'Ana Vargas',          'ana.vargas@cursito.test'),
    ('11111111-0000-4000-8000-000000000018', 'Pedro Pérez',         'pedro.perez@cursito.test');

  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                          raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                          confirmation_token, recovery_token, email_change_token_new, email_change)
  select c_inst, p.id, 'authenticated', 'authenticated', p.correo, v_clave, now(),
         '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('nombre', p.nombre),
         now(), now(), '', '', '', ''
  from semilla_personas p;

  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  select gen_random_uuid(), p.id, p.id::text,
         jsonb_build_object('sub', p.id::text, 'email', p.correo, 'email_verified', true),
         'email', now(), now(), now()
  from semilla_personas p;
  -- (el trigger crear_perfil ya creó los perfiles)

  -- ------------------------------------------------------------ Curso, materias, miembros
  insert into public.cursos (id, nombre, colegio, nivel, gestion, codigo, codigo_profesor, umbral_votacion, creado_por)
  values (c_curso, '4.º B Primaria', 'U.E. San Andrés', 'primaria', 2026, 'SAN4B7', 'PRF-K2Q9', 100,
          '11111111-0000-4000-8000-000000000001');

  -- 6 materias, una por docente; sin Ciencias Sociales (Q-CU-RES-06)
  insert into public.materias (curso_id, nombre)
  select c_curso, unnest(array['Artes Plásticas', 'Lenguaje', 'Matemática', 'Ciencias Naturales', 'Educación Física', 'Música']);

  insert into public.miembros_curso (curso_id, usuario_id, rol, es_tesorero, es_delegado, unido_en)
  select c_curso, p.id,
         case when p.id = '11111111-0000-4000-8000-000000000001' then 'asesor'::public.rol_miembro
              when p.nombre like 'Prof.%' then 'profesor'::public.rol_miembro
              else 'padre'::public.rol_miembro end,
         p.id = '11111111-0000-4000-8000-000000000011',
         p.id = '11111111-0000-4000-8000-000000000011',
         now() - interval '20 days'
  from semilla_personas p;

  insert into public.profesores_curso (miembro_id, materia_id)
  select m.id, ma.id
  from (values ('11111111-0000-4000-8000-000000000001'::uuid, 'Artes Plásticas'),
               ('11111111-0000-4000-8000-000000000002'::uuid, 'Lenguaje'),
               ('11111111-0000-4000-8000-000000000003'::uuid, 'Matemática'),
               ('11111111-0000-4000-8000-000000000004'::uuid, 'Ciencias Naturales'),
               ('11111111-0000-4000-8000-000000000005'::uuid, 'Educación Física'),
               ('11111111-0000-4000-8000-000000000006'::uuid, 'Música')) as x(usuario, materia)
  join public.miembros_curso m on m.curso_id = c_curso and m.usuario_id = x.usuario
  join public.materias ma on ma.curso_id = c_curso and ma.nombre = x.materia;

  -- ------------------------------------------------------------ Nómina (8 alumnos con su padre)
  insert into public.alumnos (curso_id, nombres, apellidos, padre_id) values
    (c_curso, 'Sofía',     'Condori',   '11111111-0000-4000-8000-000000000012'),
    (c_curso, 'Mateo',     'Gutiérrez', '11111111-0000-4000-8000-000000000011'),
    (c_curso, 'Valentina', 'Rojas',     '11111111-0000-4000-8000-000000000013'),
    (c_curso, 'Diego',     'Mamani',    '11111111-0000-4000-8000-000000000014'),
    (c_curso, 'Camila',    'Torrez',    '11111111-0000-4000-8000-000000000015'),
    (c_curso, 'Santiago',  'Huanca',    '11111111-0000-4000-8000-000000000016'),
    (c_curso, 'Luciana',   'Vargas',    '11111111-0000-4000-8000-000000000017'),
    (c_curso, 'Joaquín',   'Pérez',     '11111111-0000-4000-8000-000000000018');

  -- ------------------------------------------------------------ Horario de la semana (sin avisos)
  alter table public.horario_bloques disable trigger aviso_horario;
  insert into public.horario_bloques (curso_id, dia, hora_inicio, hora_fin, materia_id)
  select c_curso, x.dia, x.ini, x.fin, ma.id
  from (values
    (1, time '08:00', time '09:30', 'Matemática'), (1, '09:45', '11:15', 'Lenguaje'),           (1, '11:30', '12:30', 'Música'),
    (2, '08:00', '09:30', 'Lenguaje'),             (2, '09:45', '11:15', 'Ciencias Naturales'), (2, '11:30', '12:30', 'Educación Física'),
    (3, '08:00', '09:30', 'Matemática'),           (3, '09:45', '11:15', 'Artes Plásticas'),    (3, '11:30', '12:30', 'Ciencias Naturales'),
    (4, '08:00', '09:30', 'Lenguaje'),             (4, '09:45', '11:15', 'Matemática'),         (4, '11:30', '12:30', 'Educación Física'),
    (5, '08:00', '09:30', 'Ciencias Naturales'),   (5, '09:45', '11:15', 'Música'),             (5, '11:30', '12:30', 'Artes Plásticas')
  ) as x(dia, ini, fin, materia)
  join public.materias ma on ma.curso_id = c_curso and ma.nombre = x.materia;
  alter table public.horario_bloques enable trigger aviso_horario;

  -- ------------------------------------------------------------ Evento Día de la Madre con cuota de Bs 60
  insert into public.actividades (curso_id, tipo, titulo, descripcion, fecha, lugar, pide_asistencia, creado_por, creado_en)
  values (c_curso, 'evento', 'Día de la Madre',
          'Acto por el Día de la Madre con las familias del curso.', v_fecha, 'Patio del colegio', true,
          '11111111-0000-4000-8000-000000000001', now() - interval '6 days')
  returning id into v_act;

  -- La cuota la crea el tesorero después del evento (Q-CU-ACT-08); el trigger genera las 8 deudas y el aviso.
  insert into public.cuotas (curso_id, actividad_id, concepto, monto_por_alumno, vence_el, creado_por, creado_en)
  values (c_curso, v_act, 'Día de la Madre', 60, (v_fecha at time zone 'America/La_Paz')::date,
          '11111111-0000-4000-8000-000000000011', now() - interval '5 days')
  returning id into v_cuota;

  -- 5 pagos confirmados, 2 en revisión (Marta y Ana), Joaquín sin pagar
  for r in
    select * from (values
      ('11111111-0000-4000-8000-000000000011'::uuid, '778120935540', 'confirmado'),   -- nº ya usado (T-CU37)
      ('11111111-0000-4000-8000-000000000013'::uuid, '552019384711', 'confirmado'),
      ('11111111-0000-4000-8000-000000000014'::uuid, '903318275566', 'confirmado'),
      ('11111111-0000-4000-8000-000000000015'::uuid, '661204587390', 'confirmado'),
      ('11111111-0000-4000-8000-000000000016'::uuid, '417760293851', 'confirmado'),
      ('11111111-0000-4000-8000-000000000012'::uuid, '820193746602', 'en_revision'),
      ('11111111-0000-4000-8000-000000000017'::uuid, '339581027764', 'en_revision')
    ) as x(padre, nro, estado)
  loop
    insert into public.pagos (curso_id, deuda_id, pagado_por, monto, nro_transaccion, comprobante_path, estado,
                              revisado_por, revisado_en, creado_en)
    select c_curso, d.id, r.padre, 60, r.nro, c_curso || '/' || r.padre || '/semilla.jpg', r.estado::public.estado_pago,
           case when r.estado = 'confirmado' then '11111111-0000-4000-8000-000000000011'::uuid end,
           case when r.estado = 'confirmado' then now() - interval '3 days' end,
           now() - interval '4 days'
    from public.deudas d join public.alumnos a on a.id = d.alumno_id
    where d.cuota_id = v_cuota and a.padre_id = r.padre;
  end loop;

  insert into public.avisos (curso_id, tipo, texto, ref_tabla, ref_id, creado_en)
  values (c_curso, 'pago_confirmado', 'Se confirmó un pago · Día de la Madre: 5 de 8 familias', 'cuotas', v_cuota,
          now() - interval '3 days');

  -- Gasto «Tarjetas y lazos» de Bs 50 (aprobado, bajo el umbral) con ajuste de − Bs 5
  insert into public.gastos (curso_id, actividad_id, concepto, categoria, monto, factura_path, registrado_por, creado_en)
  values (c_curso, v_act, 'Tarjetas y lazos', 'materiales', 50, c_curso || '/tarjetas-y-lazos.jpg',
          '11111111-0000-4000-8000-000000000011', now() - interval '2 days')
  returning id into v_tarjetas;

  insert into public.ajustes (curso_id, gasto_id, monto, motivo, autor_id, creado_en)
  values (c_curso, v_tarjetas, -5, 'Devolución de un lazo que sobró en la librería',
          '11111111-0000-4000-8000-000000000011', now() - interval '1 day');

  -- «Arreglos florales» de Bs 180: en votación (≥ umbral), con 2 votos
  insert into public.gastos (curso_id, actividad_id, concepto, categoria, monto, factura_path, registrado_por, creado_en)
  values (c_curso, v_act, 'Arreglos florales', 'obsequio', 180, c_curso || '/arreglos-florales.jpg',
          '11111111-0000-4000-8000-000000000011', now() - interval '2 hours')
  returning id into v_arreglos;

  insert into public.votos (gasto_id, usuario_id, a_favor) values
    (v_arreglos, '11111111-0000-4000-8000-000000000013', true),
    (v_arreglos, '11111111-0000-4000-8000-000000000014', true);

  -- QR de cobro del tesorero (R-CU42)
  update public.cursos set qr_cobro_path = c_curso || '/semilla.png' where id = c_curso;
end $$;
