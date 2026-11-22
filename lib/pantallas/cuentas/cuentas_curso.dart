import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

const categoriasGasto = {
  'obsequio': 'Obsequio',
  'comida': 'Comida',
  'materiales': 'Materiales',
  'otro': 'Otro',
};

class _Cuentas {
  _Cuentas(this.rendicion, this.gastos, this.ajustes);
  final Map<String, dynamic> rendicion;
  final List<Map<String, dynamic>> gastos, ajustes;
}

/// «Cuentas» del curso (R-CU13, R-CU14, RN-CU03): rendición con sólo números, gastos y ajustes.
/// Padres y asesor la ven (Q-CU-REN-01). El tesorero además registra gastos y ajustes.
class CuentasCurso extends StatelessWidget {
  const CuentasCurso({super.key, this.enPestana = true});
  final bool enPestana;

  CursoMio get _c => sesion.curso!;

  Future<_Cuentas> _cargar() async {
    final r = Map<String, dynamic>.from(await supa.rpc('rendicion', params: {'p_curso': _c.id}) as Map);
    final g = await supa
        .from('gastos')
        .select('id, concepto, categoria, monto, estado')
        .eq('curso_id', _c.id)
        .order('creado_en', ascending: false);
    final aj = await supa
        .from('ajustes')
        .select('id, monto, motivo, creado_en')
        .eq('curso_id', _c.id)
        .order('creado_en', ascending: false);
    return _Cuentas(
      r,
      [for (final x in g as List) Map<String, dynamic>.from(x as Map)],
      [for (final x in aj as List) Map<String, dynamic>.from(x as Map)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Cargador<_Cuentas>(
      cargar: _cargar,
      construir: (context, d, recargar) {
        final r = d.rendicion;
        return Pantalla(
          titulo: 'Cuentas',
          atras: !enPestana,
          children: [
            Titulo('Cuentas del curso', sub: 'Lo que entró, lo que salió y lo que queda.'),
            Tarjeta(
              child: Column(children: [
                _fila('Recaudado', bs(aNum(r['recaudado']))),
                _fila('Gastado', bs(aNum(r['gastado']))),
                _fila('Saldo', bs(aNum(r['saldo'])), negrita: true),
                _fila('En votación', bs(aNum(r['en_votacion']))),
                _fila('Familias que pagaron', '${r['familias_pagaron']} de ${r['familias']}'),
              ]),
            ),
            if (_c.esTesorero) ...[
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () async {
                      if (await context.push<bool>('/gastos/nuevo') == true) recargar();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Registrar gasto'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () async {
                      if (await context.push<bool>('/ajustes/nuevo') == true) recargar();
                    },
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Nuevo ajuste'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Tarjeta(
                color: C.lila,
                onTap: () async {
                  await context.push('/tesorero');
                  recargar();
                },
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet_outlined, color: C.lilaStrong),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Panel del tesorero', style: T.heading)),
                  const Icon(Icons.chevron_right, color: C.lilaStrong),
                ]),
              ),
            ],
            const Seccion('Gastos'),
            if (d.gastos.isEmpty) const Vacio('Aún no hay gastos registrados.', icono: Icons.receipt_long_outlined),
            for (final g in d.gastos)
              Tarjeta(
                onTap: () async {
                  await context.push('/gastos/${g['id']}');
                  recargar();
                },
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(g['concepto'] as String, style: T.heading),
                      const SizedBox(height: 2),
                      Text(categoriasGasto[g['categoria']] ?? '', style: T.caption),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(bs(aNum(g['monto'])), style: T.heading),
                    const SizedBox(height: 4),
                    chipEstadoGasto(g['estado'] as String),
                  ]),
                ]),
              ),
            const Seccion('Ajustes'),
            if (d.ajustes.isEmpty)
              const Vacio('Los ajustes corrigen un pago o un gasto sin borrar nada.', icono: Icons.tune),
            for (final a in d.ajustes)
              Tarjeta(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(bs(aNum(a['monto']), decimales: true), style: T.heading),
                  const SizedBox(height: 2),
                  Text(a['motivo'] as String, style: T.caption),
                ]),
              ),
          ],
        );
      },
    );
  }

  Widget _fila(String etiqueta, String valor, {bool negrita = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(etiqueta, style: T.body)),
          Text(valor, style: negrita ? T.heading : T.body),
        ]),
      );
}

/// Chip del estado de un gasto (usado también en el detalle).
Widget chipEstadoGasto(String estado) => switch (estado) {
      'aprobado' => const Chip2('Aprobado', fondo: C.menta, tinta: C.mentaInk),
      'en_votacion' => const Chip2('En votación', fondo: C.lila, tinta: C.ink),
      _ => const Chip2('Rechazado', fondo: C.rosa, tinta: C.rosaInk),
    };
