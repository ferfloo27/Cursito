import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

const _diasSemana = {1: 'Lunes', 2: 'Martes', 3: 'Miércoles', 4: 'Jueves', 5: 'Viernes'};

/// Calendario del mes (R-CU27): tareas y eventos del curso, por día.
class CalendarioCurso extends StatefulWidget {
  const CalendarioCurso({super.key, this.enPestana = true});
  final bool enPestana;
  @override
  State<CalendarioCurso> createState() => _CalendarioCursoState();
}

class _CalendarioCursoState extends State<CalendarioCurso> {
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  VoidCallback? _refrescar;

  CursoMio get _c => sesion.curso!;

  Future<List<Map<String, dynamic>>> _cargar() async {
    final ini = DateTime(_mes.year, _mes.month).toUtc();
    final fin = DateTime(_mes.year, _mes.month + 1).toUtc();
    final f = await supa
        .from('actividades')
        .select('id, tipo, titulo, fecha, lugar, cancelada_en')
        .eq('curso_id', _c.id)
        .gte('fecha', ini.toIso8601String())
        .lt('fecha', fin.toIso8601String())
        .order('fecha', ascending: true);
    return [for (final a in f as List) Map<String, dynamic>.from(a as Map)];
  }

  void _cambiarMes(int delta) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + delta));
    _refrescar?.call();
  }

  String _ruta(String id) => sesion.esAlumno ? '/a/actividad/$id' : '/actividad/$id';

  @override
  Widget build(BuildContext context) {
    return Cargador<List<Map<String, dynamic>>>(
      cargar: _cargar,
      construir: (context, actividades, recargar) {
        _refrescar = recargar;
        // Agrupa por día.
        final porDia = <DateTime, List<Map<String, dynamic>>>{};
        for (final a in actividades) {
          final f = DateTime.parse(a['fecha'] as String).toLocal();
          porDia.putIfAbsent(DateTime(f.year, f.month, f.day), () => []).add(a);
        }
        final dias = porDia.keys.toList()..sort();
        return Pantalla(
          titulo: 'Calendario',
          atras: !widget.enPestana,
          children: [
            Row(children: [
              IconButton(onPressed: () => _cambiarMes(-1), icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Text(
                  _titulo(_mes),
                  style: T.heading,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(onPressed: () => _cambiarMes(1), icon: const Icon(Icons.chevron_right)),
            ]),
            const SizedBox(height: 8),
            if (dias.isEmpty) const Vacio('No hay tareas ni eventos este mes.', icono: Icons.event_outlined),
            for (final dia in dias) ...[
              Seccion(fechaLarga(dia)),
              for (final a in porDia[dia]!)
                Tarjeta(
                  onTap: () => context.push(_ruta(a['id'] as String)),
                  child: Row(children: [
                    Icon(a['tipo'] == 'evento' ? Icons.celebration_outlined : Icons.assignment_outlined,
                        color: C.lilaStrong),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a['titulo'] as String, style: T.heading),
                        const SizedBox(height: 2),
                        Text(
                          [
                            hora(DateTime.parse(a['fecha'] as String)),
                            if (a['lugar'] != null) a['lugar'],
                            if (a['cancelada_en'] != null) 'cancelada',
                          ].join(' · '),
                          style: T.caption,
                        ),
                      ]),
                    ),
                  ]),
                ),
            ],
          ],
        );
      },
    );
  }

  String _titulo(DateTime m) {
    final t = fechaLarga(DateTime(m.year, m.month, 1)); // «Sábado 1 de noviembre»
    final partes = t.split(' de ');
    return partes.length >= 2 ? '${partes[1][0].toUpperCase()}${partes[1].substring(1)} ${m.year}' : t;
  }
}

/// Horario semanal (R-CU29). Lo ven padres, alumno y docentes. Los profesores tienen su propio apartado.
class HorarioCurso extends StatelessWidget {
  const HorarioCurso({super.key, this.enPestana = true});
  final bool enPestana;

  CursoMio get _c => sesion.curso!;

  Future<List<Map<String, dynamic>>> _cargar() async {
    final b = await supa
        .from('horario_bloques')
        .select('dia, hora_inicio, hora_fin, materia:materias(nombre)')
        .eq('curso_id', _c.id)
        .order('dia')
        .order('hora_inicio');
    return [for (final x in b as List) Map<String, dynamic>.from(x as Map)];
  }

  @override
  Widget build(BuildContext context) {
    return Cargador<List<Map<String, dynamic>>>(
      cargar: _cargar,
      construir: (context, bloques, _) => Pantalla(
        titulo: 'Horario',
        atras: !enPestana,
        children: [
          Titulo('Horario de ${_c.nombre}', sub: 'Materias por día y hora.'),
          if (bloques.isEmpty)
            const Vacio('Todavía no se cargó el horario.', icono: Icons.schedule_outlined)
          else
            _cuadricula(bloques),
        ],
      ),
    );
  }

  static const _colores = [
    (C.lila, C.ink),
    (C.cielo, C.cieloInk),
    (C.menta, C.mentaInk),
    (C.durazno, C.duraznoInk),
    (C.rosa, C.rosaInk),
  ];

  /// Cuadrícula semanal: una fila por franja horaria y una columna por día (lunes a viernes).
  /// Cada materia conserva su color en toda la semana.
  Widget _cuadricula(List<Map<String, dynamic>> bloques) {
    final franjas = <String>{for (final b in bloques) '${_hora(b['hora_inicio'])}|${_hora(b['hora_fin'])}'}.toList()
      ..sort();
    final materias = <String>{for (final b in bloques) _materia(b)}.toList()..sort();
    final celdas = <String, String>{
      for (final b in bloques) '${b['dia']}|${_hora(b['hora_inicio'])}|${_hora(b['hora_fin'])}': _materia(b),
    };

    Widget encabezado(String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(t, style: T.label, textAlign: TextAlign.center),
        );

    Widget celda(String? materia) {
      if (materia == null) return const SizedBox(height: 56);
      final (fondo, tinta) = _colores[materias.indexOf(materia) % _colores.length];
      return Container(
        height: 56,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(R.sm)),
        child: Text(
          materia,
          style: T.caption.copyWith(color: tinta, fontWeight: FontWeight.w600, fontSize: 11),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        const anchoHora = 52.0;
        final anchoDia = ((c.maxWidth - anchoHora) / 5).clamp(64.0, 200.0);
        final tabla = Table(
          columnWidths: {
            0: const FixedColumnWidth(anchoHora),
            for (var i = 1; i <= 5; i++) i: FixedColumnWidth(anchoDia),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(children: [
              const SizedBox.shrink(),
              for (final dia in _diasSemana.values) encabezado(dia.substring(0, 3)),
            ]),
            for (final f in franjas)
              TableRow(children: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(f.replaceFirst('|', '\n'), style: T.caption.copyWith(fontSize: 10)),
                ),
                for (final dia in _diasSemana.keys) celda(celdas['$dia|$f']),
              ]),
          ],
        );
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: tabla);
      },
    );
  }

  static String _materia(Map<String, dynamic> b) => ((b['materia'] as Map?)?['nombre'] as String?) ?? '';

  static String _hora(dynamic t) => (t as String).substring(0, 5);
}
