-- Cursito · 0003 · RLS (§13.5) con los ajustes de las rondas:
--   · la rendición (gastos, ajustes, facturas) la ven padres y asesor, no profesores (Q-CU-REN-01)
--   · los eventos los crea sólo el asesor; el profesor, tareas de su materia (RN-CU20)
--   · el alumno no tiene ninguna política sobre finanzas, informes, comunicados ni avisos (RN-CU04)
-- Sin política de UPDATE ni DELETE sobre pagos, gastos, ajustes, votos, comentarios, lecturas y avisos:
-- intentarlo afecta 0 filas (T-CU35, T-CU36) y, además, hay triggers que lo impiden (0002).

-- ---------------------------------------------------------------- Privilegios de tabla
revoke all on all tables in schema public from anon;
revoke insert, update, delete, truncate on all tables in schema public from authenticated;
grant select on all tables in schema public to authenticated;

-- Columnas que el cliente puede escribir directamente (el resto, sólo por RPC o triggers)
revoke select on public.perfiles from authenticated;
grant select (id, nombre, es_alumno, creado_en) on public.perfiles to authenticated;   -- el celular no se muestra
grant update (nombre, telefono) on public.perfiles to authenticated;
grant update (umbral_votacion) on public.cursos to authenticated;
grant insert (curso_id, nombres, apellidos), update (nombres, apellidos), delete on public.alumnos to authenticated;
grant insert (curso_id, dia, hora_inicio, hora_fin, materia_id), update (dia, hora_inicio, hora_fin, materia_id), delete
  on public.horario_bloques to authenticated;
grant delete on public.miembros_curso, public.profesores_curso to authenticated;
grant insert (curso_id, tipo, titulo, descripcion, materia_id, fecha, lugar, pide_asistencia, pide_autorizacion),
      update (fecha, lugar, descripcion, cancelada_en) on public.actividades to authenticated;
grant insert (actividad_id, texto) on public.comentarios to authenticated;
grant insert (actividad_id, alumno_id, respuesta), update (respuesta) on public.asistencias to authenticated;
grant insert (actividad_id, alumno_id) on public.autorizaciones to authenticated;
grant insert (curso_id, tipo, titulo, cuerpo, actividad_id, pide_enterado) on public.comunicados to authenticated;
grant insert (comunicado_id) on public.lecturas_comunicado to authenticated;
grant insert (alumno_id, periodo, rendimiento, conducta, participacion, puntualidad, tareas, observaciones, enviado_en),
      update (rendimiento, conducta, participacion, puntualidad, tareas, observaciones, enviado_en)
  on public.informes_alumno to authenticated;
grant insert (curso_id, actividad_id, concepto, monto_por_alumno, vence_el) on public.cuotas to authenticated;
grant insert (curso_id, actividad_id, concepto, categoria, monto, factura_path) on public.gastos to authenticated;
grant insert (gasto_id, a_favor) on public.votos to authenticated;
grant insert (curso_id, pago_id, gasto_id, monto, motivo) on public.ajustes to authenticated;
-- Libro: privilegio sin política = 0 filas afectadas (así lo esperan T-CU35 y T-CU36)
grant update, delete on public.pagos, public.gastos, public.ajustes, public.votos, public.comentarios,
                        public.lecturas_comunicado, public.avisos to authenticated;

-- ---------------------------------------------------------------- RLS en todas las tablas
alter table public.perfiles            enable row level security;
alter table public.cursos              enable row level security;
alter table public.miembros_curso      enable row level security;
alter table public.alumnos             enable row level security;
alter table public.tokens_vinculacion  enable row level security;
alter table public.materias            enable row level security;
alter table public.profesores_curso    enable row level security;
alter table public.horario_bloques     enable row level security;
alter table public.actividades         enable row level security;
alter table public.comentarios         enable row level security;
alter table public.asistencias         enable row level security;
alter table public.autorizaciones      enable row level security;
alter table public.comunicados         enable row level security;
alter table public.lecturas_comunicado enable row level security;
alter table public.informes_alumno     enable row level security;
alter table public.avisos              enable row level security;
alter table public.cuotas              enable row level security;
alter table public.deudas              enable row level security;
alter table public.pagos               enable row level security;
alter table public.gastos              enable row level security;
alter table public.votos               enable row level security;
alter table public.ajustes             enable row level security;

