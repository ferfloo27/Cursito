-- Cursito · contacto de docentes (R-CU28, RF-C09)
-- Los padres y los docentes del curso pueden ver el celular de un docente (asesor o profesor) del mismo curso.
-- El celular del resto de las personas sigue sin mostrarse (0003_rls: sólo id, nombre, es_alumno, creado_en).
-- No hay chat (SRC-CU01 §0): el contacto es el celular que el docente registró.

create or replace function public.contacto_docente(p_miembro uuid) returns text
language plpgsql stable security definer set search_path = '' as $$
declare
  v_m public.miembros_curso;
begin
  select * into v_m from public.miembros_curso where id = p_miembro;
  if not found or v_m.rol not in ('asesor', 'profesor') then raise exception 'no_encontrado'; end if;
  if not privado.es_adulto(v_m.curso_id) then raise exception 'sin_permiso'; end if;
  return (select nullif(trim(p.telefono), '') from public.perfiles p where p.id = v_m.usuario_id);
end $$;

revoke all on function public.contacto_docente(uuid) from public, anon;
grant execute on function public.contacto_docente(uuid) to authenticated;
