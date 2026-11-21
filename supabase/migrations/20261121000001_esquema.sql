-- Cursito · 0001 · Tipos, tablas y restricciones
-- Fuente: ../docs/09-Entradas/2026-11-21-requerimientos-iniciales/documento/requerimientos.md §13.2-13.3,
-- con los ajustes de ../docs/02-Arquitectura/Decisiones por resolver.md (rondas 1-4).

create schema if not exists privado;

-- ---------------------------------------------------------------- Tipos
create type public.rol_miembro as enum ('asesor', 'profesor', 'padre', 'alumno');
create type public.nivel_curso as enum ('inicial', 'primaria', 'secundaria');          -- Q-CU-CUR-07
create type public.tipo_actividad as enum ('tarea', 'evento');
create type public.tipo_comunicado as enum ('aviso', 'recordatorio', 'urgente');
create type public.calificacion as enum ('bueno', 'regular', 'por_mejorar');           -- en pantalla «Necesita mejorar» (Q-CU-INF-04)
create type public.estado_pago as enum ('en_revision', 'confirmado', 'rechazado');
create type public.estado_gasto as enum ('aprobado', 'en_votacion', 'rechazado');
create type public.categoria_gasto as enum ('obsequio', 'comida', 'materiales', 'otro'); -- Q-CU-GAS-05
create type public.respuesta_asistencia as enum ('asiste', 'no_asiste');
create type public.tipo_aviso as enum (
  'cuota_nueva', 'cuota_anulada', 'pago_confirmado', 'gasto_registrado',
  'votacion_abierta', 'votacion_cerrada', 'ajuste',
  'actividad_cambiada', 'actividad_cancelada',  -- R-CU47
  'horario_cambiado',                            -- R-CU29
  'recordatorio_cuota',                          -- R-CU39 (privado)
  'recordatorio_comunicado'                      -- R-CU48 (privado)
);

-- ---------------------------------------------------------------- Núcleo
create table public.perfiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  nombre     text not null check (length(trim(nombre)) > 0),
  telefono   text,                              -- opcional, no se muestra (Q-CU-ACC-03)
  es_alumno  boolean not null default false,
  creado_en  timestamptz not null default now()
);

create table public.cursos (
  id               uuid primary key default gen_random_uuid(),
  nombre           text not null check (length(trim(nombre)) > 0),
  colegio          text not null check (length(trim(colegio)) > 0),
  nivel            public.nivel_curso not null,
  gestion          int not null check (gestion between 2000 and 2100),
  codigo           text not null unique check (codigo ~ '^[A-Z0-9]{6}$'),
  codigo_profesor  text not null unique check (codigo_profesor ~ '^PRF-[A-Z0-9]{4}$'),
  umbral_votacion  numeric(10,2) not null default 100 check (umbral_votacion > 0),
  dias_votacion    int not null default 2 check (dias_votacion = 2),           -- fijo (Q-CU-GAS-06)
  qr_cobro_path    text,                                                       -- R-CU42
  creado_por       uuid references public.perfiles (id),
  creado_en        timestamptz not null default now()
);

create table public.miembros_curso (
  id           uuid primary key default gen_random_uuid(),
  curso_id     uuid not null references public.cursos (id) on delete cascade,
  usuario_id   uuid not null references public.perfiles (id) on delete cascade,
  rol          public.rol_miembro not null,
  es_tesorero  boolean not null default false,
  es_delegado  boolean not null default false,
  unido_en     timestamptz not null default now(),
  unique (curso_id, usuario_id),
  check (not es_delegado or rol = 'padre'),
  check (not es_tesorero or rol in ('asesor', 'padre'))
);
create unique index miembros_un_tesorero on public.miembros_curso (curso_id) where es_tesorero;          -- RN-CU02
create unique index miembros_un_asesor_por_curso on public.miembros_curso (curso_id) where rol = 'asesor';
create unique index miembros_asesor_de_un_curso on public.miembros_curso (usuario_id) where rol = 'asesor'; -- RN-CU18

create table public.alumnos (
  id                 uuid primary key default gen_random_uuid(),
  curso_id           uuid not null references public.cursos (id) on delete cascade,
  nombres            text not null check (length(trim(nombres)) > 0),
  apellidos          text not null check (length(trim(apellidos)) > 0),
  padre_id           uuid references public.perfiles (id),
  usuario_alumno_id  uuid unique references public.perfiles (id),
  creado_en          timestamptz not null default now(),
  unique (curso_id, padre_id),   -- un hijo por curso en el MVP (RN-CU13)
  unique (id, curso_id)
);

create table public.tokens_vinculacion (
  id             uuid primary key default gen_random_uuid(),
  alumno_id      uuid not null references public.alumnos (id) on delete cascade,
  token_hash     text not null unique,     -- sha256 hex; el token en claro sólo vive en el QR
  creado_por     uuid references public.perfiles (id),
  creado_en      timestamptz not null default now(),
  expira_en      timestamptz not null default now() + interval '10 minutes',
  usado_en       timestamptz,
  invalidado_en  timestamptz
);

