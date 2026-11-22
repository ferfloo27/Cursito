import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errores.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

class _Datos {
  _Datos(this.qrUrl, this.cuotas);
  final String? qrUrl;
  final List<Map<String, dynamic>> cuotas;
}

/// Panel del tesorero (Cuentas): QR de cobro (R-CU42), cuotas del curso, crear (R-CU08) y anular (Q-CU-PAG-08).
/// Comprobantes, «Quién debe» y gastos llegan en las partes 3.3 y 3.4.
class PanelTesorero extends StatefulWidget {
  const PanelTesorero({super.key, this.enPestana = true});
  final bool enPestana; // false cuando se abre desde «Mis cuotas» (con botón de volver)
  @override
  State<PanelTesorero> createState() => _PanelTesoreroState();
}

class _PanelTesoreroState extends State<PanelTesorero> {
  CursoMio get _c => sesion.curso!;
  bool _subiendo = false;

  Future<_Datos> _cargar() async {
    final c = await supa.from('cursos').select('qr_cobro_path').eq('id', _c.id).single();
    final ruta = c['qr_cobro_path'] as String?;
    final url = ruta == null ? null : await supa.storage.from('qr_cobro').createSignedUrl(ruta, 3600);
    final cuotas = await supa
        .from('cuotas')
        .select('id, concepto, monto_por_alumno, vence_el, anulada_en, motivo_anulacion')
        .eq('curso_id', _c.id)
        .order('creado_en', ascending: false);
    return _Datos(url, List<Map<String, dynamic>>.from(cuotas));
  }

  Future<void> _subirQr(VoidCallback recargar) async {
    final foto = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 90);
    if (foto == null) return;
    setState(() => _subiendo = true);
    final ok = await intentar(context, () async {
      final bytes = await FlutterImageCompress.compressWithList(
          await foto.readAsBytes(),
          minWidth: 1080,
          minHeight: 1080,
          quality: 85);
      final ruta = '${_c.id}/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await supa.storage
          .from('qr_cobro')
          .uploadBinary(ruta, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
      await supa.rpc('fijar_qr_cobro', params: {'p_curso': _c.id, 'p_path': ruta});
    });
    if (!mounted) return;
    setState(() => _subiendo = false);
    if (ok) {
      avisar(context, 'QR guardado. Las familias lo verán al pagar.');
      recargar();
    }
  }

  Future<void> _anular(Map<String, dynamic> q, VoidCallback recargar) async {
    final motivo = await _pedirMotivo(context, q['concepto'] as String);
    if (motivo == null || !mounted) return;
    final ok = await intentar(
        context, () => supa.rpc('anular_cuota', params: {'p_cuota': q['id'], 'p_motivo': motivo}));
    if (!mounted) return;
    if (ok) {
      avisar(context, 'Cuota anulada.');
      recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Cargador<_Datos>(
      cargar: _cargar,
      construir: (context, d, recargar) => Pantalla(
        titulo: 'Cuentas',
        atras: !widget.enPestana,
        children: [
          const Titulo('Panel del tesorero', sub: 'Tu QR de cobro y las cuotas del curso.'),
          const Seccion('Tu QR de cobro'),
          Tarjeta(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (d.qrUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(R.md),
                  child: Image.network(d.qrUrl!, height: 220, fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Text('No se pudo mostrar el QR.', style: T.caption)),
                )
              else
                Text('Aún no subiste tu QR. Las familias lo verán al pagar la cuota.', style: T.body),
              const SizedBox(height: 12),
              BotonPrincipal(d.qrUrl == null ? 'Subir QR' : 'Cambiar QR',
                  icono: Icons.qr_code_2, cargando: _subiendo, onPressed: () => _subirQr(recargar)),
            ]),
          ),
          Seccion(
            'Cuotas',
            accion: TextButton.icon(
              onPressed: () async {
                final creada = await context.push<bool>('/cuotas/nueva');
                if (creada == true) recargar();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Crear cuota'),
            ),
          ),
          if (d.cuotas.isEmpty)
            const Vacio('Aún no hay cuotas. Crea la primera para que las familias vean su deuda.',
                icono: Icons.payments_outlined),
          for (final q in d.cuotas) _tarjetaCuota(q, recargar),
        ],
      ),
    );
  }

  Widget _tarjetaCuota(Map<String, dynamic> q, VoidCallback recargar) {
    final anulada = q['anulada_en'] != null;
    final vence = DateTime.parse(q['vence_el'] as String);
    return Tarjeta(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(q['concepto'] as String, style: T.heading)),
          if (anulada) const Chip2('Anulada', fondo: C.rosa, tinta: C.rosaInk),
        ]),
        const SizedBox(height: 4),
        Text('${bs(aNum(q['monto_por_alumno']))} por alumno · vence el ${fechaCorta(vence)}', style: T.caption),
        if (anulada)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Motivo: ${q['motivo_anulacion']}', style: T.caption),
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => _anular(q, recargar), child: const Text('Anular')),
          ),
      ]),
    );
  }
}

/// Pide el motivo de la anulación (obligatorio). Devuelve null si cancela.
Future<String?> _pedirMotivo(BuildContext context, String concepto) {
  final motivo = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Anular «$concepto»', style: T.heading),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Solo se puede si nadie pagó. Las familias verán la cuota como anulada, con este motivo.',
            style: T.caption),
        const SizedBox(height: 12),
        TextField(
          controller: motivo,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Por ejemplo: monto equivocado'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        TextButton(
          onPressed: () {
            final t = motivo.text.trim();
            if (t.isNotEmpty) Navigator.pop(c, t);
          },
          child: const Text('Anular cuota'),
        ),
      ],
    ),
  );
}