-- ---------------------------------------------------------------- Núcleo
create policy ver_perfiles on public.perfiles for select to authenticated
  using (privado.comparte_curso(id));
create policy editar_mi_perfil on public.perfiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy ver_curso on public.cursos for select to authenticated
  using (privado.es_miembro(id));
create policy editar_umbral on public.cursos for update to authenticated
  using (privado.es_asesor(id) or privado.es_delegado(id))
  with check (privado.es_asesor(id) or privado.es_delegado(id));

create policy ver_miembros on public.miembros_curso for select to authenticated
  using (privado.es_adulto(curso_id) or usuario_id = auth.uid());
create policy quitar_miembro on public.miembros_curso for delete to authenticated
  using (privado.es_asesor(curso_id) and rol <> 'asesor' and usuario_id <> auth.uid());

create policy ver_alumnos on public.alumnos for select to authenticated
  using (privado.es_adulto(curso_id) or usuario_alumno_id = auth.uid());
create policy cargar_nomina on public.alumnos for insert to authenticated
  with check (privado.es_asesor(curso_id) or privado.es_delegado(curso_id));
create policy corregir_nomina on public.alumnos for update to authenticated
  using (privado.es_asesor(curso_id) or privado.es_delegado(curso_id))
  with check (privado.es_asesor(curso_id) or privado.es_delegado(curso_id));
create policy quitar_de_nomina on public.alumnos for delete to authenticated
  using (privado.es_asesor(curso_id) or privado.es_delegado(curso_id));   -- el trigger exige: sin padre, cuenta ni pagos

-- tokens_vinculacion: sin políticas (sólo por RPC y Edge Function)

create policy ver_materias on public.materias for select to authenticated
  using (privado.es_miembro(curso_id));                                    -- lista fija: nadie las crea (Q-CU-CUR-07)

create policy ver_profesores on public.profesores_curso for select to authenticated
  using (privado.es_miembro((select m.curso_id from public.miembros_curso m where m.id = miembro_id)));
create policy quitar_profesor on public.profesores_curso for delete to authenticated
  using (privado.es_asesor((select m.curso_id from public.miembros_curso m where m.id = miembro_id)));

create policy ver_horario on public.horario_bloques for select to authenticated
  using (privado.es_miembro(curso_id));
create policy cargar_horario on public.horario_bloques for insert to authenticated
  with check (privado.es_asesor(curso_id));
create policy cambiar_horario on public.horario_bloques for update to authenticated
  using (privado.es_asesor(curso_id)) with check (privado.es_asesor(curso_id));
create policy quitar_horario on public.horario_bloques for delete to authenticated
  using (privado.es_asesor(curso_id));

-- ---------------------------------------------------------------- Actividades
create policy ver_actividades on public.actividades for select to authenticated
  using (privado.es_miembro(curso_id));
create policy publicar_actividad on public.actividades for insert to authenticated
  with check (
    (tipo = 'evento' and privado.es_asesor(curso_id))                                       -- RN-CU20
    or (tipo = 'tarea' and (
          privado.es_asesor(curso_id)
          or exists (select 1 from public.profesores_curso pc
                     join public.miembros_curso m on m.id = pc.miembro_id
                     where pc.materia_id = actividades.materia_id and m.usuario_id = auth.uid()
                       and m.curso_id = actividades.curso_id and m.rol = 'profesor'))));
create policy editar_mi_actividad on public.actividades for update to authenticated
  using (creado_por = auth.uid() and privado.es_docente(curso_id))
  with check (creado_por = auth.uid());

