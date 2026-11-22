-- Cursito · 0006 · Quitar el acceso del alumno (R-CU46): también se libera el correo en auth.identities,
-- para que un QR nuevo pueda crear la cuenta `alumno-<alumno_id>@cursito.app` otra vez.
create or replace function public.quitar_acceso_alumno(p_alumno uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_alumno public.alumnos;
  v_baja   text;
begin
  if not privado.es_padre_de(p_alumno) then raise exception 'sin_permiso'; end if;
  select * into v_alumno from public.alumnos where id = p_alumno for update;
  if v_alumno.usuario_alumno_id is null then return; end if;
  v_baja := 'baja-' || v_alumno.usuario_alumno_id || '@cursito.app';
  update public.alumnos set usuario_alumno_id = null where id = p_alumno;
  delete from public.miembros_curso where curso_id = v_alumno.curso_id and usuario_id = v_alumno.usuario_alumno_id;
  update auth.users set banned_until = 'infinity', email = v_baja where id = v_alumno.usuario_alumno_id;
  update auth.identities set identity_data = jsonb_set(identity_data, '{email}', to_jsonb(v_baja))
  where user_id = v_alumno.usuario_alumno_id;
  delete from auth.sessions where user_id = v_alumno.usuario_alumno_id;
  update public.tokens_vinculacion set invalidado_en = now()
  where alumno_id = p_alumno and usado_en is null and invalidado_en is null;
end $$;

revoke execute on function public.quitar_acceso_alumno(uuid) from public, anon;
grant execute on function public.quitar_acceso_alumno(uuid) to authenticated;

-- Arreglo de datos locales previos a esta migración
update auth.identities i set identity_data = jsonb_set(i.identity_data, '{email}', to_jsonb(u.email::text))
from auth.users u
where u.id = i.user_id and u.email like 'baja-%' and i.identity_data ->> 'email' is distinct from u.email;
