import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'estado/sesion.dart';
import 'pantallas/acceso/acceso.dart';
import 'pantallas/curso/crear_curso.dart';
import 'pantallas/curso/miembros.dart';
import 'pantallas/curso/nomina.dart';
import 'pantallas/curso/unirme.dart';
import 'pantallas/inicio/inicio.dart';
import 'pantallas/inicio/marco.dart';
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
    GoRoute(path: '/alumno/escanear', builder: (_, _) => const AlumnoEscanear()),
    GoRoute(path: '/alumno/pin', builder: (_, _) => const AlumnoPin()),
    StatefulShellRoute.indexedStack(
      builder: (_, _, nav) => MarcoAdulto(nav: nav),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/inicio', builder: (_, _) => const InicioCurso())]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/actividades', builder: (_, _) => const Proximamente('Actividades', Icons.event_note_outlined))
        ]),
        StatefulShellBranch(
            routes: [GoRoute(path: '/muro', builder: (_, _) => const Proximamente('Muro', Icons.forum_outlined))]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/cuentas', builder: (_, _) => const Proximamente('Cuentas', Icons.account_balance_wallet_outlined))
        ]),
        StatefulShellBranch(routes: [GoRoute(path: '/mas', builder: (_, _) => const Mas())]),
      ],
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, nav) => MarcoAlumno(nav: nav),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/a/inicio', builder: (_, _) => const InicioAlumno())]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/a/tareas', builder: (_, _) => const Proximamente('Tareas', Icons.assignment_outlined))
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/a/calendario', builder: (_, _) => const Proximamente('Calendario', Icons.calendar_month_outlined))
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/a/horario', builder: (_, _) => const Proximamente('Horario', Icons.schedule_outlined))
        ]),
      ],
    ),
  ],
);
