import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/errores.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';
import 'mis_hijos.dart' show prefijoQr;

/// Soy alumno: escanear el QR del padre (HU-L1). La Edge Function crea la cuenta y devuelve las credenciales,
/// que se guardan en el almacenamiento seguro del teléfono (ADR-CU04).
class AlumnoEscanear extends StatefulWidget {
  const AlumnoEscanear({super.key});
  @override
  State<AlumnoEscanear> createState() => _AlumnoEscanearState();
}

class _AlumnoEscanearState extends State<AlumnoEscanear> {
  final _camara = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  final _manual = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _camara.dispose();
    super.dispose();
  }

  Future<void> _usar(String leido) async {
    if (_enviando) return;
    final token = leido.startsWith(prefijoQr) ? leido.substring(prefijoQr.length) : leido;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final r = await supa.functions.invoke('vincular-alumno', body: {'token': token.trim()});
      final d = Map<String, dynamic>.from(r.data as Map);
      if (sesion.conSesion) await supa.auth.signOut();
      await supa.auth.signInWithPassword(email: d['email'] as String, password: d['password'] as String);
      await sesion.guardarAlumno(d['email'] as String, d['password'] as String); // → «Elige tu PIN»
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Pantalla(
        titulo: 'Entrar como alumno',
        children: [
          const Titulo('Escanea el código', sub: 'Tu mamá o papá lo tiene en Cursito, en «Mis hijos».'),
          ClipRRect(
            borderRadius: BorderRadius.circular(R.lg),
            child: SizedBox(
              height: 320,
              child: _enviando
                  ? const ColoredBox(color: C.lila, child: Cargando())
                  : MobileScanner(
                      controller: _camara,
                      onDetect: (c) {
                        final v = c.barcodes.firstOrNull?.rawValue;
                        if (v != null) _usar(v);
                      },
                      errorBuilder: (_, _) => const ColoredBox(
                          color: C.lila, child: Center(child: Text('No pudimos abrir la cámara.', textAlign: TextAlign.center))),
                    ),
            ),
          ),
          if (_error != null) AvisoCaja(_error!),
          const SizedBox(height: 12),
          Text('¿No eres el alumno? Pídele a tu mamá o papá su propio código.', style: T.caption),
          if (kDebugMode || const bool.fromEnvironment('CURSITO_DEV')) ...[
            // Sólo en desarrollo (no sale en el APK de release, que no define CURSITO_DEV): pegar el token sin cámara.
            const Etiqueta('Token (sólo desarrollo)'),
            TextField(controller: _manual),
            TextButton(onPressed: () => _usar(_manual.text), child: const Text('Usar token')),
          ],
        ],
      );
}

/// Elegir el PIN (tras vincular) o escribirlo para desbloquear la app en este teléfono (RN-CU12).
class AlumnoPin extends StatefulWidget {
  const AlumnoPin({super.key});
  @override
  State<AlumnoPin> createState() => _AlumnoPinState();
}

class _AlumnoPinState extends State<AlumnoPin> {
  final _pin = TextEditingController();
  bool _enviando = false;
  String? _error;
  bool get _elegir => sesion.pinPendiente;

  Future<Map<String, dynamic>> _datos() async => await supa
      .from('alumnos')
      .select('nombres, apellidos, curso:cursos(nombre, colegio, nivel), padre:perfiles!alumnos_padre_id_fkey(nombre)')
      .eq('usuario_alumno_id', sesion.usuario!.id)
      .single();

  Future<void> _listo() async {
    if (_pin.text.length != 4) return setState(() => _error = 'El PIN tiene 4 números.');
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      if (_elegir) {
        await sesion.fijarPin(_pin.text);
      } else if (!await sesion.desbloquear(_pin.text)) {
        _pin.clear();
        setState(() => _error = 'Ese PIN no es. Intenta de nuevo.');
      }
      if (mounted && !sesion.alumnoBloqueado && !sesion.pinPendiente) context.go('/a/inicio');
    } catch (e) {
      setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _campoPin() => TextField(
        controller: _pin,
        autofocus: true,
        obscureText: true,
        maxLength: 4,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: T.display.copyWith(letterSpacing: 24),
        decoration: const InputDecoration(counterText: '', hintText: '• • • •'),
        onSubmitted: (_) => _listo(),
      );

  @override
  Widget build(BuildContext context) {
    if (!_elegir) {
      return Pantalla(
        atras: false,
        abajo: BotonPrincipal('Entrar', onPressed: _listo, cargando: _enviando),
        children: [
          const SizedBox(height: 32),
          const Titulo('Hola de nuevo', sub: 'Escribe tu PIN de 4 números para entrar.'),
          _campoPin(),
          if (_error != null) AvisoCaja(_error!),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Entrar como alumno'), automaticallyImplyLeading: false),
      bottomNavigationBar: SafeArea(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: BotonPrincipal('Entrar a mi curso', onPressed: _listo, cargando: _enviando))),
      body: Cargador<Map<String, dynamic>>(
        cargar: _datos,
        construir: (context, d, _) {
          final curso = d['curso'] as Map? ?? {};
          final padre = (d['padre'] as Map?)?['nombre'] ?? '';
          Widget fila(String a, String b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [SizedBox(width: 110, child: Text(a, style: T.caption)), Expanded(child: Text(b, style: T.heading))]),
              );
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Chip2('Código leído', fondo: C.menta, tinta: C.mentaInk),
            const SizedBox(height: 8),
            Text('Hola, ${d['nombres']}', style: T.display),
            const SizedBox(height: 16),
            Tarjeta(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Estos son tus datos', style: T.heading),
                const SizedBox(height: 8),
                fila('Nombre', '${d['nombres']} ${d['apellidos']}'),
                fila('Curso', '${curso['nombre']}'),
                fila('Colegio', '${curso['colegio']}'),
                fila('Vinculado por', '$padre'),
              ]),
            ),
            const Etiqueta('Elige un PIN de 4 números'),
            _campoPin(),
            const SizedBox(height: 6),
            Text('Lo usarás para entrar desde este celular. No se lo cuentes a tus compañeros.', style: T.caption),
            if (_error != null) AvisoCaja(_error!),
            const SizedBox(height: 12),
            Text('¿No eres ${d['nombres']}? Pídele a tu mamá o papá su propio código.', style: T.caption),
          ]);
        },
      ),
    );
  }
}
