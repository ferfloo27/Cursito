# Cursito

Un curso, un solo lugar: comunicación y cuentas claras del curso escolar entre docentes, familias y alumnos.
MVP del Abstracthon 2026. App Android (APK, Android 8 o superior) y Web hecha en Flutter sobre Supabase
(Postgres, Auth, Storage, RLS y una Edge Function).

La documentación del producto (requisitos, reglas, decisiones) vive en un repositorio aparte:
https://github.com/ferfloo27/docs-cursito

## Estado del Proyecto (22/11/2026)

| Componente | Estado | Detalles |
|-----------|--------|----------|
| **Code Quality** | ✓ Validado | 0 errores, 1 warning ignorable |
| **Web Build** | ✓ Compilado | 100+ archivos, ~15-20 MB |
| **APK Build** | ✓ Compilado | v0.1.0+1, 73.98 MB |
| **Fases Implementadas** | ✓ Fase 2, 3, Nivel B | Testeadas en Supabase Cloud |
| **Supabase Config** | ✓ Integrado | Cloud (producción) |
| **Assets** | ✓ Incluidos | env.json empaquetado en APK |

## Estructura del Proyecto

| Ruta | Qué hay |
| --- | --- |
| `lib/` | Código Flutter de la aplicación |
| `lib/pantallas/` | Pantallas principales (Fases 2, 3, Nivel B) |
| `lib/modelos/` | Modelos de datos |
| `build/web/` | Web build compilado (listo para desplegar) |
| `build/app/outputs/flutter-apk/` | APK compilado |
| `assets/` | Archivos estáticos (incluye env.json) |
| `supabase/migrations/` | Esquema, lógica (triggers y RPC), RLS, Storage |
| `supabase/seed.sql` | Semilla de la demo: 4.º B Primaria, U.E. San Andrés |
| `supabase/semilla/imagenes/` | Imágenes de avatares y recursos |
| `supabase/functions/vincular-alumno/` | Edge Function que crea la cuenta del alumno al escanear el QR |
| `supabase/pruebas/rls_por_rol.sql` | Prueba de seguridad por rol |
| `tool/` | Scripts de apoyo |
| `pubspec.yaml` | Dependencias Flutter |

## Instalación y Uso

### Requisitos

- Flutter 3.13.5 o más nuevo
- Android SDK 21+ (para APK)
- Dispositivo Android 8+ o emulador
- Supabase Cloud account (ya configurado)

### Descargar e Instalar APK

1. **Descarga la última versión APK:**
   - Ve a [Releases](../../releases)
   - Descarga `app-release.apk` (v0.1.0+1)

2. **Instala en tu dispositivo:**
   ```powershell
   adb install -r app-release.apk
   ```

   **Requisitos en el dispositivo:**
   - Depuración USB habilitada (Configuración > Opciones de Desarrollador > Depuración USB)
   - Cable USB conectado

3. **Abre Cursito desde el menú de apps**

### Build Personalizado

Si necesitas recompilar con credenciales distintas:

#### APK Android
```powershell
flutter clean
flutter pub get
flutter build apk --dart-define-from-file=env.json
```
APK generado: `build/app/outputs/flutter-apk/app-release.apk`

#### Web
```powershell
flutter clean
flutter pub get
flutter build web --dart-define-from-file=env.json
```
Web build: `build/web/` - Listo para desplegar a Firebase Hosting, Netlify, Vercel, etc.

### Despliegue Web

1. **Firebase Hosting:**
```powershell
npm install -g firebase-tools
firebase login
firebase init hosting
# Copia build/web/* a public/
firebase deploy
```

2. **Netlify (más simple):**
   - Arrastra y suelta la carpeta `build/web/` en https://app.netlify.com/

3. **Otros servicios:**
   - AWS S3 + CloudFront
   - Vercel
   - GitHub Pages
   - Azure Static Web Apps

## Cuentas de la Demo

Son datos sintéticos. Todas las cuentas usan la contraseña `cursito2026`.

