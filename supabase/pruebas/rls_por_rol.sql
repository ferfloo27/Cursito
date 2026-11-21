-- Cursito · Prueba de seguridad por rol (§13.7, T-CU32…T-CU39 y otras de Testing.md)
-- Se corre sobre la semilla recién cargada, en el editor SQL de Supabase o con psql.
-- Cada prueba va en su propia transacción y termina en ROLLBACK: no deja datos.
-- Resultado: una línea «PASS T-CUxx …» por prueba; un fallo corta con «FAIL …».
--
-- Usuarios de la semilla:
--   asesora Rocío ...0001 · profesor Carlos (Lenguaje) ...0002 · tesorero Javier ...0011
--   padre Marta (Sofía, pago en revisión) ...0012 · padre Silvia (votó) ...0013 · padre Pedro (sin pagar) ...0018

\set ON_ERROR_STOP on

-- Alumno de prueba: se vincula a Sofía dentro de la transacción (sin pasar por la Edge Function)
create or replace function pg_temp.crear_alumno_de_prueba() returns uuid language plpgsql as $$
declare v uuid := gen_random_uuid(); v_alumno uuid;
begin
  insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data)
  values ('00000000-0000-0000-0000-000000000000', v, 'authenticated', 'authenticated',
          'alumno-prueba-' || v || '@cursito.app', '{"nombre":"Sofía Condori","es_alumno":true}');
  select id into v_alumno from public.alumnos where nombres = 'Sofía';
  perform public.completar_vinculacion(v_alumno, v);
  return v;
end $$;

-- ------------------------------------------------------------ T-CU32 · Alumno: 0 filas en plata, informes y comunicados
begin;
insert into public.comunicados (curso_id, tipo, titulo, cuerpo, autor_id)
values ('22222222-0000-4000-8000-000000000001', 'aviso', 'Prueba', 'Comunicado de prueba', '11111111-0000-4000-8000-000000000001');
insert into public.informes_alumno (alumno_id, periodo, rendimiento, conducta, participacion, puntualidad, tareas, enviado_en, autor_id)
select id, '1.er trimestre', 'bueno', 'bueno', 'bueno', 'bueno', 'bueno', now(), '11111111-0000-4000-8000-000000000001'
from public.alumnos where nombres = 'Sofía';
select set_config('request.jwt.claims', json_build_object('sub', pg_temp.crear_alumno_de_prueba(), 'role', 'authenticated')::text, true);
set local role authenticated;
do $$ begin
  if (select count(*) from public.pagos) + (select count(*) from public.deudas) + (select count(*) from public.cuotas)
     + (select count(*) from public.gastos) + (select count(*) from public.ajustes) + (select count(*) from public.votos)
     + (select count(*) from public.informes_alumno) + (select count(*) from public.comunicados)
     + (select count(*) from public.avisos) <> 0 then
    raise exception 'FAIL T-CU32: el alumno ve finanzas, informes o comunicados';
  end if;
  if (select count(*) from public.actividades) = 0 or (select count(*) from public.horario_bloques) = 0 then
    raise exception 'FAIL T-CU32: el alumno no ve actividades u horario';
  end if;
  raise notice 'PASS T-CU32 alumno: 0 filas en pagos, deudas, cuotas, gastos, ajustes, votos, informes, comunicados y avisos; ve actividades y horario';
end $$;
do $$ begin
  perform public.rendicion('22222222-0000-4000-8000-000000000001');
  raise exception 'FAIL T-CU32: el alumno obtuvo la rendición';
exception when raise_exception then
  if sqlerrm like 'FAIL%' then raise; end if;
  raise notice 'PASS T-CU32 alumno: rendicion() da error (%)', sqlerrm;
end $$;
rollback;

