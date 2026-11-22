import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

/// «Mis cuotas» del padre (R-CU08, RN-CU07): lo que debe su hijo, con el estado de cada pago.
/// Sólo ve sus propias cuotas (RN-CU03, RN-CU04).
class MisCuotas extends StatelessWidget {
  const MisCuotas({super.key});

  CursoMio get _c => sesion.curso!;

  Future<List<Map<String, dynamic>>> _cargar() async {
    final f = await supa.rpc('mis_cuotas', params: {'p_curso': _c.id}) as List;
    return f.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Cargador<List<Map<String, dynamic>>>(
      cargar: _cargar,
      construir: (context, cuotas, recargar) {
        final activas = cuotas.where((q) => q['anulada'] != true).toList();
        final pendientes = activas.where((q) => aNum(q['pendiente']) > 0).toList();
        final pagadas = activas.where((q) => aNum(q['pendiente']) <= 0).toList();
        final anuladas = cuotas.where((q) => q['anulada'] == true).toList();
        return Pantalla(
          titulo: 'Cuentas',
          atras: false,
          children: [
            Titulo(_c.hijo == null ? 'Mis cuotas' : 'Cuotas de ${_c.hijoNombre}',
                sub: 'Solo tú y el tesorero ven tu estado de pago.'),
            Tarjeta(
              onTap: () async {
                await context.push('/cuentas/curso');
                recargar();
              },
              child: Row(children: [
                const Icon(Icons.receipt_long_outlined, color: C.lilaStrong),
                const SizedBox(width: 12),
                Expanded(child: Text('Cuentas del curso', style: T.heading)),
                const Icon(Icons.chevron_right, color: C.lilaStrong),
              ]),
            ),
            if (_c.esTesorero)
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
            if (activas.isEmpty && anuladas.isEmpty)
              const Vacio('Por ahora no hay cuotas.', icono: Icons.payments_outlined),
            if (pendientes.isNotEmpty) ...[
              const Seccion('Por pagar'),
              for (final q in pendientes) _tarjeta(context, q, recargar),
            ],
            if (pagadas.isNotEmpty) ...[
              const Seccion('Pagadas'),
              for (final q in pagadas) _tarjeta(context, q, recargar),
            ],
            if (anuladas.isNotEmpty) ...[
              const Seccion('Anuladas'),
              for (final q in anuladas) _tarjeta(context, q, recargar),
            ],
          ],
        );
      },
    );
  }

  Widget _tarjeta(BuildContext context, Map<String, dynamic> q, VoidCallback recargar) {
    final monto = aNum(q['monto']);
    final pagado = aNum(q['pagado']);
    final pendiente = aNum(q['pendiente']);
    final enRevision = aNum(q['en_revision']);
    final vence = DateTime.parse(q['vence_el'] as String);
    final vencida = pendiente > 0 && vence.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    final rechazo = q['ultimo_rechazo'] as String?;
    final anulada = q['anulada'] == true;

    return Tarjeta(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(q['concepto'] as String, style: T.heading)),
          if (anulada)
            const Chip2('Anulada', fondo: C.rosa, tinta: C.rosaInk)
          else if (pendiente <= 0)
            const Chip2('Pagada', fondo: C.menta, tinta: C.mentaInk)
          else if (vencida)
            const Chip2('Vencida', fondo: C.rosa, tinta: C.rosaInk),
        ]),
        const SizedBox(height: 4),
        Text('Vence el ${fechaCorta(vence)} · ${bs(monto)}', style: T.caption),
        if (!anulada && pendiente > 0 && pagado > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Pagado ${bs(pagado)} de ${bs(monto)} · faltan ${bs(pendiente)}', style: T.body),
          ),
        if (enRevision > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('En revisión: ${bs(enRevision)}. El tesorero lo confirma o lo rechaza.', style: T.caption),
          ),
        if (rechazo != null && pendiente > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Rechazado: $rechazo', style: T.body.copyWith(color: C.rosaInk)),
          ),
        if (anulada)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Motivo: ${q['motivo_anulacion']}', style: T.caption),
          ),
        if (!anulada && pendiente > 0) ...[
          const SizedBox(height: 12),
          BotonPrincipal(
            rechazo != null ? 'Subir otro comprobante' : 'Pagar con QR',
            icono: Icons.qr_code_2,
            onPressed: () async {
              await context.push('/cuotas/pagar', extra: q);
              recargar();
            },
          ),
        ],
      ]),
    );
  }
}
