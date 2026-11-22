import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'estado/sesion.dart';
import 'pantallas/acceso/acceso.dart';
import 'pantallas/actividades/actividades.dart';
import 'pantallas/actividades/detalle.dart';
import 'pantallas/comunicados/comunicados.dart';
import 'pantallas/cuentas/crear_cuota.dart';
import 'pantallas/cuentas/cuentas_curso.dart';
import 'pantallas/cuentas/gastos.dart';
import 'pantallas/cuentas/mis_cuotas.dart';
import 'pantallas/cuentas/nuevo_ajuste.dart';
import 'pantallas/cuentas/pagar_cuota.dart';
import 'pantallas/cuentas/revisar_pago.dart';
import 'pantallas/cuentas/panel_tesorero.dart';
import 'pantallas/curso/crear_curso.dart';
import 'pantallas/agenda/agenda.dart';
import 'pantallas/informes/informes.dart';
import 'pantallas/curso/miembros.dart';
import 'pantallas/curso/nomina.dart';
import 'pantallas/curso/unirme.dart';
import 'pantallas/inicio/inicio.dart';
import 'pantallas/inicio/marco.dart';
import 'pantallas/inicio/perfil.dart';
import 'pantallas/profesores/profesores.dart';
import 'pantallas/vinculacion/alumno.dart';
import 'pantallas/vinculacion/mis_hijos.dart';

const _publicas = {'/bienvenida', '/registro', '/entrar', '/alumno/escanear'};
const _sinCurso = {'/elegir', '/crear-curso', '/curso-creado', '/unirme/padre', '/unirme/profesor', '/alumno/escanear'};

