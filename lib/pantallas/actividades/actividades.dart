import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errores.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

const selectActividad = 'id, curso_id, tipo, titulo, descripcion, fecha, lugar, pide_asistencia, pide_autorizacion, '
    'cancelada_en, creado_por, materia_id, materia:materias(nombre), autor:perfiles!actividades_creado_por_fkey(nombre)';

String rutaActividad(String id) => sesion.esAlumno ? '/a/actividad/$id' : '/actividad/$id';

/// Chip de tipo: tarea (cielo, comunicación) o evento (durazno, pide acción).
Widget chipTipo(Map<String, dynamic> a) {
  final evento = a['tipo'] == 'evento';
  final materia = (a['materia'] as Map?)?['nombre'];
  return Chip2(evento ? 'Evento' : 'Tarea${materia == null ? '' : ' · $materia'}',
      fondo: evento ? C.durazno : C.cielo, tinta: evento ? C.duraznoInk : C.cieloInk);
}

/// 15 · Lista de actividades (R-CU25): filtros Todas · Tareas · Eventos.
class ListaActividades extends StatefulWidget {
  const ListaActividades({super.key});
  @override
  State<ListaActividades> createState() => _ListaActividadesState();
}

class _ListaActividadesState extends State<ListaActividades> {
  String _filtro = 'todas';
  int _version = 0;

  Future<(List<Map<String, dynamic>>, Set<String>)> _cargar(CursoMio c) async {
    final f = await supa.from('actividades').select(selectActividad).eq('curso_id', c.id).order('fecha', ascending: true);
    var conCuota = <String>{};
    if (!c.esAlumno) {
      final q = await supa.from('cuotas').select('actividad_id').eq('curso_id', c.id).isFilter('anulada_en', null);
      conCuota = {for (final x in q) if (x['actividad_id'] != null) x['actividad_id'] as String};
    }
    return (List<Map<String, dynamic>>.from(f), conCuota);
  }

  bool _puedePublicar(CursoMio c) => c.esDocente;

  @override
  Widget build(BuildContext context) {
    final c = sesion.curso;
    if (c == null) return const Scaffold(body: Cargando());
    return Scaffold(
      appBar: AppBar(title: Text(c.esAlumno ? 'Tareas y eventos' : 'Actividades'), automaticallyImplyLeading: false),
      floatingActionButton: _puedePublicar(c)
          ? FloatingActionButton.extended(
              onPressed: () async {
                final creada = await context.push<bool>('/actividades/nueva');
                if (creada == true) setState(() => _version++);
              },
              icon: const Icon(Icons.add),
              label: const Text('Nueva actividad'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _version++),
        child: Cargador<(List<Map<String, dynamic>>, Set<String>)>(
          key: ValueKey('${c.id}-$_version'),
          cargar: () => _cargar(c),
          construir: (context, d, _) {
            final ahora = DateTime.now();
            final todas = d.$1.where((a) => _filtro == 'todas' || a['tipo'] == (_filtro == 'tareas' ? 'tarea' : 'evento')).toList();
            final proximas = todas.where((a) => a['cancelada_en'] == null && DateTime.parse(a['fecha'] as String).isAfter(ahora)).toList();
            final pasadas = todas.where((a) => !proximas.contains(a)).toList().reversed.toList();
            return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
              Wrap(spacing: 8, children: [
                for (final f in const [('todas', 'Todas'), ('tareas', 'Tareas'), ('eventos', 'Eventos')])
                  ChoiceChip(label: Text(f.$2), selected: _filtro == f.$1, onSelected: (_) => setState(() => _filtro = f.$1)),
              ]),
              const SizedBox(height: 12),
              if (todas.isEmpty)
                Vacio(_puedePublicar(c) ? 'Todavía no hay actividades. Publica la primera.' : 'Todavía no hay actividades.',
                    icono: Icons.event_note_outlined),
              for (final a in proximas) _tarjeta(context, a, d.$2.contains(a['id'])),
              if (pasadas.isNotEmpty) ...[
                Padding(padding: const EdgeInsets.only(top: 12, bottom: 8), child: Text('PASADAS O CANCELADAS', style: T.label)),
                for (final a in pasadas) Opacity(opacity: 0.6, child: _tarjeta(context, a, d.$2.contains(a['id']))),
              ],
            ]);
          },
        ),
      ),
    );
  }

  Widget _tarjeta(BuildContext context, Map<String, dynamic> a, bool conCuota) {
    final fecha = DateTime.parse(a['fecha'] as String);
    final cancelada = a['cancelada_en'] != null;
    return Tarjeta(
      onTap: () async {
        await context.push(rutaActividad(a['id'] as String));
        if (mounted) setState(() => _version++);
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          chipTipo(a),
          if (conCuota) const Chip2('Con cuota', fondo: C.menta, tinta: C.mentaInk),
          if (cancelada) const Chip2('Cancelada', fondo: C.rosa, tinta: C.rosaInk),
        ]),
        const SizedBox(height: 8),
        Text(a['titulo'] as String, style: T.heading.copyWith(decoration: cancelada ? TextDecoration.lineThrough : null)),
        const SizedBox(height: 2),
        Text(
            [
              fechaHora(fecha),
              if (a['tipo'] == 'evento' && a['lugar'] != null) a['lugar'] as String,
              if (a['tipo'] == 'tarea') (a['autor'] as Map?)?['nombre'] ?? '',
            ].join(' · '),
            style: T.caption),
      ]),
    );
  }
}