create table public.materias (
  id        uuid primary key default gen_random_uuid(),
  curso_id  uuid not null references public.cursos (id) on delete cascade,
  nombre    text not null,
  unique (curso_id, nombre),
  unique (id, curso_id)
);

create table public.profesores_curso (
  id          uuid primary key default gen_random_uuid(),
  miembro_id  uuid not null unique references public.miembros_curso (id) on delete cascade, -- una materia por docente y curso
  materia_id  uuid not null unique references public.materias (id) on delete cascade          -- una materia, un profesor
);

create table public.horario_bloques (
  id           uuid primary key default gen_random_uuid(),
  curso_id     uuid not null references public.cursos (id) on delete cascade,
  dia          smallint not null check (dia between 1 and 5),
  hora_inicio  time not null,
  hora_fin     time not null,
  materia_id   uuid not null,
  foreign key (materia_id, curso_id) references public.materias (id, curso_id) on delete cascade,
  check (hora_fin > hora_inicio)
);

-- ---------------------------------------------------------------- Actividades
create table public.actividades (
  id                 uuid primary key default gen_random_uuid(),
  curso_id           uuid not null references public.cursos (id) on delete cascade,
  tipo               public.tipo_actividad not null,
  titulo             text not null check (length(trim(titulo)) > 0),
  descripcion        text,
  materia_id         uuid,
  fecha              timestamptz not null,
  lugar              text,
  pide_asistencia    boolean not null default false,
  pide_autorizacion  boolean not null default false,   -- R-CU38 (Should)
  cancelada_en       timestamptz,                      -- R-CU47
  creado_por         uuid references public.perfiles (id),
  creado_en          timestamptz not null default now(),
  actualizado_en     timestamptz,
  unique (id, curso_id),
  foreign key (materia_id, curso_id) references public.materias (id, curso_id),
  check (tipo <> 'tarea' or materia_id is not null),
  check (tipo = 'evento' or (not pide_asistencia and not pide_autorizacion))  -- la tarea sólo se anuncia (Q-CU-ACT-06)
);

create table public.comentarios (
  id            uuid primary key default gen_random_uuid(),
  actividad_id  uuid not null references public.actividades (id) on delete cascade,
  autor_id      uuid not null references public.perfiles (id),
  texto         text not null check (length(trim(texto)) between 1 and 500),
  creado_en     timestamptz not null default now(),
  oculto        boolean not null default false,
  oculto_por    uuid references public.perfiles (id),
  oculto_en     timestamptz
);

create table public.asistencias (
  id              uuid primary key default gen_random_uuid(),
  actividad_id    uuid not null references public.actividades (id) on delete cascade,
  alumno_id       uuid not null references public.alumnos (id) on delete cascade,
  respuesta       public.respuesta_asistencia not null,
  respondido_por  uuid references public.perfiles (id),
  respondido_en   timestamptz not null default now(),
  unique (actividad_id, alumno_id)
);

create table public.autorizaciones (       -- R-CU38 (Should): distinto de la asistencia (Q-CU-ACT-05)
  actividad_id    uuid not null references public.actividades (id) on delete cascade,
  alumno_id       uuid not null references public.alumnos (id) on delete cascade,
  autorizado_por  uuid references public.perfiles (id),
  autorizado_en   timestamptz not null default now(),
  primary key (actividad_id, alumno_id)
);

-- ---------------------------------------------------------------- Comunicación
create table public.comunicados (
  id             uuid primary key default gen_random_uuid(),
  curso_id       uuid not null references public.cursos (id) on delete cascade,
  tipo           public.tipo_comunicado not null,
  titulo         text not null check (length(trim(titulo)) > 0),
  cuerpo         text not null check (length(trim(cuerpo)) > 0),
  actividad_id   uuid,
  pide_enterado  boolean not null default true,   -- Q-CU-COM-02
  autor_id       uuid references public.perfiles (id),
  creado_en      timestamptz not null default now(),
  foreign key (actividad_id, curso_id) references public.actividades (id, curso_id)
);

create table public.lecturas_comunicado (
  comunicado_id  uuid not null references public.comunicados (id) on delete cascade,
  usuario_id     uuid not null references public.perfiles (id),
  leido_en       timestamptz not null default now(),
  primary key (comunicado_id, usuario_id)
);