-- ------------------------------------------------------------ T-CU33 · Padre: sólo sus pagos
begin;
select set_config('request.jwt.claims', '{"sub":"11111111-0000-4000-8000-000000000012","role":"authenticated"}', true);
set local role authenticated;
do $$ begin
  if (select count(*) from public.pagos) <> 1 or exists (select 1 from public.pagos where pagado_por <> auth.uid()) then
    raise exception 'FAIL T-CU33: el padre ve pagos ajenos';
  end if;
  if (select count(*) from public.deudas) <> 1 then raise exception 'FAIL T-CU33: el padre ve deudas ajenas'; end if;
  raise notice 'PASS T-CU33 padre: ve sólo su pago y su deuda';
end $$;
rollback;

-- ------------------------------------------------------------ T-CU34 · Padre: quien_debe da error
begin;
select set_config('request.jwt.claims', '{"sub":"11111111-0000-4000-8000-000000000012","role":"authenticated"}', true);
set local role authenticated;
do $$ begin
  perform * from public.quien_debe('22222222-0000-4000-8000-000000000001');
  raise exception 'FAIL T-CU34: el padre obtuvo quien_debe';
exception when raise_exception then
  if sqlerrm like 'FAIL%' then raise; end if;
  raise notice 'PASS T-CU34 padre: quien_debe da error (%)', sqlerrm;
end $$;
rollback;

-- ------------------------------------------------------------ T-CU35 · Padre: update gastos → 0 filas
begin;
select set_config('request.jwt.claims', '{"sub":"11111111-0000-4000-8000-000000000012","role":"authenticated"}', true);
set local role authenticated;
do $$ declare n int; begin
  update public.gastos set monto = 1;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL T-CU35: % filas afectadas', n; end if;
  raise notice 'PASS T-CU35 padre: update gastos set monto = 1 → 0 filas';
end $$;
rollback;

-- ------------------------------------------------------------ T-CU36 · Tesorero: delete pagos → 0 filas
begin;
select set_config('request.jwt.claims', '{"sub":"11111111-0000-4000-8000-000000000011","role":"authenticated"}', true);
set local role authenticated;
do $$ declare n int; begin
  delete from public.pagos;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL T-CU36: % filas borradas', n; end if;
  update public.pagos set monto = 1 where estado = 'confirmado';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL T-CU36: % pagos editados', n; end if;
  raise notice 'PASS T-CU36 tesorero: delete/update sobre pagos → 0 filas';
end $$;
rollback;

-- ------------------------------------------------------------ T-CU37 · Nº ya usado → 23505 «comprobante_usado»
begin;
select set_config('request.jwt.claims', '{"sub":"11111111-0000-4000-8000-000000000018","role":"authenticated"}', true);
set local role authenticated;
do $$ declare v_deuda uuid; begin
  select id into v_deuda from public.deudas limit 1;
  perform public.registrar_pago(v_deuda, 60, '7781 2093 5540',
    '22222222-0000-4000-8000-000000000001/11111111-0000-4000-8000-000000000018/x.jpg');
  raise exception 'FAIL T-CU37: se aceptó un nº duplicado';
exception when unique_violation then
  raise notice 'PASS T-CU37 nº 7781 2093 5540 repetido → % (%)', sqlstate, sqlerrm;
end $$;
rollback;

-- ------------------------------------------------------------ T-CU38 · Votar dos veces → error de clave primaria
begin;
select set_config('request.jwt.claims', '{"sub":"11111111-0000-4000-8000-000000000013","role":"authenticated"}', true);
set local role authenticated;
do $$ begin
  insert into public.votos (gasto_id, a_favor)
  select id, false from public.gastos where concepto = 'Arreglos florales';
  raise exception 'FAIL T-CU38: se aceptó un segundo voto';
exception when unique_violation then
  raise notice 'PASS T-CU38 segundo voto → % (%)', sqlstate, sqlerrm;
end $$;
rollback;

