import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';
import 'marco.dart';

/// Cabecera de color con el colegio, el selector de curso (R-CU41) y el saludo.
class CabeceraCurso extends StatelessWidget {
  const CabeceraCurso({super.key, required this.saludo, this.resumen});
  final String saludo;
  final String? resumen;
  @override
  Widget build(BuildContext context) {
    final c = sesion.curso!;
    final chip = c.esPadre && c.hijo != null ? '${c.hijoNombre} · ${c.nombre}' : c.nombre;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(color: C.lila, borderRadius: BorderRadius.circular(R.lg)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c.colegio.toUpperCase(), style: T.label.copyWith(color: C.ink)),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => elegirCurso(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: C.surfaceRaised, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(chip, style: T.label.copyWith(color: C.ink)),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 18),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Text(saludo, style: T.display),
        if (resumen != null) ...[const SizedBox(height: 4), Text(resumen!, style: T.body)],
      ]),
    );
  }
}

String _primerNombre(String? n) => (n ?? '').replaceFirst('Prof. ', '').split(' ').first;

/// 13 · Inicio del curso (padre, profesor, tesorero).
class InicioCurso extends StatelessWidget {
  const InicioCurso({super.key});

  Future<_DatosInicio> _cargar(CursoMio c) async {
    final perfil = await supa.from('perfiles').select('nombre').eq('id', sesion.usuario!.id).single();
    final acts = await supa
        .from('actividades')
        .select('id, tipo, titulo, fecha, lugar, materia:materias(nombre)')
        .eq('curso_id', c.id)
        .isFilter('cancelada_en', null)
        .gte('fecha', DateTime.now().toUtc().toIso8601String())
        .order('fecha', ascending: true)
        .limit(3);
    Map<String, dynamic>? rend;
    if (c.veCuentas) rend = Map<String, dynamic>.from(await supa.rpc('rendicion', params: {'p_curso': c.id}) as Map);
    List<Map<String, dynamic>> cuotas = [];
    if (c.esPadre) {
      final f = await supa.rpc('mis_cuotas', params: {'p_curso': c.id}) as List;
      cuotas = f.map((e) => Map<String, dynamic>.from(e as Map)).where((m) => m['anulada'] != true && aNum(m['pendiente']) > 0).toList();
    }
    return _DatosInicio(perfil['nombre'] as String, List<Map<String, dynamic>>.from(acts), rend, cuotas);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: sesion,
        builder: (context, _) {
          final c = sesion.curso;
          if (c == null) return const Scaffold(body: Cargando());
          return Scaffold(
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: sesion.recargarCursos,
                child: Cargador<_DatosInicio>(
                  key: ValueKey('${c.id}-${sesion.cursos.length}'),
                  cargar: () => _cargar(c),
                  construir: (context, d, _) {
                    final resumen = c.esPadre
                        ? (d.cuotas.isEmpty ? 'Estás al día con las cuotas.' : '${d.cuotas.length} cuota${d.cuotas.length == 1 ? '' : 's'} pendiente${d.cuotas.length == 1 ? '' : 's'}')
                        : etiquetaRol(c);
                    return ListView(padding: const EdgeInsets.all(16), children: [
                      CabeceraCurso(saludo: 'Hola, ${_primerNombre(d.nombre)}', resumen: resumen),
                      if (d.cuotas.isNotEmpty) ...[
                        const Seccion('Para hoy'),
                        for (final q in d.cuotas)
                          Tarjeta(
                            color: C.menta,
                            child: Row(children: [
                              const Icon(Icons.payments_outlined, color: C.mentaInk),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Cuota: ${q['concepto']}', style: T.heading),
                                Text(aNum(q['pagado']) > 0
                                    ? 'Pagado ${bs(q['pagado'])} de ${bs(q['monto'])} · faltan ${bs(q['pendiente'])}'
                                    : '${bs(q['pendiente'])} · vence el ${fechaCorta(DateTime.parse(q['vence_el'] as String))}',
                                    style: T.caption.copyWith(color: C.mentaInk)),
                              ])),
                            ]),
                          ),
                      ],
                      const Seccion('Próximas actividades'),
                      if (d.actividades.isEmpty) const Vacio('No hay actividades próximas.', icono: Icons.event_available_outlined),
                      for (final a in d.actividades)
                        Tarjeta(
                          color: a['tipo'] == 'evento' ? C.durazno : C.cielo,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Chip2(a['tipo'] == 'evento' ? 'Evento' : 'Tarea · ${(a['materia'] as Map?)?['nombre'] ?? ''}',
                                fondo: C.surfaceRaised, tinta: a['tipo'] == 'evento' ? C.duraznoInk : C.cieloInk),
                            const SizedBox(height: 8),
                            Text(a['titulo'] as String, style: T.heading),
                            Text(fechaHora(DateTime.parse(a['fecha'] as String)), style: T.caption.copyWith(color: C.ink)),
                          ]),
                        ),
                      if (d.rendicion != null) ...[
                        const Seccion('Cuenta del curso'),
                        Tarjeta(
                          child: Row(children: [
                            _cifra('Recaudado', d.rendicion!['recaudado']),
                            _cifra('Gastado', d.rendicion!['gastado']),
                            _cifra('Saldo', d.rendicion!['saldo'], fuerte: true),
                          ]),
                        ),
                      ],
                    ]);
                  },
                ),
              ),
            ),
          );
        },
      );

  Widget _cifra(String t, dynamic v, {bool fuerte = false}) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.toUpperCase(), style: T.label),
          Text(bs(aNum(v)), style: (fuerte ? T.heading.copyWith(color: C.mentaInk) : T.heading)
              .copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      );
}