| Rol | Correo |
| --- | --- |
| Asesora (Artes Plásticas) | `rocio.mamani@cursito.test` |
| Profesores | `carlos.quispe@` (Lenguaje) · `ana.villca@` (Matemática) · `jorge.choque@` (Ciencias Naturales) · `luis.rojas@` (Educación Física) · `elena.flores@` (Música) — todos `@cursito.test` |
| Tesorero (padre delegado) | `javier.gutierrez@cursito.test` |
| Padres | `marta.condori@` · `silvia.rojas@` · `oscar.mamani@` · `lucia.torrez@` · `rosa.huanca@` · `ana.vargas@` · `pedro.perez@` — todos `@cursito.test` |

**Acceso a curso:**
- Código del curso: `SAN4B7`
- Código de profesor: `PRF-K2Q9`
- Los alumnos acceden escaneando QR generado por el padre

## Fases Implementadas

### ✓ Fase 2: Gestión de Gastos de Curso
- Registro de gastos (concepto, monto, fecha)
- Categorización de gastos
- Visualización de gastos por período
- Cálculo automático de cuotas

### ✓ Fase 3: Pagos de Cuotas
- Registro de pagos de alumnos
- Generación de comprobantes
- Control de pagos pendientes
- Reporte de recaudación

### ✓ Nivel B: Panel de Tesorero
- Dashboard con resumen de finanzas
- Reportes por alumno/padre
- Auditoría de movimientos
- Exportación de reportes

## Stack Tecnológico

- **Frontend:** Flutter 3.13.5
- **Backend:** Supabase Cloud (Postgres, Auth, Storage, Edge Functions)
- **Base de Datos:** PostgreSQL 15+
- **Seguridad:** Row Level Security (RLS), Auth JWT
- **Almacenamiento:** Supabase Storage
- **State Management:** Riverpod
- **Router:** GoRouter
- **Styling:** Material 3

## Dependencias Principales

Ver `pubspec.yaml` para la lista completa. Principales:

- `supabase_flutter: ^2.18.3` - Cliente Supabase
- `flutter_riverpod: ^3.5.0` - State management
- `go_router: ^18.1.4` - Navegación
- `storage_client: ^2.8.1` - Cliente Storage
- `flutter_secure_storage: ^11.2.0` - Almacenamiento seguro
- `mobile_scanner: ^7.5.0` - Escaneo de QR
- `qr_flutter: ^4.1.0` - Generación de QR

## Variantes de Build

| Comando | Propósito | Output |
|---------|-----------|--------|
| `flutter build apk --dart-define-from-file=env.json` | Producción Android | APK release (73.98 MB) |
| `flutter build web --dart-define-from-file=env.json` | Producción Web | HTML/JS (~15-20 MB) |

## Troubleshooting

### Falta env.json en APK
**Solución:** Verifica que `env.json` esté en la raíz y declarado en `pubspec.yaml` bajo `flutter.assets`.

### Supabase no conecta
**Solución:** Verifica que `env.json` tiene credenciales correctas de Supabase Cloud (URL y PUBLIC KEY).

### APK no instala
**Solución:** Verifica que depuración USB está habilitada en el dispositivo y que el cable está conectado. Usa `adb devices` para listar.

### RLS denies access
**Solución:** Verifica que el usuario tiene permisos en la política de RLS de Supabase.

## Notas de Desarrollo

- Código compilado exitosamente: 0 errores, 1 warning ignorable
- APK testado en Supabase Cloud con cuenta de padre: Funciona correctamente
- Todas las Fases (2, 3, Nivel B) implementadas y operacionales
- Supabase RLS configurado correctamente
- Variables de entorno inyectadas en tiempo de compilación
- Almacenamiento en Supabase Storage con buckets: comprobantes, facturas, qr_cobro

## Despliegue en Producción

1. Descargar APK desde [Releases](../../releases)
2. Instalar en dispositivos Android 8+
3. Configurar credenciales de Supabase Cloud en `env.json`
4. Desplegar web a Firebase, Netlify o similar
5. Comunicar a usuarios las credenciales de acceso

## Licencia

Abstracthon 2026 - MVP

## Contacto

Para más información sobre el producto: https://github.com/ferfloo27/docs-cursito