-- ------------------------------------------------------------ T-CU39 · Padre: informe de otro alumno → 0 filas
begin;
insert into public.informes_alumno (alumno_id, periodo, rendimiento, conducta, participacion, puntualidad, tareas, enviado_en, autor_id)
select id, '1.er trimestre', 'bueno', 'regular', 'bueno', 'por_mejorar', 'bueno', now(), '11111111-0000-4000-8000-000000000001'
from public.alumnos where nombres in ('Sofía', 'Mateo');
select set_config('request.jwt.claims', '{"sub":"11111111-0000-4000-8000-000000000012","role":"authenticated"}', true);
set local role authenticated;
do $$ begin
  if (select count(*) from public.informes_alumno) <> 1
     or exists (select 1 from public.informes_alumno i join public.alumnos a on a.id = i.alumno_id where a.nombres <> 'Sofía') then
    raise exception 'FAIL T-CU39: el padre ve informes ajenos';
  end if;
  raise notice 'PASS T-CU39 padre: sólo ve el informe de su hija';
end $$;
rollback;

-- ------------------------------------------------------------ T-CU25 · Rendición con la semilla: 300 / 45 / 255
begin;
select set_config('request.jwt.claims', '{"sub":"11111111-0000-4000-8000-000000000012","role":"authenticated"}', true);
set local role authenticated;
do $$ declare r jsonb; begin
  r := public.rendicion('22222222-0000-4000-8000-000000000001');
  if (r ->> 'recaudado')::numeric <> 300 or (r ->> 'gastado')::numeric <> 45 or (r ->> 'saldo')::numeric <> 255
     or (r ->> 'familias_pagaron')::int <> 5 or (r ->> 'familias')::int <> 8 then
    raise exception 'FAIL T-CU25: %', r;
  end if;
  raise notice 'PASS T-CU25 rendición: %', r;
end $$;
rollback;

-- ------------------------------------------------------------ T-CU57 · Profesor: no ve la rendición
begin;
select set_config('request.jwt.claims', '{"sub":"11111111-0000-4000-8000-000000000002","role":"authenticated"}', true);
set local role authenticated;
do $$ begin
  if (select count(*) from public.gastos) + (select count(*) from public.ajustes) + (select count(*) from public.pagos) <> 0 then
    raise exception 'FAIL T-CU57: el profesor ve gastos, ajustes o pagos';
  end if;
  perform public.rendicion('22222222-0000-4000-8000-000000000001');
  raise exception 'FAIL T-CU57: el profesor obtuvo la rendición';
exception when raise_exception then
  if sqlerrm like 'FAIL%' then raise; end if;
  raise notice 'PASS T-CU57 profesor: 0 gastos/ajustes/pagos y rendicion() da error (%)', sqlerrm;
end $$;
rollback;

-- ------------------------------------------------------------ T-CU54 · Profesor: no crea eventos; sí tareas de su materia
begin;
select set_config('request.jwt.claims', '{"sub":"11111111-0000-4000-8000-000000000002","role":"authenticated"}', true);
set local role authenticated;
do $$ begin
  begin
    insert into public.actividades (curso_id, tipo, titulo, fecha)
    values ('22222222-0000-4000-8000-000000000001', 'evento', 'Kermés', now() + interval '7 days');
    raise exception 'FAIL T-CU54: el profesor creó un evento';
  exception when insufficient_privilege then null;
  end;
  insert into public.actividades (curso_id, tipo, titulo, fecha, materia_id)
  select '22222222-0000-4000-8000-000000000001', 'tarea', 'Leer el cuento', now() + interval '3 days', id
  from public.materias where nombre = 'Lenguaje';
  begin
    insert into public.actividades (curso_id, tipo, titulo, fecha, materia_id)
    select '22222222-0000-4000-8000-000000000001', 'tarea', 'Ejercicios', now() + interval '3 days', id
    from public.materias where nombre = 'Matemática';
    raise exception 'FAIL T-CU54: el profesor publicó una tarea de otra materia';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS T-CU54 profesor: evento rechazado, tarea de Lenguaje aceptada, tarea de Matemática rechazada';
end $$;
rollback;

-- ------------------------------------------------------------ T-CU44 / T-CU47 · Pago parcial y diferencia
begin;
-- Pedro paga Bs 50 de Bs 60
select set_config('request.jwt.claims', '{"sub":"11111111-0000-4000-8000-000000000018","role":"authenticated"}', true);
set local role authenticated;
create temporary table t_pago as
select public.registrar_pago((select id from public.deudas limit 1), 50, '1234-5678',
  '22222222-0000-4000-8000-000000000001/11111111-0000-4000-8000-000000000018/a.jpg') as r;