final rutas = GoRouter(
  initialLocation: '/cargando',
  refreshListenable: sesion,
  redirect: (context, state) {
    final loc = state.matchedLocation;
    if (sesion.cargando) return loc == '/cargando' ? null : '/cargando';
    if (sesion.pinPendiente || sesion.alumnoBloqueado) return loc == '/alumno/pin' ? null : '/alumno/pin';
    if (!sesion.conSesion) return _publicas.contains(loc) ? null : '/bienvenida';
    if (sesion.cursos.isEmpty) return _sinCurso.contains(loc) ? null : '/elegir';
    if (sesion.esAlumno) return loc.startsWith('/a/') ? null : '/a/inicio';
    if (loc.startsWith('/a/') || _publicas.contains(loc) || loc == '/cargando' || loc == '/alumno/pin') return '/inicio';
    return null;
  },
  routes: [
    GoRoute(path: '/cargando', builder: (_, _) => const PantallaCargando()),
    GoRoute(path: '/bienvenida', builder: (_, _) => const Bienvenida()),
    GoRoute(path: '/registro', builder: (_, _) => const Registro()),
    GoRoute(path: '/entrar', builder: (_, _) => const IniciarSesion()),
    GoRoute(path: '/elegir', builder: (_, _) => const ElegirEntrada()),
    GoRoute(path: '/crear-curso', builder: (_, _) => const CrearCurso()),
    GoRoute(path: '/curso-creado', builder: (_, _) => const CursoCreado()),
    GoRoute(path: '/nomina', builder: (_, _) => const Nomina()),
    GoRoute(path: '/miembros', builder: (_, _) => const Miembros()),
    GoRoute(path: '/unirme/padre', builder: (_, _) => const UnirmePadre()),
    GoRoute(path: '/unirme/profesor', builder: (_, _) => const UnirmeProfesor()),
    GoRoute(path: '/mis-hijos', builder: (_, _) => const MisHijos()),
    GoRoute(path: '/actividades/nueva', builder: (_, _) => const NuevaActividad()),
    GoRoute(
        path: '/cuotas/nueva',
        builder: (_, s) => CrearCuota(actividadId: (s.extra as Map?)?['actividad_id'] as String?)),
    GoRoute(path: '/cuotas/pagar', builder: (_, s) => PagarCuota(cuota: s.extra as Map<String, dynamic>)),
    GoRoute(path: '/cuotas/resultado', builder: (_, s) => ResultadoPago(datos: s.extra as Map<String, dynamic>)),
    GoRoute(path: '/tesorero', builder: (_, _) => const PanelTesorero(enPestana: false)),
    GoRoute(path: '/pagos/revisar', builder: (_, s) => RevisarPago(pago: s.extra as Map<String, dynamic>)),
    GoRoute(path: '/cuentas/curso', builder: (_, _) => const CuentasCurso(enPestana: false)),
    GoRoute(path: '/calendario', builder: (_, _) => const CalendarioCurso(enPestana: false)),
    GoRoute(path: '/horario', builder: (_, _) => const HorarioCurso(enPestana: false)),
    GoRoute(path: '/perfil', builder: (_, _) => const PerfilUsuario()),
    GoRoute(path: '/profesores', builder: (_, _) => const ListaProfesores()),
    GoRoute(path: '/profesor', builder: (_, s) => PerfilProfesor(profesor: s.extra as Map<String, dynamic>)),
    GoRoute(path: '/informes', builder: (_, _) => const ListaInformes()),
    GoRoute(path: '/informes/redactar', builder: (_, s) => RedactarInforme(datos: s.extra as Map<String, dynamic>)),
    GoRoute(path: '/mi-informe', builder: (_, _) => const MiInforme()),
    GoRoute(path: '/gastos/nuevo', builder: (_, _) => const RegistrarGasto()),
    GoRoute(path: '/gastos/:id', builder: (_, s) => DetalleGasto(id: s.pathParameters['id']!)),
    GoRoute(
        path: '/ajustes/nuevo',
        builder: (_, s) => NuevoAjuste(gastoId: (s.extra as Map?)?['gasto_id'] as String?)),
    GoRoute(path: '/actividad/:id', builder: (_, s) => DetalleActividad(id: s.pathParameters['id']!)),
    GoRoute(
        path: '/actividad/:id/editar',
        builder: (_, s) => NuevaActividad(editar: s.extra as Map<String, dynamic>?)),
    GoRoute(path: '/a/actividad/:id', builder: (_, s) => DetalleActividad(id: s.pathParameters['id']!)),
    GoRoute(path: '/comunicados/nuevo', builder: (_, _) => const NuevoComunicado()),
    GoRoute(path: '/comunicado/:id', builder: (_, s) => DetalleComunicado(id: s.pathParameters['id']!)),
    GoRoute(
        path: '/comunicado/:id/lectores',
        builder: (_, s) => QuienLeyo(id: s.pathParameters['id']!, titulo: s.extra as String?)),
    GoRoute(path: '/alumno/escanear', builder: (_, _) => const AlumnoEscanear()),
    GoRoute(path: '/alumno/pin', builder: (_, _) => const AlumnoPin()),
    StatefulShellRoute.indexedStack(
      builder: (_, _, nav) => MarcoAdulto(nav: nav),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/inicio', builder: (_, _) => const InicioCurso())]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/actividades', builder: (_, _) => const ListaActividades())
        ]),
        StatefulShellBranch(
            routes: [GoRoute(path: '/muro', builder: (_, _) => const Muro())]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/cuentas',
              builder: (_, _) => sesion.curso?.esAsesor == true
                  ? const CuentasCurso()
                  : sesion.curso?.esPadre == true
                      ? const MisCuotas()
                      : sesion.curso?.esTesorero == true
                          ? const PanelTesorero()
                          : const Proximamente('Cuentas', Icons.account_balance_wallet_outlined))
        ]),
        StatefulShellBranch(routes: [GoRoute(path: '/mas', builder: (_, _) => const Mas())]),
      ],
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, nav) => MarcoAlumno(nav: nav),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/a/inicio', builder: (_, _) => const InicioAlumno())]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/a/tareas', builder: (_, _) => const ListaActividades())
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/a/calendario', builder: (_, _) => const CalendarioCurso())
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/a/horario', builder: (_, _) => const HorarioCurso())
        ]),
      ],
    ),
  ],
);
