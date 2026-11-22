SET local check_function_bodies = off;

CREATE OR REPLACE FUNCTION privado.aviso_actividad()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  if new.cancelada_en is not null then
    perform privado.publicar_aviso(new.curso_id, 'actividad_cancelada', 'Se canceló: ' || new.titulo, 'actividades', new.id);
  elsif (new.fecha, new.lugar, new.descripcion) is distinct from (old.fecha, old.lugar, old.descripcion) then
    perform privado.publicar_aviso(new.curso_id, 'actividad_cambiada',
      'Cambió ' || new.titulo || ': ' || concat_ws(', ',
        case when new.fecha is distinct from old.fecha then 'fecha' end,
        case when new.lugar is distinct from old.lugar then 'lugar' end,
        case when new.descripcion is distinct from old.descripcion then 'descripción' end),
      'actividades', new.id);
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.aviso_ajuste()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_sobre text;
begin
  if new.gasto_id is not null then
    select g.concepto into v_sobre from public.gastos g where g.id = new.gasto_id;
  else
    select 'un pago de ' || c.concepto into v_sobre
    from public.pagos p join public.deudas d on d.id = p.deuda_id join public.cuotas c on c.id = d.cuota_id
    where p.id = new.pago_id;
  end if;
  perform privado.publicar_aviso(new.curso_id, 'ajuste',
    coalesce(privado.nombre_de(new.autor_id), 'El tesorero') || ' registró un ajuste de ' ||
    privado.bs(new.monto, true) || ' en ' || v_sobre, 'ajustes', new.id);
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.aviso_gasto()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  if new.estado = 'en_votacion' then
    perform privado.publicar_aviso(new.curso_id, 'votacion_abierta',
      'Votación abierta: ' || new.concepto || ' · ' || privado.bs(new.monto), 'gastos', new.id);
  else
    perform privado.publicar_aviso(new.curso_id, 'gasto_registrado',
      'Gasto registrado: ' || new.concepto || ' · ' || privado.bs(new.monto), 'gastos', new.id);
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.aviso_horario()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_fila record;
begin
  if tg_op = 'DELETE' then v_fila := old; else v_fila := new; end if;
  perform privado.publicar_aviso(v_fila.curso_id, 'horario_cambiado',
    'Cambió el horario del ' || (array['lunes','martes','miércoles','jueves','viernes'])[v_fila.dia],
    'horario_bloques', v_fila.id);
  return v_fila;
end $function$;

CREATE OR REPLACE FUNCTION privado.bs (
  p           numeric,
  p_decimales boolean DEFAULT false
)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  select case when p < 0 then '− ' else '' end || 'Bs ' ||
    case when abs(p) = trunc(abs(p)) and not p_decimales
      then replace(to_char(abs(p), 'FM999,999,990'), ',', '.')
      else translate(to_char(abs(p), 'FM999,999,990.00'), ',.', '.,')
    end
$function$;

CREATE OR REPLACE FUNCTION privado.cerrar_votacion_si_toca (
  p_gasto uuid
)
  RETURNS public.estado_gasto
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_gasto     public.gastos;
  v_favor     int;
  v_contra    int;
  v_familias  int;
  v_estado    public.estado_gasto;
begin
  select * into v_gasto from public.gastos where id = p_gasto for update;
  if v_gasto.estado <> 'en_votacion' then
    return v_gasto.estado;
  end if;
  select count(*) filter (where a_favor), count(*) filter (where not a_favor)
    into v_favor, v_contra from public.votos where gasto_id = p_gasto;
  v_familias := (select count(*) from public.miembros_curso m where m.curso_id = v_gasto.curso_id and m.rol = 'padre');
  if now() < v_gasto.vota_hasta and (v_favor + v_contra) < v_familias then
    return v_gasto.estado;
  end if;
  v_estado := case when v_favor + v_contra >= 3 and v_favor > v_contra then 'aprobado' else 'rechazado' end;
  update public.gastos set estado = v_estado, cerrado_en = now() where id = p_gasto;
  perform privado.publicar_aviso(v_gasto.curso_id, 'votacion_cerrada',
    'Votación cerrada: ' || v_gasto.concepto || ' · ' || privado.bs(v_gasto.monto) || ' · ' ||
    case when v_estado = 'aprobado' then 'aprobado' else 'rechazado' end ||
    ' (' || v_favor || ' a favor, ' || v_contra || ' en contra)', 'gastos', p_gasto);
  return v_estado;
end $function$;

CREATE OR REPLACE FUNCTION privado.cerrar_votaciones_vencidas (
  p_curso uuid DEFAULT NULL::uuid
)
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_id uuid;
  v_n  int := 0;
begin
  for v_id in select id from public.gastos
              where estado = 'en_votacion' and vota_hasta <= now() and (p_curso is null or curso_id = p_curso)
  loop
    perform privado.cerrar_votacion_si_toca(v_id);
    v_n := v_n + 1;
  end loop;
  return v_n;
end $function$;

CREATE OR REPLACE FUNCTION privado.cierre_por_votos()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  perform privado.cerrar_votacion_si_toca(new.gasto_id);
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.codigo_aleatorio (
  p_largo integer
)
  RETURNS text
  LANGUAGE sql
  AS $function$
  select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', (floor(random() * 32) + 1)::int, 1), '')
  from generate_series(1, p_largo)
$function$;

CREATE OR REPLACE FUNCTION privado.comentario_nuevo()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  new.oculto := false;
  new.oculto_por := null;
  new.oculto_en := null;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.comparte_curso (
  p_perfil uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select p_perfil = auth.uid() or exists (
    select 1 from public.miembros_curso yo
    where yo.usuario_id = auth.uid() and (
      exists (select 1 from public.miembros_curso otro
              where otro.curso_id = yo.curso_id and otro.usuario_id = p_perfil)
      or exists (select 1 from public.alumnos al
                 where al.curso_id = yo.curso_id and (al.padre_id = p_perfil or al.usuario_alumno_id = p_perfil))))
$function$;

CREATE OR REPLACE FUNCTION privado.crear_perfil()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  insert into public.perfiles (id, nombre, telefono, es_alumno)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'nombre'), ''), split_part(new.email, '@', 1)),
    nullif(trim(new.raw_user_meta_data ->> 'telefono'), ''),
    coalesce((new.raw_user_meta_data ->> 'es_alumno')::boolean, false)
  );
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.curso_de_actividad (
  p_actividad uuid
)
  RETURNS uuid
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select a.curso_id from public.actividades a where a.id = p_actividad
$function$;

