import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema.dart';
import '../../estado/sesion.dart';

/// Barra inferior de padres, profesores y tesorero: Inicio · Actividades · Muro · Cuentas · Más.
/// «Cuentas» sólo para quien ve la rendición (padres y asesor: Q-CU-REN-01).
class MarcoAdulto extends StatelessWidget {
  const MarcoAdulto({super.key, required this.nav});
  final StatefulNavigationShell nav;

  @override
  Widget build(BuildContext context) {
    final veCuentas = sesion.curso?.veCuentas ?? false;
    final ramas = [0, 1, 2, if (veCuentas) 3, 4];
    final destinos = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
      const NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Actividades'),
      const NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'Muro'),
      if (veCuentas)
        const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Cuentas'),
      const NavigationDestination(icon: Icon(Icons.menu), label: 'Más'),
    ];
    final actual = ramas.indexOf(nav.currentIndex);
    return Scaffold(
      body: nav,
      bottomNavigationBar: NavigationBar(
        selectedIndex: actual < 0 ? 0 : actual,
        onDestinationSelected: (i) => nav.goBranch(ramas[i], initialLocation: ramas[i] == nav.currentIndex),
        destinations: destinos,
      ),
    );
  }
}

/// Barra del alumno: Inicio · Tareas · Calendario · Horario (RN-CU04: sin plata, informes ni comunicados).
class MarcoAlumno extends StatelessWidget {
  const MarcoAlumno({super.key, required this.nav});
  final StatefulNavigationShell nav;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: nav,
        bottomNavigationBar: NavigationBar(
          selectedIndex: nav.currentIndex,
          onDestinationSelected: (i) => nav.goBranch(i, initialLocation: i == nav.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
            NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Tareas'),
            NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendario'),
            NavigationDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule), label: 'Horario'),
          ],
        ),
      );
}

/// Selector de curso sencillo para quien está en varios cursos (R-CU41).
Future<void> elegirCurso(BuildContext context) async {
  final id = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.all(16), child: Text('Elige el curso', style: T.title)),
        for (final cu in sesion.cursos)
          ListTile(
            leading: CircleAvatar(backgroundColor: C.lila, child: Text(cu.nombre.characters.first, style: T.heading)),
            title: Text(cu.esPadre && cu.hijo != null ? '${cu.hijoNombre} · ${cu.nombre}' : cu.nombre, style: T.heading),
            subtitle: Text('${cu.colegio} · ${etiquetaRol(cu)}', style: T.caption),
            trailing: cu.id == sesion.curso?.id ? const Icon(Icons.check, color: C.lilaStrong) : null,
            onTap: () => Navigator.pop(c, cu.id),
          ),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Sumar otro curso'),
          onTap: () {
            Navigator.pop(c);
            context.push('/elegir');
          },
        ),
      ]),
    ),
  );
  if (id != null) sesion.elegirCurso(id);
}

String etiquetaRol(CursoMio c) => [
      switch (c.rol) { 'asesor' => 'Asesor', 'profesor' => 'Profesor', 'alumno' => 'Alumno', _ => c.esDelegado ? 'Padre delegado' : 'Padre' },
      if (c.esTesorero) 'Tesorero',
    ].join(' · ');