do $$ begin
  if not ((select r from t_pago) ->> 'monto_distinto')::boolean then raise exception 'FAIL T-CU44: no advirtió monto distinto'; end if;
end $$;
-- Javier confirma
select set_config('request.jwt.claims', '{"sub":"11111111-0000-4000-8000-000000000011","role":"authenticated"}', true);
do $$ declare q record; begin
  perform public.revisar_pago(((select r from t_pago) ->> 'pago_id')::uuid, true);
  select * into q from public.quien_debe('22222222-0000-4000-8000-000000000001') where alumno like 'Pérez%';
  if q.pendiente <> 10 or q.estado <> 'pago_parcial' then raise exception 'FAIL T-CU44: %', q; end if;
  if (public.rendicion('22222222-0000-4000-8000-000000000001') ->> 'familias_pagaron')::int <> 5
     or (public.rendicion('22222222-0000-4000-8000-000000000001') ->> 'recaudado')::numeric <> 350 then
    raise exception 'FAIL T-CU44: la rendición no cuadra';
  end if;
  raise notice 'PASS T-CU44 pago parcial: faltan Bs %, «PAGO PARCIAL», recaudado 350 y 5 de 8 familias', q.pendiente;
end $$;
-- Pedro paga la diferencia y Javier confirma
select set_config('request.jwt.claims', '{"sub":"11111111-0000-4000-8000-000000000018","role":"authenticated"}', true);
create temporary table t_pago2 as
select public.registrar_pago((select id from public.deudas limit 1), 10, '99887766',
  '22222222-0000-4000-8000-000000000001/11111111-0000-4000-8000-000000000018/b.jpg') as r;
select set_config('request.jwt.claims', '{"sub":"11111111-0000-4000-8000-000000000011","role":"authenticated"}', true);
do $$ begin
  perform public.revisar_pago(((select r from t_pago2) ->> 'pago_id')::uuid, true);
  if (public.rendicion('22222222-0000-4000-8000-000000000001') ->> 'familias_pagaron')::int <> 6 then
    raise exception 'FAIL T-CU47: la familia no pasó a contar';
  end if;
  raise notice 'PASS T-CU47 diferencia pagada: 6 de 8 familias';
end $$;
-- Q-CU-PAG-10: ya no puede pagar más
select set_config('request.jwt.claims', '{"sub":"11111111-0000-4000-8000-000000000018","role":"authenticated"}', true);
do $$ begin
  perform public.registrar_pago((select id from public.deudas limit 1), 5, '55555',
    '22222222-0000-4000-8000-000000000001/11111111-0000-4000-8000-000000000018/c.jpg');
  raise exception 'FAIL Q-CU-PAG-10: aceptó un pago sobre deuda saldada';
exception when raise_exception then
  if sqlerrm like 'FAIL%' then raise; end if;
  raise notice 'PASS Q-CU-PAG-10 deuda saldada → %', sqlerrm;
end $$;
rollback;

-- ------------------------------------------------------------ T-CU46 / RN-CU08 · Votación: cierra con todas las familias
begin;
do $$ declare v_gasto uuid; v_estado public.estado_gasto; begin
  select id into v_gasto from public.gastos where concepto = 'Arreglos florales';
  insert into public.votos (gasto_id, usuario_id, a_favor)
  select v_gasto, m.usuario_id, m.usuario_id <> '11111111-0000-4000-8000-000000000018'
  from public.miembros_curso m
  where m.rol = 'padre' and m.usuario_id not in ('11111111-0000-4000-8000-000000000013', '11111111-0000-4000-8000-000000000014');
  select estado into v_estado from public.gastos where id = v_gasto;
  if v_estado <> 'aprobado' then raise exception 'FAIL T-CU46: estado %', v_estado; end if;
  raise notice 'PASS T-CU46 votación: 8 de 8 familias votaron (7 a favor) → aprobado';
end $$;
rollback;

\echo 'Prueba de RLS terminada: todas las pruebas pasaron.'