class _DatosInicio {
  _DatosInicio(this.nombre, this.actividades, this.rendicion, this.cuotas);
  final String nombre;
  final List<Map<String, dynamic>> actividades;
  final Map<String, dynamic>? rendicion;
  final List<Map<String, dynamic>> cuotas;
}

/// 14 · Inicio del alumno: sus tareas y las clases de hoy (sin plata, informes ni comunicados).
class InicioAlumno extends StatelessWidget {
  const InicioAlumno({super.key});

  Future<(String, List<Map<String, dynamic>>, List<Map<String, dynamic>>)> _cargar(CursoMio c) async {
    final perfil = await supa.from('perfiles').select('nombre').eq('id', sesion.usuario!.id).single();
    final tareas = await supa
        .from('actividades')
        .select('id, tipo, titulo, fecha, materia:materias(nombre)')
        .eq('curso_id', c.id)
        .isFilter('cancelada_en', null)
        .gte('fecha', DateTime.now().toUtc().toIso8601String())
        .order('fecha', ascending: true)
        .limit(5);
    final dia = DateTime.now().weekday;
    final clases = dia > 5
        ? <dynamic>[]
        : await supa
            .from('horario_bloques')
            .select('hora_inicio, hora_fin, materia:materias(nombre)')
            .eq('curso_id', c.id)
            .eq('dia', dia)
            .order('hora_inicio', ascending: true);
    return (perfil['nombre'] as String, List<Map<String, dynamic>>.from(tareas), List<Map<String, dynamic>>.from(clases));
  }

