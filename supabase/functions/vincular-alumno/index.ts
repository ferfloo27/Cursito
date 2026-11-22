// Cursito · Edge Function `vincular-alumno` (§13.4, RN-CU12, ADR-CU04)
// Recibe { token } del QR que generó el padre y devuelve las credenciales y la sesión del alumno.
// 1. Reclama el token de forma atómica (un solo uso, 10 minutos).
// 2. Crea la cuenta del alumno (correo sintético y contraseña aleatoria de 32 caracteres) o, si cambió
//    de teléfono, le pone una contraseña nueva.
// 3. Liga la cuenta a la nómina y crea la membresía `alumno`.
// 4. Inicia sesión y devuelve { email, password, session }. La app guarda email y contraseña en el
//    almacenamiento seguro; el PIN de 4 dígitos sólo desbloquea la app en ese teléfono.
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function respuesta(cuerpo: unknown, estado = 200) {
  return new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function claveAleatoria(largo = 32): string {
  const alfabeto = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(largo));
  return Array.from(bytes, (b) => alfabeto[b % alfabeto.length]).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return respuesta({ error: "metodo_no_permitido" }, 405);

  let token: unknown;
  try {
    ({ token } = await req.json());
  } catch {
    return respuesta({ error: "qr_invalido" }, 400);
  }
  if (typeof token !== "string" || token.length < 32 || token.length > 128) {
    return respuesta({ error: "qr_invalido" }, 400);
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 1. Token de un solo uso
  const { data: filas, error: errToken } = await admin.rpc("reclamar_token_vinculacion", { p_token: token });
  if (errToken || !filas || filas.length === 0) return respuesta({ error: "qr_invalido" }, 400);
  const alumno = filas[0] as { alumno_id: string; curso_id: string; nombre: string; usuario_alumno_id: string | null };

  const email = `alumno-${alumno.alumno_id}@cursito.app`;
  const password = claveAleatoria();

  // 2. Cuenta nueva o cambio de teléfono
  let usuarioId = alumno.usuario_alumno_id;
  if (usuarioId) {
    const { error } = await admin.auth.admin.updateUserById(usuarioId, { password });
    if (error) {
      console.error("updateUserById", error.message);
      return respuesta({ error: "no_se_pudo_vincular" }, 500);
    }
  } else {
    const { data, error } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { nombre: alumno.nombre, es_alumno: true },
    });
    if (error || !data.user) {
      console.error("createUser", error?.message);
      return respuesta({ error: "no_se_pudo_vincular" }, 500);
    }
    usuarioId = data.user.id;
  }

  // 3. Nómina y membresía
  const { error: errVinc } = await admin.rpc("completar_vinculacion", {
    p_alumno: alumno.alumno_id,
    p_usuario: usuarioId,
  });
  if (errVinc) {
    console.error("completar_vinculacion", errVinc.message);
    return respuesta({ error: "no_se_pudo_vincular" }, 500);
  }

  // 4. Sesión
  const publico = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: sesion, error: errSesion } = await publico.auth.signInWithPassword({ email, password });
  if (errSesion || !sesion.session) {
    console.error("signInWithPassword", errSesion?.message);
    return respuesta({ error: "no_se_pudo_vincular" }, 500);
  }

  return respuesta({
    email,
    password,
    alumno: alumno.nombre,
    curso_id: alumno.curso_id,
    session: sesion.session,
  });
});