CREATE OR REPLACE FUNCTION privado.curso_de_alumno (
  p_alumno uuid
)
  RETURNS uuid
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select a.curso_id from public.alumnos a where a.id = p_alumno
$function$;

CREATE OR REPLACE FUNCTION privado.curso_de_comunicado (
  p_comunicado uuid
)
  RETURNS uuid
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select c.curso_id from public.comunicados c where c.id = p_comunicado
$function$;

CREATE OR REPLACE FUNCTION privado.curso_de_cuota (
  p_cuota uuid
)
  RETURNS uuid
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select c.curso_id from public.cuotas c where c.id = p_cuota
$function$;

CREATE OR REPLACE FUNCTION privado.curso_de_gasto (
  p_gasto uuid
)
  RETURNS uuid
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select g.curso_id from public.gastos g where g.id = p_gasto
$function$;

CREATE OR REPLACE FUNCTION privado.deudas_alumno_nuevo()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  insert into public.deudas (cuota_id, alumno_id, monto)
  select c.id, new.id, c.monto_por_alumno from public.cuotas c
  where c.curso_id = new.curso_id and c.anulada_en is null;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.es_adulto (
  p_curso uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select coalesce(privado.mi_rol(p_curso) in ('asesor', 'profesor', 'padre'), false)
$function$;

CREATE OR REPLACE FUNCTION privado.es_asesor (
  p_curso uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select coalesce(privado.mi_rol(p_curso) = 'asesor', false)
$function$;

CREATE OR REPLACE FUNCTION privado.es_delegado (
  p_curso uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select exists (select 1 from public.miembros_curso m
                 where m.curso_id = p_curso and m.usuario_id = auth.uid() and m.es_delegado)
$function$;

CREATE OR REPLACE FUNCTION privado.es_docente (
  p_curso uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select coalesce(privado.mi_rol(p_curso) in ('asesor', 'profesor'), false)
$function$;

CREATE OR REPLACE FUNCTION privado.es_miembro (
  p_curso uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select privado.mi_rol(p_curso) is not null
$function$;

CREATE OR REPLACE FUNCTION privado.es_padre (
  p_curso uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select coalesce(privado.mi_rol(p_curso) = 'padre', false)
$function$;

CREATE OR REPLACE FUNCTION privado.es_padre_de (
  p_alumno uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select exists (select 1 from public.alumnos a where a.id = p_alumno and a.padre_id = auth.uid())
$function$;

CREATE OR REPLACE FUNCTION privado.es_tesorero (
  p_curso uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select exists (select 1 from public.miembros_curso m
                 where m.curso_id = p_curso and m.usuario_id = auth.uid() and m.es_tesorero)
$function$;

CREATE OR REPLACE FUNCTION privado.estado_inicial_gasto()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_curso public.cursos;
begin
  select * into v_curso from public.cursos where id = new.curso_id;
  new.cerrado_en := null;
  if new.monto >= v_curso.umbral_votacion then              -- «mayor o igual» (Q-CU-GAS-02)
    new.estado := 'en_votacion';
    new.vota_hasta := now() + make_interval(days => v_curso.dias_votacion);
  else
    new.estado := 'aprobado';
    new.vota_hasta := null;
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.familias_del_curso (
  p_curso uuid
)
  RETURNS integer
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select count(*)::int from public.alumnos a where a.curso_id = p_curso
$function$;

CREATE OR REPLACE FUNCTION privado.fijar_autor()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_cambios jsonb := '{}'::jsonb;
begin
  if auth.uid() is not null then
    v_cambios := jsonb_build_object(tg_argv[0], auth.uid());
    if tg_nargs > 1 then
      v_cambios := v_cambios || jsonb_build_object(tg_argv[1], now());
    end if;
    new := jsonb_populate_record(new, v_cambios);
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.generar_deudas()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  insert into public.deudas (cuota_id, alumno_id, monto)
  select new.id, a.id, new.monto_por_alumno from public.alumnos a where a.curso_id = new.curso_id;

  perform privado.publicar_aviso(new.curso_id, 'cuota_nueva',
    'Nueva cuota: ' || new.concepto || ' · ' || privado.bs(new.monto_por_alumno) || ' por alumno · vence el '
      || to_char(new.vence_el, 'DD/MM/YYYY'),
    'cuotas', new.id);
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.mi_rol (
  p_curso uuid
)
  RETURNS public.rol_miembro
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select m.rol from public.miembros_curso m
  where m.curso_id = p_curso and m.usuario_id = auth.uid()
$function$;

CREATE OR REPLACE FUNCTION privado.nombre_de (
  p_perfil uuid
)
  RETURNS text
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select p.nombre from public.perfiles p where p.id = p_perfil
$function$;

CREATE OR REPLACE FUNCTION privado.pagado_de_deuda (
  p_deuda uuid
)
  RETURNS numeric
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select coalesce((select sum(p.monto) from public.pagos p
                   where p.deuda_id = p_deuda and p.estado = 'confirmado'), 0)
       + coalesce((select sum(aj.monto) from public.ajustes aj
                   join public.pagos p on p.id = aj.pago_id
                   where p.deuda_id = p_deuda and p.estado = 'confirmado'), 0)
$function$;

CREATE OR REPLACE FUNCTION privado.prohibir_borrado()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  raise exception 'libro_inalterable';
end $function$;

CREATE OR REPLACE FUNCTION privado.prohibir_edicion()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  raise exception 'libro_inalterable';
end $function$;

CREATE OR REPLACE FUNCTION privado.proteger_comentario()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if old.oculto or not new.oculto
     or (new.actividad_id, new.autor_id, new.texto, new.creado_en)
        is distinct from (old.actividad_id, old.autor_id, old.texto, old.creado_en)
  then
    raise exception 'libro_inalterable';
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.proteger_cuota()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if old.anulada_en is not null or new.anulada_en is null
     or (new.curso_id, new.actividad_id, new.concepto, new.monto_por_alumno, new.vence_el, new.creado_por, new.creado_en)
        is distinct from
        (old.curso_id, old.actividad_id, old.concepto, old.monto_por_alumno, old.vence_el, old.creado_por, old.creado_en)
  then
    raise exception 'cuota_inalterable';
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.proteger_gasto()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if old.estado <> 'en_votacion'
     or new.estado = 'en_votacion'
     or (new.curso_id, new.actividad_id, new.concepto, new.categoria, new.monto, new.factura_path,
         new.vota_hasta, new.registrado_por, new.creado_en)
        is distinct from
        (old.curso_id, old.actividad_id, old.concepto, old.categoria, old.monto, old.factura_path,
         old.vota_hasta, old.registrado_por, old.creado_en)
  then
    raise exception 'libro_inalterable';
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.proteger_pago()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if old.estado <> 'en_revision'
     or new.estado = 'en_revision'
     or (new.curso_id, new.deuda_id, new.pagado_por, new.monto, new.nro_transaccion, new.comprobante_path, new.creado_en)
        is distinct from
        (old.curso_id, old.deuda_id, old.pagado_por, old.monto, old.nro_transaccion, old.comprobante_path, old.creado_en)
  then
    raise exception 'libro_inalterable';
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.publicar_aviso (
  p_curso        uuid,
  p_tipo         public.tipo_aviso,
  p_texto        text,
  p_ref_tabla    text              DEFAULT NULL::text,
  p_ref_id       uuid              DEFAULT NULL::uuid,
  p_destinatario uuid              DEFAULT NULL::uuid
)
  RETURNS void
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  insert into public.avisos (curso_id, tipo, texto, ref_tabla, ref_id, destinatario_id)
  values (p_curso, p_tipo, p_texto, p_ref_tabla, p_ref_id, p_destinatario)
$function$;

CREATE OR REPLACE FUNCTION privado.saldo_de_deuda (
  p_deuda uuid
)
  RETURNS numeric
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select greatest(d.monto - privado.pagado_de_deuda(d.id), 0) from public.deudas d where d.id = p_deuda
$function$;

CREATE OR REPLACE FUNCTION privado.uuid_o_nulo (
  p text
)
  RETURNS uuid
  LANGUAGE plpgsql
  IMMUTABLE
  AS $function$
begin
  return p::uuid;
exception when others then
  return null;
end $function$;

CREATE OR REPLACE FUNCTION privado.validar_actividad()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  if tg_op = 'UPDATE' then
    -- El autor sólo cambia fecha, lugar y descripción, o cancela (R-CU47).
    if (new.curso_id, new.tipo, new.titulo, new.materia_id, new.pide_asistencia, new.pide_autorizacion, new.creado_por, new.creado_en)
       is distinct from
       (old.curso_id, old.tipo, old.titulo, old.materia_id, old.pide_asistencia, old.pide_autorizacion, old.creado_por, old.creado_en)
       or old.cancelada_en is not null
    then
      raise exception 'actividad_no_editable';
    end if;
    new.actualizado_en := now();
    if new.cancelada_en is not null then
      new.cancelada_en := now();
    end if;
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.validar_ajuste()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  if new.pago_id is not null and not exists (
       select 1 from public.pagos p where p.id = new.pago_id and p.curso_id = new.curso_id and p.estado = 'confirmado') then
    raise exception 'ajuste_sin_movimiento';   -- sólo lo que está en el libro
  end if;
  if new.gasto_id is not null and not exists (
       select 1 from public.gastos g where g.id = new.gasto_id and g.curso_id = new.curso_id and g.estado = 'aprobado') then
    raise exception 'ajuste_sin_movimiento';
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.validar_asistencia()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_act public.actividades;
begin
  select * into v_act from public.actividades where id = new.actividad_id;
  if not v_act.pide_asistencia or v_act.cancelada_en is not null then
    raise exception 'asistencia_no_aplica';
  end if;
  if now() >= v_act.fecha then
    raise exception 'asistencia_cerrada';
  end if;
  if privado.curso_de_alumno(new.alumno_id) <> v_act.curso_id then
    raise exception 'alumno_de_otro_curso';
  end if;
  if tg_op = 'UPDATE' and (new.actividad_id, new.alumno_id) is distinct from (old.actividad_id, old.alumno_id) then
    raise exception 'asistencia_no_editable';
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.validar_autorizacion()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_act public.actividades;
begin
  select * into v_act from public.actividades where id = new.actividad_id;
  if not v_act.pide_autorizacion or v_act.cancelada_en is not null then
    raise exception 'autorizacion_no_aplica';
  end if;
  if privado.curso_de_alumno(new.alumno_id) <> v_act.curso_id then
    raise exception 'alumno_de_otro_curso';
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.validar_informe()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  if tg_op = 'UPDATE' then
    if old.leido_en is not null then
      raise exception 'informe_ya_leido';   -- Q-CU-INF-03
    end if;
    if (new.alumno_id, new.periodo, new.autor_id, new.creado_en) is distinct from (old.alumno_id, old.periodo, old.autor_id, old.creado_en)
       or (new.leido_en is not null and auth.uid() is not null and not privado.es_padre_de(new.alumno_id)) then
      raise exception 'informe_no_editable';
    end if;
    new.actualizado_en := now();
  end if;
  if new.enviado_en is not null and (tg_op = 'INSERT' or old.enviado_en is null) then
    new.enviado_en := now();
  end if;
  if tg_op = 'INSERT' and auth.uid() is not null then
    new.leido_en := null;
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.validar_quitar_alumno()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  if old.padre_id is not null or old.usuario_alumno_id is not null
     or exists (select 1 from public.pagos p join public.deudas d on d.id = p.deuda_id where d.alumno_id = old.id)
  then
    raise exception 'alumno_no_se_puede_quitar';
  end if;
  return old;
end $function$;

CREATE OR REPLACE FUNCTION privado.validar_voto()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_gasto public.gastos;
begin
  select * into v_gasto from public.gastos where id = new.gasto_id;
  if v_gasto.estado <> 'en_votacion' or now() >= v_gasto.vota_hasta then
    raise exception 'votacion_cerrada';
  end if;
  if not exists (select 1 from public.miembros_curso m
                 where m.curso_id = v_gasto.curso_id and m.usuario_id = new.usuario_id and m.rol = 'padre') then
    raise exception 'solo_padres_votan';      -- RN-CU08 (Q-CU-GAS-08 pendiente)
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION privado.ve_cuentas (
  p_curso uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select coalesce(privado.mi_rol(p_curso) in ('asesor', 'padre'), false)
$function$;

CREATE OR REPLACE FUNCTION public.actualizar_votaciones (
  p_curso uuid
)
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  if not privado.es_adulto(p_curso) then raise exception 'sin_permiso'; end if;
  return privado.cerrar_votaciones_vencidas(p_curso);
end $function$;

CREATE OR REPLACE FUNCTION public.anular_cuota (
  p_cuota  uuid,
  p_motivo text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_cuota public.cuotas;
begin
  select * into v_cuota from public.cuotas where id = p_cuota for update;
  if not found or not privado.es_tesorero(v_cuota.curso_id) then raise exception 'sin_permiso'; end if;
  if v_cuota.anulada_en is not null then raise exception 'cuota_anulada'; end if;
  if length(trim(coalesce(p_motivo, ''))) = 0 then raise exception 'motivo_obligatorio'; end if;
  if exists (select 1 from public.pagos p join public.deudas d on d.id = p.deuda_id
             where d.cuota_id = p_cuota and p.estado <> 'rechazado') then
    raise exception 'cuota_con_pagos';                                         -- Q-CU-PAG-08
  end if;
  update public.cuotas set anulada_en = now(), anulada_por = auth.uid(), motivo_anulacion = trim(p_motivo)
  where id = p_cuota;
  perform privado.publicar_aviso(v_cuota.curso_id, 'cuota_anulada',
    'Se anuló la cuota ' || v_cuota.concepto || ': ' || trim(p_motivo), 'cuotas', p_cuota);
end $function$;

CREATE OR REPLACE FUNCTION public.asignar_asesor (
  p_miembro uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_m public.miembros_curso;
begin
  select * into v_m from public.miembros_curso where id = p_miembro;
  if not found or not privado.es_delegado(v_m.curso_id) then raise exception 'sin_permiso'; end if;
  if v_m.rol <> 'profesor' then raise exception 'debe_ser_profesor'; end if;
  if exists (select 1 from public.miembros_curso where curso_id = v_m.curso_id and rol = 'asesor') then
    raise exception 'curso_ya_tiene_asesor';
  end if;
  if exists (select 1 from public.miembros_curso where usuario_id = v_m.usuario_id and rol = 'asesor') then
    raise exception 'ya_es_asesor';
  end if;
  update public.miembros_curso set rol = 'asesor' where id = p_miembro;
end $function$;

CREATE OR REPLACE FUNCTION public.cerrar_votacion (
  p_gasto uuid
)
  RETURNS public.estado_gasto
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  if not privado.es_tesorero(privado.curso_de_gasto(p_gasto)) then raise exception 'sin_permiso'; end if;
  return privado.cerrar_votacion_si_toca(p_gasto);
end $function$;

CREATE OR REPLACE FUNCTION public.completar_vinculacion (
  p_alumno  uuid,
  p_usuario uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_curso uuid := privado.curso_de_alumno(p_alumno);
begin
  update public.alumnos set usuario_alumno_id = p_usuario where id = p_alumno;
  insert into public.miembros_curso (curso_id, usuario_id, rol) values (v_curso, p_usuario, 'alumno')
  on conflict (curso_id, usuario_id) do nothing;
end $function$;

CREATE OR REPLACE FUNCTION public.conteo_asistencia (
  p_actividad uuid
)
  RETURNS TABLE (
    asisten    integer,
    no_asisten integer
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  if not privado.es_adulto(privado.curso_de_actividad(p_actividad)) then raise exception 'sin_permiso'; end if;
  return query select (count(*) filter (where respuesta = 'asiste'))::int,
                      (count(*) filter (where respuesta = 'no_asiste'))::int
               from public.asistencias where actividad_id = p_actividad;
end $function$;

CREATE OR REPLACE FUNCTION public.crear_curso (
  p_nombre  text,
  p_colegio text,
  p_nivel   public.nivel_curso,
  p_gestion integer,
  p_rol     text,
  p_umbral  numeric            DEFAULT 100
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_curso public.cursos;
  v_intento int := 0;
begin
  if auth.uid() is null then raise exception 'sin_sesion'; end if;
  if p_rol not in ('asesor', 'delegado') then raise exception 'rol_invalido'; end if;   -- RN-CU01
  if p_rol = 'asesor' and exists (select 1 from public.miembros_curso where usuario_id = auth.uid() and rol = 'asesor') then
    raise exception 'ya_es_asesor';                                                     -- RN-CU18
  end if;
  loop
    begin
      insert into public.cursos (nombre, colegio, nivel, gestion, codigo, codigo_profesor, umbral_votacion)
      values (trim(p_nombre), trim(p_colegio), p_nivel, p_gestion,
              privado.codigo_aleatorio(6), 'PRF-' || privado.codigo_aleatorio(4), coalesce(p_umbral, 100))
      returning * into v_curso;
      exit;
    exception when unique_violation then
      v_intento := v_intento + 1;
      if v_intento > 5 then raise; end if;
    end;
  end loop;

  insert into public.miembros_curso (curso_id, usuario_id, rol, es_tesorero, es_delegado)
  values (v_curso.id, auth.uid(),
          case when p_rol = 'asesor' then 'asesor'::public.rol_miembro else 'padre'::public.rol_miembro end,
          p_rol = 'delegado', p_rol = 'delegado');                                        -- RN-CU01: el delegado, tesorero

  -- Lista fija de materias (Q-CU-CUR-07)
  insert into public.materias (curso_id, nombre)
  select v_curso.id, unnest(array['Artes Plásticas', 'Lenguaje', 'Matemática', 'Ciencias Naturales',
                                  'Ciencias Sociales', 'Educación Física', 'Música']);

  return jsonb_build_object('id', v_curso.id, 'codigo', v_curso.codigo, 'codigo_profesor', v_curso.codigo_profesor);
end $function$;

CREATE OR REPLACE FUNCTION public.designar_tesorero (
  p_miembro uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_m public.miembros_curso;
begin
  select * into v_m from public.miembros_curso where id = p_miembro;
  if not found or not (privado.es_asesor(v_m.curso_id) or privado.es_delegado(v_m.curso_id)) then
    raise exception 'sin_permiso';
  end if;
  if v_m.rol not in ('asesor', 'padre') then raise exception 'rol_no_puede_ser_tesorero'; end if;
  if v_m.es_tesorero then return; end if;
  update public.miembros_curso set es_tesorero = false where curso_id = v_m.curso_id and es_tesorero;
  update public.miembros_curso set es_tesorero = true where id = p_miembro;
  update public.cursos set qr_cobro_path = null where id = v_m.curso_id;
end $function$;

CREATE OR REPLACE FUNCTION public.desvincular_padre (
  p_alumno uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_curso uuid := privado.curso_de_alumno(p_alumno);
begin
  if v_curso is null or not (privado.es_asesor(v_curso) or privado.es_delegado(v_curso)) then
    raise exception 'sin_permiso';
  end if;
  update public.alumnos set padre_id = null where id = p_alumno;
end $function$;

CREATE OR REPLACE FUNCTION public.directorio_profesores (
  p_curso uuid
)
  RETURNS TABLE (
    usuario_id uuid,
    nombre     text,
    rol        public.rol_miembro,
    materia    text,
    correo     text
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  if not privado.es_adulto(p_curso) then raise exception 'sin_permiso'; end if;
  return query
    select m.usuario_id, p.nombre, m.rol, ma.nombre, u.email::text
    from public.miembros_curso m
    join public.perfiles p on p.id = m.usuario_id
    join auth.users u on u.id = m.usuario_id
    left join public.profesores_curso pc on pc.miembro_id = m.id
    left join public.materias ma on ma.id = pc.materia_id
    where m.curso_id = p_curso and m.rol in ('asesor', 'profesor')
    order by (m.rol = 'asesor') desc, p.nombre;
end $function$;

CREATE OR REPLACE FUNCTION public.fijar_qr_cobro (
  p_curso uuid,
  p_path  text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  if not privado.es_tesorero(p_curso) then raise exception 'sin_permiso'; end if;
  if p_path is null or split_part(p_path, '/', 1) <> p_curso::text then raise exception 'ruta_invalida'; end if;
  update public.cursos set qr_cobro_path = p_path where id = p_curso;
end $function$;

CREATE OR REPLACE FUNCTION public.generar_token_vinculacion (
  p_alumno uuid
)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_token text := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
begin
  if not privado.es_padre_de(p_alumno) then raise exception 'sin_permiso'; end if;
  update public.tokens_vinculacion set invalidado_en = now()
  where alumno_id = p_alumno and usado_en is null and invalidado_en is null;         -- RN-CU12
  insert into public.tokens_vinculacion (alumno_id, token_hash, creado_por, expira_en)
  values (p_alumno, encode(sha256(convert_to(v_token, 'UTF8')), 'hex'), auth.uid(), now() + interval '10 minutes');
  return v_token;
end $function$;

CREATE OR REPLACE FUNCTION public.lectores (
  p_comunicado uuid
)
  RETURNS TABLE (
    alumno   text,
    padre_id uuid,
    padre    text,
    leido_en timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_com public.comunicados;
begin
  select * into v_com from public.comunicados where id = p_comunicado;
  if not found or not (v_com.autor_id = auth.uid() or privado.es_asesor(v_com.curso_id)) then
    raise exception 'sin_permiso';                                        -- RN-CU10
  end if;
  return query
    select a.nombres || ' ' || a.apellidos, a.padre_id, p.nombre, l.leido_en
    from public.alumnos a
    left join public.perfiles p on p.id = a.padre_id
    left join public.lecturas_comunicado l on l.comunicado_id = p_comunicado and l.usuario_id = a.padre_id
    where a.curso_id = v_com.curso_id
    order by l.leido_en nulls first, a.apellidos;
end $function$;

CREATE OR REPLACE FUNCTION public.marcar_informe_leido (
  p_informe uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_inf public.informes_alumno;
begin
  select * into v_inf from public.informes_alumno where id = p_informe;
  if not found or not privado.es_padre_de(v_inf.alumno_id) or v_inf.enviado_en is null then
    raise exception 'sin_permiso';
  end if;
  if v_inf.leido_en is null then
    update public.informes_alumno set leido_en = now() where id = p_informe;
  end if;
end $function$;

CREATE OR REPLACE FUNCTION public.materias_por_codigo_profesor (
  p_codigo text
)
  RETURNS TABLE (
    curso_id   uuid,
    curso      text,
    colegio    text,
    materia_id uuid,
    materia    text,
    ocupada    boolean
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_curso public.cursos;
begin
  if auth.uid() is null then raise exception 'sin_sesion'; end if;
  select * into v_curso from public.cursos c where c.codigo_profesor = upper(trim(p_codigo));
  if not found then raise exception 'codigo_invalido'; end if;
  return query
    select v_curso.id, v_curso.nombre, v_curso.colegio, ma.id, ma.nombre,
           exists (select 1 from public.profesores_curso pc where pc.materia_id = ma.id)
    from public.materias ma where ma.curso_id = v_curso.id
    order by ma.nombre;
end $function$;

CREATE OR REPLACE FUNCTION public.mis_cuotas (
  p_curso uuid
)
  RETURNS TABLE (
    deuda_id         uuid,
    cuota_id         uuid,
    actividad_id     uuid,
    concepto         text,
    monto            numeric,
    pagado           numeric,
    pendiente        numeric,
    en_revision      numeric,
    vence_el         date,
    anulada          boolean,
    motivo_anulacion text,
    ultimo_rechazo   text
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select d.id, c.id, c.actividad_id, c.concepto, d.monto,
         privado.pagado_de_deuda(d.id),
         privado.saldo_de_deuda(d.id),
         coalesce((select sum(p.monto) from public.pagos p where p.deuda_id = d.id and p.estado = 'en_revision'), 0),
         c.vence_el, c.anulada_en is not null, c.motivo_anulacion,
         (select case when p.estado = 'rechazado' then p.motivo_rechazo end
          from public.pagos p where p.deuda_id = d.id order by p.creado_en desc limit 1)
  from public.deudas d
  join public.cuotas c on c.id = d.cuota_id
  join public.alumnos a on a.id = d.alumno_id
  where c.curso_id = p_curso and a.padre_id = auth.uid()
  order by c.anulada_en is not null, c.vence_el
$function$;

CREATE OR REPLACE FUNCTION public.mis_cursos()
  RETURNS TABLE (
    curso_id    uuid,
    nombre      text,
    colegio     text,
    gestion     integer,
    rol         public.rol_miembro,
    es_tesorero boolean,
    es_delegado boolean,
    hijo_id     uuid,
    hijo        text
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
  select c.id, c.nombre, c.colegio, c.gestion, m.rol, m.es_tesorero, m.es_delegado,
         a.id, a.nombres || ' ' || a.apellidos
  from public.miembros_curso m
  join public.cursos c on c.id = m.curso_id
  left join public.alumnos a on a.curso_id = c.id and a.padre_id = m.usuario_id
  where m.usuario_id = auth.uid()
  order by c.gestion desc, c.nombre
$function$;

CREATE OR REPLACE FUNCTION public.nomina_por_codigo (
  p_codigo text
)
  RETURNS TABLE (
    curso_id  uuid,
    curso     text,
    colegio   text,
    alumno_id uuid,
    alumno    text
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_curso public.cursos;
begin
  if auth.uid() is null then raise exception 'sin_sesion'; end if;
  select * into v_curso from public.cursos c where c.codigo = upper(trim(p_codigo));
  if not found then raise exception 'codigo_invalido'; end if;
  return query
    select v_curso.id, v_curso.nombre, v_curso.colegio, a.id, a.apellidos || ' ' || a.nombres
    from public.alumnos a
    where a.curso_id = v_curso.id and a.padre_id is null
    order by a.apellidos, a.nombres;
end $function$;

CREATE OR REPLACE FUNCTION public.ocultar_comentario (
  p_comentario uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_act public.actividades;
begin
  select a.* into v_act from public.comentarios c join public.actividades a on a.id = c.actividad_id
  where c.id = p_comentario;
  if not found then raise exception 'no_encontrado'; end if;
  -- El asesor, o el profesor de esa actividad (su autor o el de su materia) (Q-CU-ACT-01)
  if not (privado.es_asesor(v_act.curso_id)
          or (privado.mi_rol(v_act.curso_id) = 'profesor' and (
                v_act.creado_por = auth.uid()
                or exists (select 1 from public.profesores_curso pc join public.miembros_curso m on m.id = pc.miembro_id
                           where pc.materia_id = v_act.materia_id and m.usuario_id = auth.uid())))) then
    raise exception 'sin_permiso';
  end if;
  update public.comentarios set oculto = true, oculto_por = auth.uid(), oculto_en = now()
  where id = p_comentario and not oculto;
end $function$;

CREATE OR REPLACE FUNCTION public.quien_debe (
  p_curso uuid
)
  RETURNS TABLE (
    alumno_id   uuid,
    alumno      text,
    padre       text,
    cuota_id    uuid,
    concepto    text,
    monto       numeric,
    pagado      numeric,
    pendiente   numeric,
    en_revision numeric,
    estado      text,
    vencida     boolean
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
begin
  if not privado.es_tesorero(p_curso) then raise exception 'sin_permiso'; end if;
  return query
    select a.id, a.apellidos || ' ' || a.nombres, p.nombre, c.id, c.concepto, d.monto,
           privado.pagado_de_deuda(d.id), privado.saldo_de_deuda(d.id),
           coalesce((select sum(pg.monto) from public.pagos pg where pg.deuda_id = d.id and pg.estado = 'en_revision'), 0),
           case when privado.pagado_de_deuda(d.id) > 0 then 'pago_parcial' else 'pendiente' end,
           c.vence_el < current_date                                       -- la app usa la hora del teléfono (Q-CU-GEN-04)
    from public.deudas d
    join public.cuotas c on c.id = d.cuota_id
    join public.alumnos a on a.id = d.alumno_id
    left join public.perfiles p on p.id = a.padre_id
    where c.curso_id = p_curso and c.anulada_en is null and privado.saldo_de_deuda(d.id) > 0
    order by c.vence_el, a.apellidos;
end $function$;

CREATE OR REPLACE FUNCTION public.reclamar_token_vinculacion (
  p_token text
)
  RETURNS TABLE (
    alumno_id         uuid,
    curso_id          uuid,
    nombre            text,
    usuario_alumno_id uuid
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_alumno uuid;
begin
  update public.tokens_vinculacion t set usado_en = now()
  where t.token_hash = encode(sha256(convert_to(p_token, 'UTF8')), 'hex')
    and t.usado_en is null and t.invalidado_en is null and t.expira_en > now()
  returning t.alumno_id into v_alumno;
  if v_alumno is null then raise exception 'qr_invalido'; end if;
  return query select a.id, a.curso_id, a.nombres || ' ' || a.apellidos, a.usuario_alumno_id
               from public.alumnos a where a.id = v_alumno;
end $function$;

CREATE OR REPLACE FUNCTION public.recordar_comunicado (
  p_comunicado uuid
)
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_com public.comunicados;
  v_n int;
begin
  select * into v_com from public.comunicados where id = p_comunicado;
  if not found or not (v_com.autor_id = auth.uid() or privado.es_asesor(v_com.curso_id)) then
    raise exception 'sin_permiso';
  end if;
  insert into public.avisos (curso_id, tipo, texto, ref_tabla, ref_id, destinatario_id)
  select v_com.curso_id, 'recordatorio_comunicado', 'Recordatorio: lee «' || v_com.titulo || '»', 'comunicados', v_com.id, a.padre_id
  from public.alumnos a
  where a.curso_id = v_com.curso_id and a.padre_id is not null
    and not exists (select 1 from public.lecturas_comunicado l where l.comunicado_id = v_com.id and l.usuario_id = a.padre_id);
  get diagnostics v_n = row_count;
  return v_n;
end $function$;

CREATE OR REPLACE FUNCTION public.recordar_cuota (
  p_cuota uuid
)
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_cuota public.cuotas;
  v_n int;
begin
  select * into v_cuota from public.cuotas where id = p_cuota;
  if not found or not privado.es_tesorero(v_cuota.curso_id) then raise exception 'sin_permiso'; end if;
  insert into public.avisos (curso_id, tipo, texto, ref_tabla, ref_id, destinatario_id)
  select v_cuota.curso_id, 'recordatorio_cuota',
         'Recordatorio: falta pagar ' || v_cuota.concepto || ' · ' || privado.bs(privado.saldo_de_deuda(d.id)),
         'cuotas', v_cuota.id, a.padre_id
  from public.deudas d join public.alumnos a on a.id = d.alumno_id
  where d.cuota_id = p_cuota and a.padre_id is not null and privado.saldo_de_deuda(d.id) > 0;
  get diagnostics v_n = row_count;
  return v_n;
end $function$;

CREATE OR REPLACE FUNCTION public.regenerar_codigo (
  p_curso uuid,
  p_para  text
)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_nuevo text;
begin
  if not privado.es_asesor(p_curso) then raise exception 'sin_permiso'; end if;
  if p_para = 'padres' then
    v_nuevo := privado.codigo_aleatorio(6);
    update public.cursos set codigo = v_nuevo where id = p_curso;
  elsif p_para = 'profesores' then
    v_nuevo := 'PRF-' || privado.codigo_aleatorio(4);
    update public.cursos set codigo_profesor = v_nuevo where id = p_curso;
  else
    raise exception 'parametro_invalido';
  end if;
  return v_nuevo;
end $function$;

CREATE OR REPLACE FUNCTION public.registrar_pago (
  p_deuda            uuid,
  p_monto            numeric,
  p_nro              text,
  p_comprobante_path text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_deuda  public.deudas;
  v_cuota  public.cuotas;
  v_alumno public.alumnos;
  v_nro    text := regexp_replace(coalesce(p_nro, ''), '[\s-]', '', 'g');
  v_saldo  numeric;
  v_id     uuid;
begin
  select * into v_deuda from public.deudas where id = p_deuda;
  if not found then raise exception 'deuda_invalida'; end if;
  select * into v_alumno from public.alumnos where id = v_deuda.alumno_id;
  if v_alumno.padre_id is distinct from auth.uid() then raise exception 'sin_permiso'; end if;
  select * into v_cuota from public.cuotas where id = v_deuda.cuota_id;
  if v_cuota.anulada_en is not null then raise exception 'cuota_anulada'; end if;
  if p_monto is null or p_monto <= 0 then raise exception 'monto_invalido'; end if;
  if v_nro = '' then raise exception 'nro_invalido'; end if;
  if p_comprobante_path is null or p_comprobante_path not like v_cuota.curso_id || '/' || auth.uid() || '/%' then
    raise exception 'comprobante_invalido';
  end if;
  v_saldo := privado.saldo_de_deuda(p_deuda);
  if v_saldo <= 0 then raise exception 'deuda_saldada'; end if;              -- Q-CU-PAG-10
  begin
    insert into public.pagos (curso_id, deuda_id, pagado_por, monto, nro_transaccion, comprobante_path)
    values (v_cuota.curso_id, p_deuda, auth.uid(), p_monto, v_nro, p_comprobante_path)
    returning id into v_id;
  exception when unique_violation then
    raise exception 'comprobante_usado' using errcode = '23505';            -- RN-CU06
  end;
  return jsonb_build_object('ok', true, 'pago_id', v_id, 'monto_distinto', p_monto <> v_saldo, 'saldo', v_saldo);
end $function$;

CREATE OR REPLACE FUNCTION public.rendicion (
  p_curso     uuid,
  p_actividad uuid DEFAULT NULL::uuid
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_recaudado numeric;
  v_gastado   numeric;
  v_votacion  numeric;
  v_pagaron   int;
  v_familias  int;
begin
  if not privado.ve_cuentas(p_curso) then raise exception 'sin_permiso'; end if;
  perform privado.cerrar_votaciones_vencidas(p_curso);

  select coalesce(sum(p.monto), 0) into v_recaudado
  from public.pagos p join public.deudas d on d.id = p.deuda_id join public.cuotas c on c.id = d.cuota_id
  where p.curso_id = p_curso and p.estado = 'confirmado' and (p_actividad is null or c.actividad_id = p_actividad);
  v_recaudado := v_recaudado + coalesce((
    select sum(aj.monto) from public.ajustes aj
    join public.pagos p on p.id = aj.pago_id join public.deudas d on d.id = p.deuda_id join public.cuotas c on c.id = d.cuota_id
    where aj.curso_id = p_curso and (p_actividad is null or c.actividad_id = p_actividad)), 0);

  select coalesce(sum(g.monto), 0) into v_gastado
  from public.gastos g
  where g.curso_id = p_curso and g.estado = 'aprobado' and (p_actividad is null or g.actividad_id = p_actividad);
  v_gastado := v_gastado + coalesce((
    select sum(aj.monto) from public.ajustes aj join public.gastos g on g.id = aj.gasto_id
    where aj.curso_id = p_curso and (p_actividad is null or g.actividad_id = p_actividad)), 0);

  select coalesce(sum(g.monto), 0) into v_votacion
  from public.gastos g
  where g.curso_id = p_curso and g.estado = 'en_votacion' and (p_actividad is null or g.actividad_id = p_actividad);

  -- Familias que pagaron todo lo que les toca (en el total o en la actividad)
  select count(*) filter (where pendiente = 0 and tiene), count(*) into v_pagaron, v_familias
  from (
    select a.id,
           coalesce(sum(privado.saldo_de_deuda(d.id)), 0) as pendiente,
           count(d.id) > 0 as tiene
    from public.alumnos a
    left join public.deudas d on d.alumno_id = a.id
      and exists (select 1 from public.cuotas c where c.id = d.cuota_id and c.anulada_en is null
                  and (p_actividad is null or c.actividad_id = p_actividad))
    where a.curso_id = p_curso
    group by a.id
  ) f;

  return jsonb_build_object(
    'recaudado', v_recaudado, 'gastado', v_gastado, 'saldo', v_recaudado - v_gastado,
    'en_votacion', v_votacion, 'familias_pagaron', v_pagaron, 'familias', v_familias);
end $function$;

CREATE OR REPLACE FUNCTION public.resultado_votacion (
  p_gasto uuid
)
  RETURNS TABLE (
    a_favor    integer,
    en_contra  integer,
    familias   integer,
    mi_voto    boolean,
    vota_hasta timestamp with time zone,
    estado     public.estado_gasto
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_gasto public.gastos;
begin
  select * into v_gasto from public.gastos where id = p_gasto;
  if not found or not privado.ve_cuentas(v_gasto.curso_id) then raise exception 'sin_permiso'; end if;
  return query
    select (count(*) filter (where v.a_favor))::int, (count(*) filter (where not v.a_favor))::int,
           (select count(*)::int from public.miembros_curso m where m.curso_id = v_gasto.curso_id and m.rol = 'padre'),
           (select v2.a_favor from public.votos v2 where v2.gasto_id = p_gasto and v2.usuario_id = auth.uid()),
           v_gasto.vota_hasta, v_gasto.estado
    from public.votos v where v.gasto_id = p_gasto;
end $function$;

CREATE OR REPLACE FUNCTION public.revisar_pago (
  p_pago      uuid,
  p_confirmar boolean,
  p_motivo    text    DEFAULT NULL::text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_pago    public.pagos;
  v_cuota   public.cuotas;
  v_pagaron int;
  v_total   int;
begin
  select * into v_pago from public.pagos where id = p_pago for update;
  if not found or not privado.es_tesorero(v_pago.curso_id) then raise exception 'sin_permiso'; end if;
  if v_pago.estado <> 'en_revision' then raise exception 'pago_ya_revisado'; end if;
  if p_confirmar then
    update public.pagos set estado = 'confirmado', revisado_por = auth.uid(), revisado_en = now() where id = p_pago;
    select c.* into v_cuota from public.deudas d join public.cuotas c on c.id = d.cuota_id where d.id = v_pago.deuda_id;
    select count(*) filter (where privado.saldo_de_deuda(d.id) = 0), count(*)
      into v_pagaron, v_total from public.deudas d where d.cuota_id = v_cuota.id;
    perform privado.publicar_aviso(v_pago.curso_id, 'pago_confirmado',       -- anónimo (RN-CU17)
      'Se confirmó un pago · ' || v_cuota.concepto || ': ' || v_pagaron || ' de ' || v_total || ' familias',
      'cuotas', v_cuota.id);
  else
    if length(trim(coalesce(p_motivo, ''))) = 0 then raise exception 'motivo_obligatorio'; end if;
    update public.pagos set estado = 'rechazado', motivo_rechazo = trim(p_motivo),
                            revisado_por = auth.uid(), revisado_en = now() where id = p_pago;
  end if;
end $function$;

CREATE OR REPLACE FUNCTION public.unirme_como_padre (
  p_codigo text,
  p_alumno uuid
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_curso   public.cursos;
  v_alumno  public.alumnos;
  v_rol     public.rol_miembro;
begin
  if auth.uid() is null then raise exception 'sin_sesion'; end if;
  select * into v_curso from public.cursos c where c.codigo = upper(trim(p_codigo));
  if not found then raise exception 'codigo_invalido'; end if;
  select * into v_alumno from public.alumnos a where a.id = p_alumno and a.curso_id = v_curso.id for update;
  if not found then raise exception 'alumno_invalido'; end if;
  if v_alumno.padre_id is not null then raise exception 'alumno_ya_tiene_padre'; end if;   -- RN-CU13
  if exists (select 1 from public.alumnos a where a.curso_id = v_curso.id and a.padre_id = auth.uid()) then
    raise exception 'ya_tiene_hijo_en_curso';
  end if;
  select m.rol into v_rol from public.miembros_curso m where m.curso_id = v_curso.id and m.usuario_id = auth.uid();
  if v_rol is null then
    insert into public.miembros_curso (curso_id, usuario_id, rol) values (v_curso.id, auth.uid(), 'padre');
  elsif v_rol <> 'padre' then
    raise exception 'ya_es_miembro';
  end if;
  update public.alumnos set padre_id = auth.uid() where id = p_alumno;
  return v_curso.id;
end $function$;

CREATE OR REPLACE FUNCTION public.unirme_como_profesor (
  p_codigo  text,
  p_materia uuid
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare
  v_curso    public.cursos;
  v_miembro  uuid;
begin
  if auth.uid() is null then raise exception 'sin_sesion'; end if;
  select * into v_curso from public.cursos c where c.codigo_profesor = upper(trim(p_codigo));
  if not found then raise exception 'codigo_invalido'; end if;
  if not exists (select 1 from public.materias ma where ma.id = p_materia and ma.curso_id = v_curso.id) then
    raise exception 'materia_invalida';
  end if;
  if exists (select 1 from public.miembros_curso m where m.curso_id = v_curso.id and m.usuario_id = auth.uid()) then
    raise exception 'ya_es_miembro';
  end if;
  insert into public.miembros_curso (curso_id, usuario_id, rol) values (v_curso.id, auth.uid(), 'profesor')
  returning id into v_miembro;
  begin
    insert into public.profesores_curso (miembro_id, materia_id) values (v_miembro, p_materia);
  exception when unique_violation then
    raise exception 'materia_ocupada';
  end;
  return v_curso.id;
end $function$;

