import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:storage_client/storage_client.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';
import 'cuentas_curso.dart';

const _maxFactura = 500 * 1024; // el bucket «facturas» acepta hasta 512 KB

/// Baja la calidad de una foto hasta que pese menos de 500 KB.
Future<Uint8List> _comprimirFoto(Uint8List bytes) async {
  var calidad = 80;
  var out = await FlutterImageCompress.compressWithList(bytes, minWidth: 1080, minHeight: 1080, quality: calidad);
  while (out.length > _maxFactura && calidad > 30) {
    calidad -= 15;
    out = await FlutterImageCompress.compressWithList(bytes, minWidth: 1080, minHeight: 1080, quality: calidad);
  }
  return out;
}

/// «Registrar gasto» (RN-CU19: todo gasto lleva foto; RN-CU08: desde el umbral pasa a votación).
class RegistrarGasto extends StatefulWidget {
  const RegistrarGasto({super.key});
  @override
  State<RegistrarGasto> createState() => _RegistrarGastoState();
}

class _RegistrarGastoState extends State<RegistrarGasto> {
  final _form = GlobalKey<FormState>();
  final _concepto = TextEditingController(), _monto = TextEditingController();
  String _categoria = 'comida';
  Uint8List? _factura;
  bool _enviando = false;
  String? _error;
  late final Future<num> _umbral = supa
      .from('cursos')
      .select('umbral_votacion')
      .eq('id', sesion.curso!.id)
      .single()
      .then((f) => aNum(f['umbral_votacion']));

  @override
  void initState() {
    super.initState();
    _monto.addListener(() => setState(() {}));
  }

  Future<void> _elegirFactura() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 90);
    if (x == null) return;
    final ok = await intentar(context, () async { // ignore: use_build_context_synchronously
    });
    if (ok && mounted) setState(() => _error = null);
  }

  Future<void> _registrar() async {
    if (!_form.currentState!.validate()) return;
    if (_factura == null) return setState(() => _error = 'Sube la foto de la factura o del recibo.');
    final c = sesion.curso!;
    final ruta = '${c.id}/${DateTime.now().microsecondsSinceEpoch}.jpg';
    setState(() {
      _enviando = true;
      _error = null;
    });
    final ok = await intentar(context, () async {
      await supa.storage.from('facturas').uploadBinary(ruta, _factura!, fileOptions: const FileOptions(contentType: 'image/jpeg'));
      await supa.from('gastos').insert({
        'curso_id': c.id,
        'concepto': _concepto.text.trim(),
        'categoria': _categoria,
        'monto': num.parse(_monto.text.trim().replaceAll(',', '.')),
        'factura_path': ruta,
      });
    });
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Pantalla(
        titulo: 'Registrar gasto',
        abajo: BotonPrincipal('Guardar gasto', onPressed: _registrar, cargando: _enviando),
        children: [
          const Titulo('Nuevo gasto', sub: 'Cada gasto lleva la foto de la factura o del recibo.'),
          Campo(
            etiqueta: 'Concepto',
            controller: _concepto,
            hint: 'Arreglos florales',
            validar: (v) => (v ?? '').trim().isEmpty ? 'Escribe el concepto' : null,
          ),
          const Etiqueta('Categoría'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in categoriasGasto.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _categoria == e.key,
                onSelected: (_) => setState(() => _categoria = e.key),
              ),
          ]),
          Campo(
            etiqueta: 'Monto (Bs)',
            controller: _monto,
            teclado: const TextInputType.numberWithOptions(decimal: true),
            hint: '150',
            validar: (v) {
              final n = num.tryParse((v ?? '').trim().replaceAll(',', '.'));
              return n == null || n <= 0 ? 'Escribe un monto mayor que cero.' : null;
            },
          ),
          FutureBuilder<num>(
            future: _umbral,
            builder: (context, s) {
              final m = num.tryParse(_monto.text.trim().replaceAll(',', '.')) ?? 0;
              if (!s.hasData || m <= 0 || m < s.data!) return const SizedBox.shrink();
              return AvisoCaja(
                'Desde ${bs(s.data!)} el gasto pasa a votación de las familias (2 días).',
                fondo: C.cielo,
                tinta: C.cieloInk,
                icono: Icons.how_to_vote_outlined,
              );
            },
          ),
          const Seccion('Factura o recibo'),
          if (_factura != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(R.md),
              child: Image.memory(_factura!, height: 200, fit: BoxFit.contain),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _elegirFactura,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(_factura == null ? 'Elegir foto' : 'Cambiar foto'),
          ),
          if (_error != null) AvisoCaja(_error!),
        ],
      ),
    );
  }
}

