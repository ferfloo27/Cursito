# Cursito

Un curso, un solo lugar: comunicación y cuentas claras del curso escolar entre docentes, familias y alumnos.
MVP del Abstracthon 2026. App Android (APK, Android 8 o superior) hecha en Flutter sobre Supabase
(Postgres, Auth, Storage, RLS y una Edge Function).

La documentación del producto (requisitos, reglas, decisiones) vive en un repositorio aparte:
https://github.com/ferfloo27/docs-cursito

## Estructura

| Ruta | Qué hay |
| --- | --- |
| `lib/` | App Flutter |
| `supabase/migrations/` | Esquema, lógica (triggers y RPC), RLS, Storage y `pg_cron` |
| `supabase/seed.sql` | Semilla de la demo: 4.º B Primaria, U.E. San Andrés |
| `supabase/semilla/` | Imágenes de la semilla y script para subirlas a Storage |
| `supabase/functions/vincular-alumno/` | Edge Function que crea la cuenta del alumno al escanear el QR |
| `supabase/pruebas/rls_por_rol.sql` | Prueba de seguridad por rol (se corre a mano) |
| `tool/` | Scripts de apoyo (generar las imágenes de la semilla) |

## Arranque local

Requisitos: Flutter 3.47 o más nuevo, Node 20 o más nuevo y Docker Desktop.

```powershell
npx supabase start -x vector,logflare,studio,imgproxy,mailpit,realtime,supavisor
$env:SUPABASE_URL = "http://127.0.0.1:56321"; $env:SUPABASE_SECRET_KEY = "<SERVICE_ROLE_KEY que muestra supabase start>"
node supabase/semilla/subir_imagenes.mjs
```

Copia `env.example.json` como `env.json` con la URL y la clave publicable, y corre la app así:

```powershell
flutter run --dart-define-from-file=env.json
```

Para volver a cargar la semilla: `npx supabase db reset` y después vuelve a subir las imágenes.

## Cuentas de la demo

Son datos sintéticos. Todas las cuentas usan la contraseña `cursito2026`.

| Rol | Correo |
| --- | --- |
| Asesora (Artes Plásticas) | `rocio.mamani@cursito.test` |
| Profesores | `carlos.quispe@` (Lenguaje) · `ana.villca@` (Matemática) · `jorge.choque@` (Ciencias Naturales) · `luis.rojas@` (Educación Física) · `elena.flores@` (Música) — todos `@cursito.test` |
| Tesorero (padre delegado) | `javier.gutierrez@cursito.test` |
| Padres | `marta.condori@` · `silvia.rojas@` · `oscar.mamani@` · `lucia.torrez@` · `rosa.huanca@` · `ana.vargas@` · `pedro.perez@` — todos `@cursito.test` |

Código del curso: `SAN4B7` · código de profesor: `PRF-K2Q9`. Los alumnos no tienen cuenta:
el padre genera el QR en «Mis hijos» y el alumno entra escaneándolo.

## Prueba de seguridad por rol

```powershell
docker cp supabase/pruebas/rls_por_rol.sql supabase_db_cursito:/tmp/rls.sql
docker exec supabase_db_cursito psql -U postgres -q -f /tmp/rls.sql
```

Cada prueba imprime `PASS T-CUxx`. El mismo archivo se puede pegar en el editor SQL del proyecto,
sin las líneas que empiezan con `\`.
