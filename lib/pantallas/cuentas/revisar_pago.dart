import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

/// «Revisar comprobante» (RN-CU07): el tesorero confirma o rechaza con motivo. Sólo lo ve el tesorero.
class RevisarPago extends StatefulWidget {
  const RevisarPago({super.key, required this.pago});
  final Map<String, dynamic> pago;
  @override
  State<RevisarPago> createState() => _RevisarPagoState();
}

class _RevisarPagoState extends State<RevisarPago> {
  late final Future<String> _foto = supa.storage
      .from('comprobantes')
      .createSignedUrl(widget.pago['comprobante_path'] as String, 3600);
  bool _enviando = false;

  Map<String, dynamic> get _deuda => Map<String, dynamic>.from(widget.pago['deuda'] as Map);
  Map<String, dynamic> get _alumno => Map<String, dynamic>.from(_deuda['alumno'] as Map);
  String get _concepto => ((_deuda['cuota'] as Map)['concepto'] as String);
  String get _nombreAlumno => '${_alumno['apellidos']} ${_alumno['nombres']}';
  num get _monto => aNum(widget.pago['monto']);
  num get _montoCuota => aNum(_deuda['monto']);

  Future<void> _revisar(bool confirmar, {String? motivo}) async {
    setState(() => _enviando = true);
    final ok = await intentar(
        context,
        () => supa.rpc('revisar_pago', params: {
              'p_pago': widget.pago['id'],
              'p_confirmar': confirmar,
              'p_motivo': motivo,
            }));
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok) {
      avisar(context, confirmar ? 'Pago confirmado.' : 'Pago rechazado. La familia verá el motivo.');
      context.pop(true);
    }
  }

  Future<void> _rechazar() async {
    final motivo = await _pedirMotivoRechazo(context);
    if (motivo == null) return;
    await _revisar(false, motivo: motivo);
  }

  @override
  Widget build(BuildContext context) {
    final igual = _monto == _montoCuota;
    return Pantalla(
      titulo: 'Revisar comprobante',
      abajo: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BotonPrincipal('Confirmar pago',
            icono: Icons.check, cargando: _enviando, onPressed: () => _revisar(true)),
        TextButton(
          onPressed: _enviando ? null : _rechazar,
          child: const Text('Rechazar con un motivo'),
        ),
      ]),
      children: [
        Titulo(_concepto, sub: '$_nombreAlumno · padre: ${widget.pago['padre'] ?? 'sin nombre'}'),
        FutureBuilder<String>(
          future: _foto,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) return const Cargando();
            if (s.hasError) return AvisoCaja(s.error.toString());
            return ClipRRect(
              borderRadius: BorderRadius.circular(R.md),
              child: Image.network(s.data!, height: 360, fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Text('No se pudo mostrar el comprobante.', style: T.caption)),
            );
          },
        ),
        const SizedBox(height: 12),
        Tarjeta(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Monto: ${bs(_monto)}', style: T.heading),
            const SizedBox(height: 4),
            Text('Nº de transacción: ${widget.pago['nro_transaccion']}', style: T.body),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (igual)
                const Chip2('Monto igual a la cuota', fondo: C.menta, tinta: C.mentaInk)
              else
                Chip2('Distinto a lo que falta (${bs(_montoCuota)})', fondo: C.durazno, tinta: C.duraznoInk),
            ]),
            const SizedBox(height: 10),
            Text('Compara el número con la foto antes de confirmar.', style: T.caption),
          ]),
        ),
      ],
    );
  }
}

/// Motivo obligatorio del rechazo (texto libre, Q-CU-PAG-09). Devuelve null si cancela.
Future<String?> _pedirMotivoRechazo(BuildContext context) {
  final motivo = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Rechazar el pago', style: T.heading),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('La familia verá este motivo y podrá subir otro comprobante.', style: T.caption),
        const SizedBox(height: 12),
        TextField(
          controller: motivo,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Por ejemplo: la foto no se lee'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        TextButton(
          onPressed: () {
            final t = motivo.text.trim();
            if (t.isNotEmpty) Navigator.pop(c, t);
          },
          child: const Text('Rechazar'),
        ),
      ],
    ),
  );
}