class _DatosGasto {
  _DatosGasto(this.gasto, this.fotoUrl, this.votos);
  final Map<String, dynamic> gasto;
  final String fotoUrl;
  final Map<String, dynamic>? votos; // fila de resultado_votacion (null si nadie votó aún)
}

/// Detalle del gasto (RN-CU08): factura, estado y votación. Los padres votan; el tesorero cierra o ajusta.
class DetalleGasto extends StatefulWidget {
  const DetalleGasto({super.key, required this.id});
  final String id;
  @override
  State<DetalleGasto> createState() => _DetalleGastoState();
}

class _DetalleGastoState extends State<DetalleGasto> {
  VoidCallback? _refrescar; // recarga lo que dibuja el Cargador
  bool _enviando = false;

  CursoMio get _c => sesion.curso!;

  Future<_DatosGasto> _cargar() async {
    final g = Map<String, dynamic>.from(await supa.from('gastos').select().eq('id', widget.id).single());
    final url = await supa.storage.from('facturas').createSignedUrl(g['factura_path'] as String, 3600);
    final rv = await supa.rpc('resultado_votacion', params: {'p_gasto': widget.id}) as List;
    final votos = rv.isEmpty ? null : Map<String, dynamic>.from(rv.first as Map);
    return _DatosGasto(g, url, votos);
  }

  void _recargar() => _refrescar?.call();

  Future<void> _votar(bool aFavor) async {
    setState(() => _enviando = true);
    final ok = await intentar(context,
        () => supa.from('votos').insert({'gasto_id': widget.id, 'a_favor': aFavor}));
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok) {
      avisar(context, 'Tu voto quedó registrado.');
      _recargar();
    }
  }

  Future<void> _cerrar() async {
    final ok = await confirmar(context, 'Cerrar la votación', 'Se cuenta lo que hay hasta ahora. No se puede volver a votar.',
        si: 'Cerrar votación');
    if (!ok || !mounted) return;
    setState(() => _enviando = true);
    final hecho = await intentar(context, () => supa.rpc('cerrar_votacion', params: {'p_gasto': widget.id}));
    if (!mounted) return;
    setState(() => _enviando = false);
    if (hecho) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Cargador<_DatosGasto>(
      cargar: _cargar,
      construir: (context, d, recargar) {
        _refrescar = recargar;
        final g = d.gasto;
        final estado = g['estado'] as String;
        final v = d.votos;
        final vota = g['vota_hasta'] == null ? null : DateTime.parse(g['vota_hasta'] as String).toLocal();
        final abierta = estado == 'en_votacion' && vota != null && DateTime.now().isBefore(vota);
        final miVoto = v?['mi_voto'];
        return Pantalla(
          titulo: 'Gasto',
          children: [
            Row(children: [
              Expanded(child: Text(g['concepto'] as String, style: T.display)),
              chipEstadoGasto(estado),
            ]),
            const SizedBox(height: 8),
            Text('${categoriasGasto[g['categoria']] ?? ''} · ${bs(aNum(g['monto']))}', style: T.body),
            if (vota != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    estado == 'en_votacion'
                        ? 'Votación hasta ${fechaHora(vota)}'
                        : 'Votación cerrada el ${fechaHora(vota)}',
                    style: T.caption),
              ),
            if (v != null && estado == 'en_votacion')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    'A favor: ${v['a_favor']} · En contra: ${v['en_contra']} · Familias: ${v['familias']}',
                    style: T.caption),
              ),
            const Seccion('Factura'),
            ClipRRect(
              borderRadius: BorderRadius.circular(R.md),
              child: Image.network(d.fotoUrl, height: 320, fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Text('No se pudo mostrar la factura.', style: T.caption)),
            ),
            if (abierta && _c.esPadre && miVoto == null) ...[
              const Seccion('Tu voto'),
              Row(children: [
                Expanded(
                    child: BotonPrincipal('A favor', cargando: _enviando, onPressed: () => _votar(true))),
                const SizedBox(width: 12),
                Expanded(
                    child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: _enviando ? null : () => _votar(false),
                        child: const Text('En contra'))),
              ]),
            ],
            if (miVoto != null && abierta)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('Ya votaste ${miVoto == true ? 'a favor' : 'en contra'}.', style: T.caption),
              ),
            if (_c.esTesorero && abierta) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _enviando ? null : _cerrar,
                child: const Text('Cerrar votación ahora'),
              ),
            ],
            if (_c.esTesorero && estado == 'aprobado') ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () async {
                  if (await context.push<bool>('/ajustes/nuevo', extra: {'gasto_id': widget.id}) == true) _recargar();
                },
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Registrar ajuste'),
              ),
            ],
          ],
        );
      },
    );
  }
}
