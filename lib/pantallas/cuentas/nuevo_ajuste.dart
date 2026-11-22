import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

class _Opciones {
  _Opciones(this.pagos, this.gastos);
  final List<Map<String, dynamic>> pagos, gastos;
}

/// «Nuevo ajuste» (RN-CU05): corrige un pago confirmado o un gasto aprobado. Nunca borra ni edita el libro.
class NuevoAjuste extends StatefulWidget {
  const NuevoAjuste({super.key, this.gastoId});
  final String? gastoId; // viene desde el detalle de un gasto
  @override
  State<NuevoAjuste> createState() => _NuevoAjusteState();
}

class _NuevoAjusteState extends State<NuevoAjuste> {
  final _form = GlobalKey<FormState>();
  final _monto = TextEditingController(), _motivo = TextEditingController();
  late bool _sobreGasto = widget.gastoId != null;
  String? _pagoId, _gastoId;
  bool _enviando = false;
  String? _error;
  late final Future<_Opciones> _opciones = _cargarOpciones();

  CursoMio get _c => sesion.curso!;

  @override
  void initState() {
    super.initState();
    _gastoId = widget.gastoId;
  }

  Future<_Opciones> _cargarOpciones() async {
    final p = await supa
        .from('pagos')
        .select('id, monto, deuda:deudas(cuota:cuotas(concepto))')
        .eq('curso_id', _c.id)
        .eq('estado', 'confirmado')
        .order('creado_en', ascending: false);
    final g = await supa
        .from('gastos')
        .select('id, concepto, monto')
        .eq('curso_id', _c.id)
        .eq('estado', 'aprobado')
        .order('creado_en', ascending: false);
    return _Opciones(
      [for (final x in p as List) Map<String, dynamic>.from(x as Map)],
      [for (final x in g as List) Map<String, dynamic>.from(x as Map)],
    );
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final destino = _sobreGasto ? _gastoId : _pagoId;
    if (destino == null) return setState(() => _error = _sobreGasto ? 'Elige el gasto.' : 'Elige el pago.');
    setState(() {
      _enviando = true;
      _error = null;
    });
    final ok = await intentar(
        context,
        () => supa.from('ajustes').insert({
              'curso_id': _c.id,
              if (_sobreGasto) 'gasto_id': destino else 'pago_id': destino,
              'monto': num.parse(_monto.text.trim().replaceAll(',', '.')),
              'motivo': _motivo.text.trim(),
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
        titulo: 'Nuevo ajuste',
        abajo: BotonPrincipal('Registrar ajuste', onPressed: _guardar, cargando: _enviando),
        children: [
          const Titulo('Nuevo ajuste',
              sub: 'El libro no se edita: el ajuste suma o resta sobre el movimiento y queda a la vista de todos.'),
          FutureBuilder<_Opciones>(
            future: _opciones,
            builder: (context, s) {
              if (!s.hasData) {
                if (s.hasError) return AvisoCaja(s.error.toString());
                return const Cargando();
              }
              final o = s.data!;
              final items = _sobreGasto ? o.gastos : o.pagos;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Etiqueta('Corrige'),
                if (widget.gastoId == null)
                  Wrap(spacing: 8, children: [
                    ChoiceChip(
                      label: const Text('Pago confirmado'),
                      selected: !_sobreGasto,
                      onSelected: (_) => setState(() => _sobreGasto = false),
                    ),
                    ChoiceChip(
                      label: const Text('Gasto aprobado'),
                      selected: _sobreGasto,
                      onSelected: (_) => setState(() => _sobreGasto = true),
                    ),
                  ]),
                const SizedBox(height: 8),
                if (_sobreGasto && widget.gastoId != null)
                  Text(
                      o.gastos.where((g) => g['id'] == _gastoId).map((g) => g['concepto'] as String).firstOrNull ??
                          'Gasto aprobado',
                      style: T.heading)
                else if (items.isEmpty)
                  Vacio(_sobreGasto ? 'No hay gastos aprobados.' : 'No hay pagos confirmados.')
                else
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final it in items)
                      ChoiceChip(
                        label: Text(_sobreGasto
                            ? '${it['concepto']} · ${bs(aNum(it['monto']))}'
                            : '${((it['deuda'] as Map)['cuota'] as Map)['concepto']} · ${bs(aNum(it['monto']))}'),
                        selected: (_sobreGasto ? _gastoId : _pagoId) == it['id'],
                        onSelected: (_) => setState(() {
                          if (_sobreGasto) {
                            _gastoId = it['id'] as String;
                          } else {
                            _pagoId = it['id'] as String;
                          }
                        }),
                      ),
                  ]),
              ]);
            },
          ),
          Campo(
            etiqueta: 'Monto (Bs)',
            controller: _monto,
            teclado: const TextInputType.numberWithOptions(decimal: true, signed: true),
            hint: '-20 para restar, 20 para sumar',
            validar: (v) {
              final n = num.tryParse((v ?? '').trim().replaceAll(',', '.'));
              return n == null || n == 0 ? 'Escribe un monto distinto de cero.' : null;
            },
          ),
          Campo(
            etiqueta: 'Motivo',
            controller: _motivo,
            lineas: 2,
            hint: 'Por qué se corrige',
            validar: (v) => (v ?? '').trim().length < 10 ? 'Explica el motivo con al menos 10 letras.' : null,
          ),
          if (_error != null) AvisoCaja(_error!),
        ],
      ),
    );
  }
}