/// 17 · Nueva actividad (R-CU25, RN-CU20) y edición (R-CU47: sólo fecha, lugar y descripción).
class NuevaActividad extends StatefulWidget {
  const NuevaActividad({super.key, this.editar});
  final Map<String, dynamic>? editar;
  @override
  State<NuevaActividad> createState() => _NuevaActividadState();
}

class _NuevaActividadState extends State<NuevaActividad> {
  final _form = GlobalKey<FormState>();
  late String _tipo = widget.editar?['tipo'] as String? ?? (sesion.curso!.esAsesor ? 'evento' : 'tarea');
  String? _materia;
  final _titulo = TextEditingController(), _lugar = TextEditingController(), _descripcion = TextEditingController();
  DateTime? _fecha;
  TimeOfDay _hora = const TimeOfDay(hour: 10, minute: 0);
  bool _asistencia = true, _autorizacion = false, _enviando = false;
  String? _error;
  late final Future<List<Map<String, dynamic>>> _materias = _cargarMaterias();

  bool get _editando => widget.editar != null;
  CursoMio get _c => sesion.curso!;

  @override
  void initState() {
    super.initState();
    final e = widget.editar;
    if (e != null) {
      final f = DateTime.parse(e['fecha'] as String).toLocal();
      _fecha = DateTime(f.year, f.month, f.day);
      _hora = TimeOfDay(hour: f.hour, minute: f.minute);
      _titulo.text = e['titulo'] as String;
      _lugar.text = e['lugar'] as String? ?? '';
      _descripcion.text = e['descripcion'] as String? ?? '';
    }
  }

  /// El asesor elige cualquier materia; el profesor, sólo la suya (RN-CU20).
  Future<List<Map<String, dynamic>>> _cargarMaterias() async {
    if (_c.esAsesor) {
      final m = await supa.from('materias').select('id, nombre').eq('curso_id', _c.id).order('nombre', ascending: true);
      return List<Map<String, dynamic>>.from(m);
    }
    final m = await supa
        .from('profesores_curso')
        .select('materia:materias!inner(id, nombre, curso_id), miembro:miembros_curso!inner(usuario_id)')
        .eq('miembro.usuario_id', sesion.usuario!.id)
        .eq('materia.curso_id', _c.id);
    final lista = [for (final x in m) Map<String, dynamic>.from(x['materia'] as Map)];
    if (lista.length == 1) _materia = lista.first['id'] as String;
    return lista;
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final d = await showDatePicker(
        context: context, initialDate: _fecha ?? hoy, firstDate: DateTime(hoy.year - 1), lastDate: DateTime(hoy.year + 2));
    if (d != null) setState(() => _fecha = d);
  }

  Future<void> _elegirHora() async {
    final h = await showTimePicker(context: context, initialTime: _hora);
    if (h != null) setState(() => _hora = h);
  }

