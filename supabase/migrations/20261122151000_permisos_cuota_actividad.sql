-- Cursito · permisos de cuota y de eventos, y quitar el QR de cobro
-- Decisión del equipo (22 nov 2026, observaciones de la prueba en 3 teléfonos):
--   · la cuota la crea el tesorero o el asesor (cambia RN-CU16),
--   · los eventos los publica el asesor o el tesorero (cambia RN-CU20); las tareas siguen siendo de los docentes.

drop policy if exists crear_cuota on public.cuotas;
create policy crear_cuota on public.cuotas for insert to authenticated
  with check (privado.es_tesorero(curso_id) or privado.es_asesor(curso_id));

drop policy if exists publicar_actividad on public.actividades;
create policy publicar_actividad on public.actividades for insert to authenticated
  with check (
    (tipo = 'evento' and (privado.es_asesor(curso_id) or privado.es_tesorero(curso_id)))
    or (tipo = 'tarea' and (
          privado.es_asesor(curso_id)
          or exists (select 1 from public.profesores_curso pc
                     join public.miembros_curso m on m.id = pc.miembro_id
                     where pc.materia_id = actividades.materia_id and m.usuario_id = auth.uid()
                       and m.curso_id = actividades.curso_id and m.rol = 'profesor'))));

-- Quien publicó un evento (docente o tesorero) puede editarlo o cancelarlo.
drop policy if exists editar_mi_actividad on public.actividades;
create policy editar_mi_actividad on public.actividades for update to authenticated
  using (creado_por = auth.uid() and (privado.es_docente(curso_id) or privado.es_tesorero(curso_id)))
  with check (creado_por = auth.uid());

-- El tesorero quita su QR de cobro (los padres vuelven a ver «el tesorero todavía no subió su QR»).
create or replace function public.quitar_qr_cobro(p_curso uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not privado.es_tesorero(p_curso) then raise exception 'sin_permiso'; end if;
  update public.cursos set qr_cobro_path = null where id = p_curso;
end $$;

revoke all on function public.quitar_qr_cobro(uuid) from public, anon;
grant execute on function public.quitar_qr_cobro(uuid) to authenticated;
