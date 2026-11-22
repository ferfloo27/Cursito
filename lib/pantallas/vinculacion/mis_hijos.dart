import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

const prefijoQr = 'cursito-vincular:';

/// 10 · Mis hijos: vincular con QR (R-CU07, RN-CU12) y quitar el acceso (R-CU46).
class MisHijos extends StatefulWidget {
  const MisHijos({super.key});
  @override
  State<MisHijos> createState() => _MisHijosState();
}

class _MisHijosState extends State<MisHijos> {
  int _version = 0;

  Future<List<Map<String, dynamic>>> _cargar() async {
    final ids = sesion.cursos.where((c) => c.esPadre && c.hijoId != null).map((c) => c.hijoId!).toList();
    if (ids.isEmpty) return [];
    final f = await supa
        .from('alumnos')
        .select('id, nombres, apellidos, usuario_alumno_id, curso:cursos(nombre, colegio)')
        .inFilter('id', ids);
    return List<Map<String, dynamic>>.from(f);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mis hijos')),
        body: Cargador<List<Map<String, dynamic>>>(
          key: ValueKey(_version),
          cargar: _cargar,
          construir: (context, hijos, _) => ListView(padding: const EdgeInsets.all(16), children: [
            if (hijos.isEmpty) const Vacio('Todavía no elegiste a tu hijo o hija en ningún curso.'),
            for (final h in hijos) _TarjetaHijo(h, alCambiar: () => setState(() => _version++)),
          ]),
        ),
      );
}

class _TarjetaHijo extends StatefulWidget {
  const _TarjetaHijo(this.h, {required this.alCambiar});
  final Map<String, dynamic> h;
  final VoidCallback alCambiar;
  @override
  State<_TarjetaHijo> createState() => _TarjetaHijoState();
}

class _TarjetaHijoState extends State<_TarjetaHijo> {
  String? _token;
  DateTime? _vence;
  Timer? _reloj;
  bool _generando = false;

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _generar() async {
    setState(() => _generando = true);
    final ok = await intentar(context, () async {
      final t = await supa.rpc('generar_token_vinculacion', params: {'p_alumno': widget.h['id']}) as String;
      _token = t;
      _vence = DateTime.now().add(const Duration(minutes: 10));
    });
    if (!mounted) return;
    setState(() => _generando = false);
    if (ok) {
      _reloj?.cancel();
      _reloj = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (!mounted) return;
        if (DateTime.now().isAfter(_vence!)) {
          _reloj?.cancel();
          setState(() => _token = null);
          return;
        }
        setState(() {});
        // ¿ya lo escaneó? cada 5 s
        if (DateTime.now().second % 5 == 0) {
          final f = await supa.from('alumnos').select('usuario_alumno_id').eq('id', widget.h['id']).single();
          if (f['usuario_alumno_id'] != null && mounted) {
            _reloj?.cancel();
            avisar(context, '${widget.h['nombres']} ya entró con el QR.');
            widget.alCambiar();
          }
        }
      });
    }
  }

  Future<void> _quitarAcceso() async {
    final n = widget.h['nombres'];
    if (!await confirmar(context, 'Quitar el acceso',
        'El celular de $n dejará de entrar a Cursito. Luego puedes generar otro QR para su nuevo celular.',
        si: 'Quitar el acceso')) {
      return;
    }
    if (!mounted) return;
    if (await intentar(context, () => supa.rpc('quitar_acceso_alumno', params: {'p_alumno': widget.h['id']}))) {
      widget.alCambiar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.h;
    final curso = h['curso'] as Map? ?? {};
    final vinculado = h['usuario_alumno_id'] != null;
    final resta = _vence == null ? Duration.zero : _vence!.difference(DateTime.now());
    final mmss = '${resta.inMinutes}:${(resta.inSeconds % 60).toString().padLeft(2, '0')}';
    return Tarjeta(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          CircleAvatar(backgroundColor: C.lila, child: Text('${h['nombres']}'[0], style: T.heading)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${h['nombres']} ${h['apellidos']}', style: T.heading),
            Text('${curso['nombre']} · ${curso['colegio']}', style: T.caption),
          ])),
          vinculado
              ? const Chip2('Vinculado', fondo: C.menta, tinta: C.mentaInk)
              : const Chip2('Sin vincular', fondo: C.durazno, tinta: C.duraznoInk),
        ]),
        const SizedBox(height: 16),
        if (_token != null) ...[
          Center(child: QrImageView(data: '$prefijoQr$_token', size: 220, backgroundColor: Colors.white)),
          const SizedBox(height: 8),
          Center(child: Chip2('Un solo uso · vence en $mmss', fondo: C.durazno, tinta: C.duraznoInk)),
          const SizedBox(height: 12),
          Text('Pídele a ${h['nombres']} que abra Cursito en su celular, toque «Soy alumno y tengo un código QR» y escanee este código.',
              style: T.body),
          const SizedBox(height: 8),
          TextButton(onPressed: _generando ? null : _generar, child: const Text('Generar otro QR')),
        ] else ...[
          Text('Qué recibe la cuenta de ${h['nombres']}', style: T.heading),
          const SizedBox(height: 6),
          Text('· Su nombre y curso, tomados de tus datos.\n'
              '· Un PIN de 4 dígitos que elige al entrar.\n'
              '· Ve tareas, eventos, calendario y horario.\n'
              '· No ve cuotas, pagos ni informes.', style: T.body),
          const SizedBox(height: 12),
          BotonPrincipal(vinculado ? 'QR para otro celular' : 'Mostrar QR a ${h['nombres']}',
              icono: Icons.qr_code_2, cargando: _generando, onPressed: _generar),
          if (vinculado) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: _quitarAcceso, child: const Text('Quitar el acceso')),
          ],
        ],
      ]),
    );
  }
}