  @override
  Widget build(BuildContext context) {
    final c = sesion.curso;
    if (c == null) return const Scaffold(body: Cargando());
    return Scaffold(
      body: SafeArea(
        child: Cargador(
          cargar: () => _cargar(c),
          construir: (context, d, _) => ListView(padding: const EdgeInsets.all(16), children: [
            CabeceraCurso(saludo: 'Hola, ${_primerNombre(d.$1)}', resumen: d.$2.length == 1 ? '1 actividad próxima' : '${d.$2.length} actividades próximas'),
            const Seccion('Mis tareas y eventos'),
            if (d.$2.isEmpty) const Vacio('No tienes tareas pendientes.', icono: Icons.check_circle_outline),
            for (final a in d.$2)
              Tarjeta(
                color: C.cielo,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a['tipo'] == 'evento' ? 'EVENTO' : '${(a['materia'] as Map?)?['nombre'] ?? ''}'.toUpperCase(),
                      style: T.label.copyWith(color: C.cieloInk)),
                  Text(a['titulo'] as String, style: T.heading),
                  Text(fechaHora(DateTime.parse(a['fecha'] as String)), style: T.caption.copyWith(color: C.ink)),
                ]),
              ),
            const Seccion('Hoy'),
            if (d.$3.isEmpty) const Vacio('Hoy no hay clases.', icono: Icons.weekend_outlined),
            for (final b in d.$3)
              Tarjeta(
                padding: 12,
                child: Row(children: [
                  SizedBox(
                      width: 64,
                      child: Text('${b['hora_inicio']}'.substring(0, 5), style: T.heading.copyWith(color: C.lilaStrong))),
                  Expanded(child: Text('${(b['materia'] as Map?)?['nombre']}', style: T.body)),
                ]),
              ),
            const SizedBox(height: 24),
            const BotonCerrarSesion(alumno: true),
          ]),
        ),
      ),
    );
  }
}

/// Menú «Más» (sin mockup): sólo las entradas del rol.
class Mas extends StatelessWidget {
  const Mas({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: sesion,
        builder: (context, _) {
          final c = sesion.curso;
          if (c == null) return const Scaffold(body: Cargando());
          Widget item(IconData i, String t, String ruta, {String? sub}) => Tarjeta(
                padding: 4,
                onTap: () => context.push(ruta),
                child: ListTile(
                    leading: Icon(i, color: C.lilaStrong),
                    title: Text(t, style: T.heading),
                    subtitle: sub == null ? null : Text(sub, style: T.caption),
                    trailing: const Icon(Icons.chevron_right)),
              );
          return Pantalla(titulo: 'Más', atras: false, children: [
            Text('${c.nombre} · ${c.colegio}', style: T.title),
            Text(etiquetaRol(c), style: T.caption),
            const SizedBox(height: 16),
            if (c.esPadre) item(Icons.child_care, 'Mis hijos', '/mis-hijos', sub: 'Vincular con QR o quitar el acceso'),
            if (c.gestiona) ...[
              item(Icons.groups_outlined, 'Nómina del curso', '/nomina', sub: 'Cargar, corregir y quitar alumnos'),
              item(Icons.manage_accounts_outlined, 'Miembros y roles', '/miembros', sub: 'Tesorero, docentes y códigos'),
              item(Icons.qr_code_2, 'Códigos del curso', '/curso-creado', sub: 'Compartir con padres y profesores'),
            ],
            Tarjeta(
              padding: 4,
              onTap: () => elegirCurso(context),
              child: const ListTile(
                  leading: Icon(Icons.swap_horiz, color: C.lilaStrong),
                  title: Text('Cambiar de curso o sumar otro'),
                  trailing: Icon(Icons.chevron_right)),
            ),
            const SizedBox(height: 8),
            const BotonCerrarSesion(),
          ]);
        },
      );
}

/// Cerrar sesión (Q-CU-ACC-06): para cambiar de cuenta en el mismo teléfono durante la demo.
class BotonCerrarSesion extends StatelessWidget {
  const BotonCerrarSesion({super.key, this.alumno = false});
  final bool alumno;
  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: () async {
          final ok = await confirmar(
            context,
            'Cerrar sesión',
            alumno
                ? 'Para volver a entrar en este celular necesitarás un QR nuevo de tu mamá o papá.'
                : '¿Salir de tu cuenta en este celular?',
            si: 'Cerrar sesión',
          );
          if (ok) await sesion.cerrarSesion();
        },
        style: TextButton.styleFrom(foregroundColor: C.rosaInk),
        icon: const Icon(Icons.logout),
        label: const Text('Cerrar sesión'),
      );
}
