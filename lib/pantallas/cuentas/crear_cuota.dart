import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

class _Opciones {
  _Opciones(this.alumnos, this.eventos);
  final int alumnos;
  final List<Map<String, dynamic>> eventos;
}

/// Crear cuota (R-CU08, RN-CU16): concepto, monto por alumno, fecha límite y, si aplica, el evento al que se liga.
class CrearCuota extends StatefulWidget {
  const CrearCuota({super.key, this.actividadId});
  final String? actividadId; // viene del detalle de un evento sin cuota
  @override
  State<CrearCuota> createState() => _CrearCuotaState();
}

class _CrearCuotaState extends State<CrearCuota> {
  final _form = GlobalKey<FormState>();
  final _concepto = TextEditingController(), _monto = TextEditingController();
  DateTime? _vence;
  late String? _actividad = widget.actividadId; // null = cuota general del curso
  bool _enviando = false;
  String? _error;
  late final Future<_Opciones> _opciones = _cargarOpciones();

  CursoMio get _c => sesion.curso!;

  @override
  void initState() {
    super.initState();
    _monto.addListener(() => setState(() {}));
  }

  Future<_Opciones> _cargarOpciones() async {
    final al = await supa.from('alumnos').select('id').eq('curso_id', _c.id);
    final ev = await supa
        .from('actividades')
        .select('id, titulo, fecha')
        .eq('curso_id', _c.id)
        .eq('tipo', 'evento')
        .isFilter('cancelada_en', null)
        .order('fecha', ascending: true);
    final cu = await supa.from('cuotas').select('actividad_id').eq('curso_id', _c.id).isFilter('anulada_en', null);
    final ligadas = {for (final q in cu) if (q['actividad_id'] != null) q['actividad_id'] as String};
    return _Opciones(
      (al as List).length,
      [for (final e in ev as List) if (!ligadas.contains(e['id'])) Map<String, dynamic>.from(e as Map)],
    );
  }

  num? get _montoNum => num.tryParse(_monto.text.trim().replaceAll(',', '.'));

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final d = await showDatePicker(
        context: context, initialDate: _vence ?? hoy, firstDate: DateTime(hoy.year - 1), lastDate: DateTime(hoy.year + 2));
    if (d != null) setState(() => _vence = d);
  }

  Future<void> _crear() async {
    if (!_form.currentState!.validate()) return;
    if (_vence == null) return setState(() => _error = 'Elige la fecha límite.');
    setState(() {
      _enviando = true;
      _error = null;
    });
    final ok = await intentar(
        context,
        () => supa.from('cuotas').insert({
              'curso_id': _c.id,
              'actividad_id': _actividad,
              'concepto': _concepto.text.trim(),
              'monto_por_alumno': _montoNum,
              'vence_el': DateFormat('yyyy-MM-dd').format(_vence!),
            }));
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Pantalla(
        titulo: 'Crear cuota',
        abajo: BotonPrincipal('Crear y avisar a las familias', onPressed: _crear, cargando: _enviando),
        children: [
          const Titulo('Nueva cuota', sub: 'Se crea una deuda por cada alumno de la nómina y se avisa en el muro.'),
          Campo(
            etiqueta: 'Concepto',
            controller: _concepto,
            hint: 'Cuota de paseo',
            validar: (v) => (v ?? '').trim().isEmpty ? 'Escribe el concepto' : null,
          ),
          Campo(
            etiqueta: 'Monto por alumno (Bs)',
            controller: _monto,
            teclado: const TextInputType.numberWithOptions(decimal: true),
            hint: '60',
            validar: (v) {
              final n = num.tryParse((v ?? '').trim().replaceAll(',', '.'));
              return n == null || n <= 0 ? 'Escribe un monto mayor que cero.' : null;
            },
          ),
          const Etiqueta('Fecha límite'),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _elegirFecha,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(_vence == null ? 'Elegir' : fechaCorta(_vence!)),
          ),
          FutureBuilder<_Opciones>(
            future: _opciones,
            builder: (context, s) {
              if (!s.hasData) {
                if (s.hasError) return AvisoCaja(s.error.toString());
                return const Cargando();
              }
              final o = s.data!;
              final m = _montoNum ?? 0;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Etiqueta('Ligada a'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoiceChip(
                    label: const Text('General del curso'),
                    selected: _actividad == null,
                    onSelected: (_) => setState(() => _actividad = null),
                  ),
                  for (final e in o.eventos)
                    ChoiceChip(
                      label: Text(e['titulo'] as String),
                      selected: _actividad == e['id'],
                      onSelected: (_) => setState(() => _actividad = e['id'] as String),
                    ),
                ]),
                const SizedBox(height: 16),
                Tarjeta(
                  color: C.menta,
                  child: Text(
                    'Se espera recaudar ${bs(m * o.alumnos)} (${bs(m)} × ${o.alumnos} alumnos)',
                    style: T.body.copyWith(color: C.mentaInk),
                  ),
                ),
              ]);
            },
          ),
          if (_error != null) AvisoCaja(_error!),
        ],
      ),
    );
  }
}
