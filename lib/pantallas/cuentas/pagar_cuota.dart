import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:storage_client/storage_client.dart';

import '../../core/errores.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

const _maxComprobante = 500 * 1024; // RNF-05: el comprobante pesa menos de 500 KB

/// «Pagar cuota» (RN-CU07): 1 paga con QR al tesorero, 2 sube el comprobante, 3 copia monto y nº.
class PagarCuota extends StatefulWidget {
  const PagarCuota({super.key, required this.cuota});
  final Map<String, dynamic> cuota;
  @override
  State<PagarCuota> createState() => _PagarCuotaState();
}

class _PagarCuotaState extends State<PagarCuota> {
  final _form = GlobalKey<FormState>();
  final _nro = TextEditingController();
  late final TextEditingController _monto;
  late final Future<String?> _qr = _cargarQr();
  Uint8List? _foto;
  bool _enviando = false;
  String? _error;

  CursoMio get _c => sesion.curso!;
  num get _saldo => aNum(widget.cuota['pendiente']);

  @override
  void initState() {
    super.initState();
    final s = _saldo;
    _monto = TextEditingController(text: s % 1 == 0 ? s.toInt().toString() : s.toStringAsFixed(2));
  }

  Future<String?> _cargarQr() async {
    final c = await supa.from('cursos').select('qr_cobro_path').eq('id', _c.id).single();
    final ruta = c['qr_cobro_path'] as String?;
    return ruta == null ? null : supa.storage.from('qr_cobro').createSignedUrl(ruta, 3600);
  }

  /// Baja la calidad hasta que quepa en 500 KB.
  Future<Uint8List> _comprimir(Uint8List bytes) async {
    var calidad = 80;
    var out = await FlutterImageCompress.compressWithList(bytes, minWidth: 1080, minHeight: 1080, quality: calidad);
    while (out.length > _maxComprobante && calidad > 30) {
      calidad -= 15;
      out = await FlutterImageCompress.compressWithList(bytes, minWidth: 1080, minHeight: 1080, quality: calidad);
    }
    return out;
  }

  Future<void> _elegirFoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 90);
    if (x == null) return;
    final comprimida = await intentar(context, () async { // ignore: use_build_context_synchronously
      _foto = await _comprimir(await x.readAsBytes());
    });
    if (comprimida && mounted) setState(() => _error = null);
  }

  Future<void> _registrar() async {
    if (!_form.currentState!.validate()) return;
    if (_foto == null) return setState(() => _error = 'Sube la foto del comprobante.');
    final monto = num.tryParse(_monto.text.trim().replaceAll(',', '.'));
    final uid = supa.auth.currentUser!.id;
    final ruta = '${_c.id}/$uid/${DateTime.now().microsecondsSinceEpoch}.jpg';
    setState(() {
      _enviando = true;
      _error = null;
    });
    Map<String, dynamic>? res;
    // ignore: use_build_context_synchronously
    final ok = await intentar(context, () async {
      await supa.storage
          .from('comprobantes')
          .uploadBinary(ruta, _foto!, fileOptions: const FileOptions(contentType: 'image/jpeg'));
      res = Map<String, dynamic>.from(await supa.rpc('registrar_pago', params: {
        'p_deuda': widget.cuota['deuda_id'],
        'p_monto': monto,
        'p_nro': _nro.text.trim(),
        'p_comprobante_path': ruta,
      }) as Map);
    });
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok && res != null) {
      context.pushReplacement('/cuotas/resultado', extra: {
        'concepto': widget.cuota['concepto'],
        'monto_distinto': res!['monto_distinto'] == true,
        'saldo': aNum(res!['saldo']),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Pantalla(
        titulo: 'Pagar cuota',
        abajo: BotonPrincipal('Registrar pago', onPressed: _registrar, cargando: _enviando),
        children: [
          Titulo(widget.cuota['concepto'] as String,
              sub: '${_c.hijo == null ? '' : '${_c.hijoNombre} · '}Faltan ${bs(_saldo)} de ${bs(aNum(widget.cuota['monto']))}'),
          const Seccion('1 · Paga con QR al tesorero'),
          Tarjeta(
            child: FutureBuilder<String?>(
              future: _qr,
              builder: (context, s) {
                if (s.connectionState != ConnectionState.done) return const Cargando();
                if (s.hasError) return AvisoCaja(mensajeDeError(s.error!));
                if (s.data == null) return Text('El tesorero todavía no subió su QR. Pregúntale cómo pagar.', style: T.body);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(R.md),
                  child: Image.network(s.data!, height: 240, fit: BoxFit.contain),
                );
              },
            ),
          ),
          const Seccion('2 · Sube tu comprobante'),
          if (_foto != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(R.md),
              child: Image.memory(_foto!, height: 200, fit: BoxFit.contain),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _elegirFoto,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(_foto == null ? 'Elegir foto' : 'Cambiar foto'),
          ),
          Text('Se comprime para que pese menos de 500 KB.', style: T.caption),
          const Seccion('3 · Copia los datos del comprobante'),
          Campo(
            etiqueta: 'Monto pagado (Bs)',
            controller: _monto,
            teclado: const TextInputType.numberWithOptions(decimal: true),
            validar: (v) {
              final n = num.tryParse((v ?? '').trim().replaceAll(',', '.'));
              return n == null || n <= 0 ? 'Escribe un monto mayor que cero.' : null;
            },
          ),
          Campo(
            etiqueta: 'Nº de transacción',
            controller: _nro,
            hint: 'Como aparece en el comprobante',
            validar: (v) => (v ?? '').trim().isEmpty ? 'Escribe el número de transacción' : null,
          ),
          if (_error != null) AvisoCaja(_error!),
        ],
      ),
    );
  }
}

/// «Resultado del pago» (RN-CU07): el pago quedó en revisión; el tesorero lo confirma o lo rechaza.
class ResultadoPago extends StatelessWidget {
  const ResultadoPago({super.key, required this.datos});
  final Map<String, dynamic> datos;

  @override
  Widget build(BuildContext context) {
    final distinto = datos['monto_distinto'] == true;
    return Pantalla(
      titulo: 'Pago registrado',
      atras: false,
      abajo: BotonPrincipal('Volver al inicio', onPressed: () => context.go('/inicio')),
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.hourglass_top_rounded, size: 56, color: C.lilaStrong),
        const SizedBox(height: 16),
        Text('Pago registrado', style: T.display, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('${datos['concepto']} · el tesorero lo revisa y te avisamos del resultado.',
            style: T.body.copyWith(color: C.inkMuted), textAlign: TextAlign.center),
        if (distinto)
          AvisoCaja(
            'El monto no coincide con lo que falta (${bs(aNum(datos['saldo']))}). El tesorero lo revisará igual.',
            fondo: C.durazno,
            tinta: C.duraznoInk,
            icono: Icons.info_outline,
          ),
      ],
    );
  }
}