create table public.informes_alumno (
  id              uuid primary key default gen_random_uuid(),
  alumno_id       uuid not null references public.alumnos (id) on delete cascade,
  periodo         text not null check (periodo in ('1.er trimestre', '2.º trimestre', '3.er trimestre')), -- Q-CU-INF-02
  rendimiento     public.calificacion,
  conducta        public.calificacion,
  participacion   public.calificacion,
  puntualidad     public.calificacion,
  tareas          public.calificacion,
  observaciones   text,
  autor_id        uuid references public.perfiles (id),
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz,
  enviado_en      timestamptz,   -- nulo = borrador (Q-CU-INF-03)
  leido_en        timestamptz,
  unique (alumno_id, periodo),
  check (enviado_en is null or (rendimiento is not null and conducta is not null and participacion is not null
                                 and puntualidad is not null and tareas is not null)),
  check (leido_en is null or enviado_en is not null)
);

create table public.avisos (
  id               uuid primary key default gen_random_uuid(),
  curso_id         uuid not null references public.cursos (id) on delete cascade,
  tipo             public.tipo_aviso not null,
  texto            text not null,
  ref_tabla        text,
  ref_id           uuid,
  destinatario_id  uuid references public.perfiles (id),   -- nulo = para todo el muro; si no, aviso privado
  creado_en        timestamptz not null default now()
);
create index avisos_curso_fecha on public.avisos (curso_id, creado_en desc);

-- ---------------------------------------------------------------- Finanzas
create table public.cuotas (
  id                uuid primary key default gen_random_uuid(),
  curso_id          uuid not null references public.cursos (id) on delete cascade,
  actividad_id      uuid,
  concepto          text not null check (length(trim(concepto)) > 0),
  monto_por_alumno  numeric(10,2) not null check (monto_por_alumno > 0),
  vence_el          date not null,
  creado_por        uuid references public.perfiles (id),
  creado_en         timestamptz not null default now(),
  anulada_en        timestamptz,     -- Q-CU-PAG-08
  anulada_por       uuid references public.perfiles (id),
  motivo_anulacion  text,
  foreign key (actividad_id, curso_id) references public.actividades (id, curso_id),
  check (anulada_en is null or length(trim(coalesce(motivo_anulacion, ''))) > 0)
);

create table public.deudas (
  id         uuid primary key default gen_random_uuid(),
  cuota_id   uuid not null references public.cuotas (id) on delete cascade,
  alumno_id  uuid not null references public.alumnos (id) on delete cascade,
  monto      numeric(10,2) not null check (monto > 0),
  unique (cuota_id, alumno_id)
);

create table public.pagos (
  id                uuid primary key default gen_random_uuid(),
  curso_id          uuid not null references public.cursos (id),
  deuda_id          uuid not null references public.deudas (id),
  pagado_por        uuid not null references public.perfiles (id),
  monto             numeric(10,2) not null check (monto > 0),
  nro_transaccion   text not null check (nro_transaccion ~ '^[^\s-]+$'),   -- normalizado
  comprobante_path  text not null,
  estado            public.estado_pago not null default 'en_revision',
  motivo_rechazo    text,
  revisado_por      uuid references public.perfiles (id),
  revisado_en       timestamptz,
  creado_en         timestamptz not null default now(),
  check (estado <> 'rechazado' or length(trim(coalesce(motivo_rechazo, ''))) > 0)
);
create unique index pagos_nro_unico_por_curso on public.pagos (curso_id, nro_transaccion)
  where estado <> 'rechazado';                                                   -- RN-CU06

create table public.gastos (
  id              uuid primary key default gen_random_uuid(),
  curso_id        uuid not null references public.cursos (id),
  actividad_id    uuid,
  concepto        text not null check (length(trim(concepto)) > 0),
  categoria       public.categoria_gasto not null,
  monto           numeric(10,2) not null check (monto > 0),
  factura_path    text not null check (length(trim(factura_path)) > 0),     -- RN-CU19
  estado          public.estado_gasto not null default 'aprobado',
  vota_hasta      timestamptz,
  registrado_por  uuid references public.perfiles (id),
  creado_en       timestamptz not null default now(),
  cerrado_en      timestamptz,
  foreign key (actividad_id, curso_id) references public.actividades (id, curso_id)
);

create table public.votos (
  gasto_id    uuid not null references public.gastos (id),
  usuario_id  uuid not null references public.perfiles (id),
  a_favor     boolean not null,
  creado_en   timestamptz not null default now(),
  primary key (gasto_id, usuario_id)                                             -- un voto por padre
);

create table public.ajustes (
  id         uuid primary key default gen_random_uuid(),
  curso_id   uuid not null references public.cursos (id),
  pago_id    uuid references public.pagos (id),
  gasto_id   uuid references public.gastos (id),
  monto      numeric(10,2) not null check (monto <> 0),
  motivo     text not null,
  autor_id   uuid references public.perfiles (id),
  creado_en  timestamptz not null default now(),
  check (num_nonnulls(pago_id, gasto_id) = 1),
  check (length(trim(motivo)) >= 10)                                             -- RN-CU05
);
