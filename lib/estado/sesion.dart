import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get supa => Supabase.instance.client;

/// Un curso del usuario, como lo devuelve la RPC `mis_cursos()` (R-CU40, R-CU41).
class CursoMio {
  CursoMio(Map<String, dynamic> m)
      : id = m['curso_id'] as String,
        nombre = m['nombre'] as String,
        colegio = m['colegio'] as String,
        gestion = m['gestion'] as int,
        rol = m['rol'] as String,
        esTesorero = m['es_tesorero'] as bool? ?? false,
        esDelegado = m['es_delegado'] as bool? ?? false,
        hijoId = m['hijo_id'] as String?,
        hijo = m['hijo'] as String?;

  final String id, nombre, colegio, rol;
  final int gestion;
  final bool esTesorero, esDelegado;
  final String? hijoId, hijo;

  bool get esAsesor => rol == 'asesor';
  bool get esProfesor => rol == 'profesor';
  bool get esPadre => rol == 'padre';
  bool get esAlumno => rol == 'alumno';
  bool get esDocente => esAsesor || esProfesor;
  bool get gestiona => esAsesor || esDelegado; // nómina y tesorero (§13.5, Q-CU-CUR-09)
  bool get veCuentas => esAsesor || esPadre; // rendición (Q-CU-REN-01)

  String get hijoNombre => (hijo ?? '').split(' ').first;
}

/// Estado global de la sesión: usuario, cursos, curso elegido y bloqueo del alumno por PIN.
/// El router escucha este objeto para decidir a qué pantalla va cada quien.
class Sesion extends ChangeNotifier {
  Sesion._();
  static final instancia = Sesion._();

  static const _almacen = FlutterSecureStorage();
  static const _kEmail = 'alumno_email', _kClave = 'alumno_clave', _kPin = 'alumno_pin';

  bool cargando = true;
  List<CursoMio> cursos = [];
  String? _cursoId;
  bool alumnoBloqueado = false; // el PIN desbloquea la app en este teléfono (RN-CU12)
  bool tieneAlumnoGuardado = false;
  bool pinPendiente = false; // credenciales guardadas, falta elegir el PIN
  StreamSubscription<AuthState>? _sub;

  User? get usuario => supa.auth.currentUser;
  bool get conSesion => supa.auth.currentSession != null;

  CursoMio? get curso {
    if (cursos.isEmpty) return null;
    return cursos.firstWhere((c) => c.id == _cursoId, orElse: () => cursos.first);
  }

  bool get esAlumno => curso?.esAlumno ?? false;

  Future<void> iniciar() async {
    try {
      final email = await _almacen.read(key: _kEmail);
      final pin = await _almacen.read(key: _kPin);
      tieneAlumnoGuardado = email != null;
      pinPendiente = email != null && pin == null;
      alumnoBloqueado = email != null && pin != null;
    } catch (_) {
      tieneAlumnoGuardado = false;
    }
    _sub = supa.auth.onAuthStateChange.listen((e) async {
      if (e.event == AuthChangeEvent.signedIn || e.event == AuthChangeEvent.signedOut) {
        await recargarCursos();
      }
    });
    await recargarCursos();
    cargando = false;
    notifyListeners();
  }

  Future<void> recargarCursos() async {
    if (!conSesion) {
      cursos = [];
      notifyListeners();
      return;
    }
    try {
      final filas = await supa.rpc('mis_cursos') as List<dynamic>;
      cursos = filas.map((f) => CursoMio(Map<String, dynamic>.from(f as Map))).toList();
    } catch (_) {
      // sin conexión: se conserva lo que había
    }
    notifyListeners();
  }

  void elegirCurso(String id) {
    _cursoId = id;
    notifyListeners();
  }

  // ---------------------------------------------------------------- Alumno
  /// Guarda las credenciales que devolvió `vincular-alumno` (almacenamiento seguro del teléfono).
  Future<void> guardarAlumno(String email, String clave) async {
    await _almacen.write(key: _kEmail, value: email);
    await _almacen.write(key: _kClave, value: clave);
    await _almacen.delete(key: _kPin);
    tieneAlumnoGuardado = true;
    pinPendiente = true;
    alumnoBloqueado = false;
    notifyListeners();
  }

  Future<void> fijarPin(String pin) async {
    await _almacen.write(key: _kPin, value: pin);
    pinPendiente = false;
    alumnoBloqueado = false;
    await recargarCursos();
  }

  /// Devuelve false si el PIN no coincide.
  Future<bool> desbloquear(String pin) async {
    final guardado = await _almacen.read(key: _kPin);
    if (guardado != pin) return false;
    if (!conSesion) {
      final email = await _almacen.read(key: _kEmail);
      final clave = await _almacen.read(key: _kClave);
      if (email == null || clave == null) return false;
      await supa.auth.signInWithPassword(email: email, password: clave);
    }
    alumnoBloqueado = false;
    await recargarCursos();
    return true;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final sesion = Sesion.instancia;