  Future<void> _publicar() async {
    if (!_form.currentState!.validate()) return;
    if (_fecha == null) return setState(() => _error = 'Elige la fecha.');
    if (_tipo == 'tarea' && _materia == null && !_editando) return setState(() => _error = 'Elige la materia.');
    final fecha = DateTime(_fecha!.year, _fecha!.month, _fecha!.day, _hora.hour, _hora.minute).toUtc().toIso8601String();
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final desc = _descripcion.text.trim().isEmpty ? null : _descripcion.text.trim();
      final lugar = _lugar.text.trim().isEmpty ? null : _lugar.text.trim();
      if (_editando) {
        await supa.from('actividades').update({'fecha': fecha, 'lugar': lugar, 'descripcion': desc}).eq('id', widget.editar!['id']);
      } else {
        await supa.from('actividades').insert({
          'curso_id': _c.id,
          'tipo': _tipo,
          'titulo': _titulo.text.trim(),
          'descripcion': desc,
          'fecha': fecha,
          'lugar': _tipo == 'evento' ? lugar : null,
          'materia_id': _tipo == 'tarea' ? _materia : null,
          'pide_asistencia': _tipo == 'evento' && _asistencia,
          'pide_autorizacion': _tipo == 'evento' && _autorizacion,
        });
      }
      if (mounted) context.pop(true);
    } catch (e) {
      setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final evento = _tipo == 'evento';
    return Form(
      key: _form,
      child: Pantalla(
        titulo: _editando ? 'Editar actividad' : 'Nueva actividad',
        abajo: BotonPrincipal(_editando ? 'Guardar cambios' : 'Publicar actividad', onPressed: _publicar, cargando: _enviando),
        children: [
          Titulo(_editando ? _titulo.text : 'Nueva actividad',
              sub: _editando ? 'Puedes cambiar fecha, lugar y descripción. Cada cambio avisa en el muro.' : null),
          if (!_editando) ...[
            const Etiqueta('Tipo'),
            SegmentedButton<String>(
              segments: [
                const ButtonSegment(value: 'tarea', label: Text('Tarea')),
                ButtonSegment(value: 'evento', label: const Text('Evento'), enabled: _c.esAsesor),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
            if (!_c.esAsesor)
              Padding(
                  padding: const EdgeInsets.only(top: 6), child: Text('Los eventos del curso los crea solo el asesor.', style: T.caption)),
            if (!evento) ...[
              const Etiqueta('Materia'),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _materias,
                builder: (context, s) => !s.hasData
                    ? const LinearProgressIndicator()
                    : Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final m in s.data!)
                          ChoiceChip(
                              label: Text(m['nombre'] as String),
                              selected: _materia == m['id'],
                              onSelected: (_) => setState(() => _materia = m['id'] as String)),
                      ]),
              ),
            ],
            Campo(
                etiqueta: 'Título',
                controller: _titulo,
                hint: evento ? 'Día de la Madre' : 'Leer el cuento',
                validar: (v) => (v ?? '').trim().isEmpty ? 'Escribe el título' : null),
          ],
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Etiqueta(evento ? 'Fecha' : 'Entrega'),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: _elegirFecha,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(_fecha == null ? 'Elegir' : fechaCorta(_fecha!)),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Etiqueta('Hora'),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: _elegirHora,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text('${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}'),
                ),
              ]),
            ),
          ]),
          if (evento) Campo(etiqueta: 'Lugar', controller: _lugar, hint: 'Patio del colegio'),
          Campo(etiqueta: 'Descripción', controller: _descripcion, lineas: 3),
          if (evento && !_editando) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Pedir confirmación de asistencia', style: T.body),
              value: _asistencia,
              onChanged: (v) => setState(() => _asistencia = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Pide autorización', style: T.body),
              subtitle: Text('Para paseos: los padres responden «Autorizo», aparte de la asistencia.', style: T.caption),
              value: _autorizacion,
              onChanged: (v) => setState(() => _autorizacion = v),
            ),
            const AvisoCaja('¿Lleva cuota? La crea el tesorero en «Crear cuota» y la liga a este evento después de publicarlo.',
                fondo: C.menta, tinta: C.mentaInk, icono: Icons.payments_outlined),
          ],
          if (_error != null) AvisoCaja(_error!),
        ],
      ),
    );
  }
}