create policy ver_comentarios on public.comentarios for select to authenticated
  using (privado.es_miembro(privado.curso_de_actividad(actividad_id))
         and (not oculto or privado.es_docente(privado.curso_de_actividad(actividad_id))));  -- RN-CU09
create policy comentar on public.comentarios for insert to authenticated
  with check (autor_id = auth.uid() and privado.es_miembro(privado.curso_de_actividad(actividad_id)));

create policy ver_asistencias on public.asistencias for select to authenticated
  using (privado.es_docente(privado.curso_de_actividad(actividad_id)) or privado.es_padre_de(alumno_id));
create policy responder_asistencia on public.asistencias for insert to authenticated
  with check (privado.es_padre_de(alumno_id));
create policy cambiar_asistencia on public.asistencias for update to authenticated
  using (privado.es_padre_de(alumno_id)) with check (privado.es_padre_de(alumno_id));      -- fecha: trigger (RN-CU15)

create policy ver_autorizaciones on public.autorizaciones for select to authenticated
  using (privado.es_docente(privado.curso_de_actividad(actividad_id)) or privado.es_padre_de(alumno_id));
create policy autorizar on public.autorizaciones for insert to authenticated
  with check (privado.es_padre_de(alumno_id));

-- ---------------------------------------------------------------- Comunicación (el alumno, nada)
create policy ver_comunicados on public.comunicados for select to authenticated
  using (privado.es_adulto(curso_id));
create policy publicar_comunicado on public.comunicados for insert to authenticated
  with check (privado.es_docente(curso_id));

create policy ver_mi_lectura on public.lecturas_comunicado for select to authenticated
  using (usuario_id = auth.uid());
create policy marcar_enterado on public.lecturas_comunicado for insert to authenticated
  with check (usuario_id = auth.uid() and privado.es_adulto(privado.curso_de_comunicado(comunicado_id)));

create policy ver_informe on public.informes_alumno for select to authenticated
  using ((privado.es_padre_de(alumno_id) and enviado_en is not null)                          -- RN-CU11
         or privado.es_docente(privado.curso_de_alumno(alumno_id)));
create policy redactar_informe on public.informes_alumno for insert to authenticated
  with check (privado.es_asesor(privado.curso_de_alumno(alumno_id)));
create policy corregir_informe on public.informes_alumno for update to authenticated
  using (privado.es_asesor(privado.curso_de_alumno(alumno_id)) and leido_en is null)
  with check (privado.es_asesor(privado.curso_de_alumno(alumno_id)));

create policy ver_avisos on public.avisos for select to authenticated
  using (privado.es_adulto(curso_id) and (destinatario_id is null or destinatario_id = auth.uid()));

-- ---------------------------------------------------------------- Finanzas (el alumno, nada)
create policy ver_cuotas on public.cuotas for select to authenticated
  using (privado.es_adulto(curso_id));
create policy crear_cuota on public.cuotas for insert to authenticated
  with check (privado.es_tesorero(curso_id));

create policy ver_deudas on public.deudas for select to authenticated
  using (privado.es_tesorero(privado.curso_de_cuota(cuota_id)) or privado.es_padre_de(alumno_id));

create policy ver_pagos on public.pagos for select to authenticated
  using (pagado_por = auth.uid() or privado.es_tesorero(curso_id));

create policy ver_gastos on public.gastos for select to authenticated
  using (privado.ve_cuentas(curso_id));
create policy registrar_gasto on public.gastos for insert to authenticated
  with check (privado.es_tesorero(curso_id));

create policy ver_mi_voto on public.votos for select to authenticated
  using (usuario_id = auth.uid());
create policy votar on public.votos for insert to authenticated
  with check (usuario_id = auth.uid() and privado.es_padre(privado.curso_de_gasto(gasto_id)));

create policy ver_ajustes on public.ajustes for select to authenticated
  using (privado.ve_cuentas(curso_id));
create policy registrar_ajuste on public.ajustes for insert to authenticated
  with check (privado.es_tesorero(curso_id));
