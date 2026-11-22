import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errores.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

class PantallaCargando extends StatelessWidget {
  const PantallaCargando({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.lila,
        body: Center(child: Text('Cursito', style: T.display.copyWith(fontSize: 44))),
      );
}

/// 1 · Splash
class Bienvenida extends StatelessWidget {
  const Bienvenida({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: C.lila, borderRadius: BorderRadius.circular(R.lg)),
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Cursito', style: T.display.copyWith(fontSize: 48, height: 1.1)),
                    const SizedBox(height: 8),
                    Text('Un curso, un solo lugar.', style: T.title),
                    const SizedBox(height: 12),
                    Text('Avisos, tareas, actividades y las cuentas del curso, claras para padres, alumnos y profesores.',
                        style: T.body),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => context.push('/registro'), child: const Text('Crear mi cuenta')),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => context.push('/entrar'), child: const Text('Ya tengo cuenta')),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => context.push('/alumno/escanear'),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Soy alumno y tengo un código QR'),
              ),
            ]),
          ),
        ),
      );
}

/// 2 · Registro (R-CU01: 8 caracteres o más, celular opcional, sin confirmar el correo)
class Registro extends StatefulWidget {
  const Registro({super.key});
  @override
  State<Registro> createState() => _RegistroState();
}

class _RegistroState extends State<Registro> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController(), _correo = TextEditingController();
  final _celular = TextEditingController(), _clave = TextEditingController();
  bool _enviando = false;
  String? _error;

  Future<void> _crear() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await supa.auth.signUp(
        email: _correo.text.trim(),
        password: _clave.text,
        data: {'nombre': _nombre.text.trim(), if (_celular.text.trim().isNotEmpty) 'telefono': _celular.text.trim()},
      );
      await sesion.recargarCursos();
    } catch (e) {
      setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: Pantalla(
          titulo: 'Crear cuenta',
          abajo: BotonPrincipal('Crear cuenta', onPressed: _crear, cargando: _enviando),
          children: [
            const Titulo('Crea tu cuenta',
                sub: 'Para padres, profesores y delegados. Los alumnos entran con el QR de su papá o mamá.'),
            Campo(
                etiqueta: 'Nombre y apellido',
                controller: _nombre,
                validar: (v) => (v ?? '').trim().length < 3 ? 'Escribe tu nombre y apellido' : null),
            Campo(
                etiqueta: 'Correo',
                controller: _correo,
                teclado: TextInputType.emailAddress,
                validar: (v) => (v ?? '').contains('@') ? null : 'Escribe un correo válido'),
            Campo(etiqueta: 'Celular (opcional)', controller: _celular, teclado: TextInputType.phone),
            Campo(
                etiqueta: 'Contraseña',
                controller: _clave,
                oculto: true,
                ayuda: 'Mínimo 8 caracteres.',
                validar: (v) => (v ?? '').length < 8 ? 'La contraseña debe tener al menos 8 caracteres' : null),
            if (_error != null) AvisoCaja(_error!),
            const SizedBox(height: 8),
            TextButton(onPressed: () => context.pushReplacement('/entrar'), child: const Text('Ya tengo cuenta')),
          ],
        ),
      );
}

/// 3 · Inicio de sesión (sin «Olvidé mi contraseña»: Q-CU-ACC-02)
class IniciarSesion extends StatefulWidget {
  const IniciarSesion({super.key});
  @override
  State<IniciarSesion> createState() => _IniciarSesionState();
}

class _IniciarSesionState extends State<IniciarSesion> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController(), _clave = TextEditingController();
  bool _enviando = false;
  String? _error;

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await supa.auth.signInWithPassword(email: _correo.text.trim(), password: _clave.text);
      await sesion.recargarCursos();
    } catch (e) {
      setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: Pantalla(
          titulo: 'Entrar',
          abajo: BotonPrincipal('Entrar', onPressed: _entrar, cargando: _enviando),
          children: [
            const Titulo('Hola de nuevo', sub: 'Entra con el correo y la contraseña de tu cuenta.'),
            Campo(
                etiqueta: 'Correo',
                controller: _correo,
                teclado: TextInputType.emailAddress,
                validar: (v) => (v ?? '').contains('@') ? null : 'Escribe un correo válido'),
            Campo(
                etiqueta: 'Contraseña',
                controller: _clave,
                oculto: true,
                validar: (v) => (v ?? '').isEmpty ? 'Escribe tu contraseña' : null),
            if (_error != null) AvisoCaja(_error!),
            const SizedBox(height: 8),
            TextButton(onPressed: () => context.pushReplacement('/registro'), child: const Text('Crear una cuenta nueva')),
          ],
        ),
      );
}

/// 4 · Elegir cómo entrar
class ElegirEntrada extends StatelessWidget {
  const ElegirEntrada({super.key});

  Widget _opcion(BuildContext context, IconData icono, Color fondo, Color tinta, String titulo, String texto, String ruta) =>
      Tarjeta(
        onTap: () => context.push(ruta),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
            child: Icon(icono, color: tinta),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: T.heading),
            Text(texto, style: T.caption),
          ])),
          const Icon(Icons.chevron_right, color: C.inkMuted),
        ]),
      );

  @override
  Widget build(BuildContext context) => Pantalla(
        titulo: 'Cómo entrar al curso',
        atras: Navigator.of(context).canPop(),
        children: [
          const Titulo('¿Cómo llegas al curso?', sub: 'Elige una opción. Luego puedes sumar otros cursos.'),
          _opcion(context, Icons.add_circle_outline, C.lila, C.lilaStrong, 'Crear un curso', 'Soy asesor o padre delegado',
              '/crear-curso'),
          _opcion(context, Icons.family_restroom, C.menta, C.mentaInk, 'Soy papá o mamá', 'Tengo el código del curso',
              '/unirme/padre'),
          _opcion(context, Icons.co_present_outlined, C.cielo, C.cieloInk, 'Soy profesor de materia',
              'Tengo el código de invitación', '/unirme/profesor'),
          _opcion(context, Icons.qr_code_scanner, C.durazno, C.duraznoInk, 'Soy alumno', 'Tengo el QR de mi papá o mamá',
              '/alumno/escanear'),
          const AvisoCaja(
              'Solo el asesor o el padre delegado pueden crear un curso. No hace falta que el colegio contrate nada.',
              fondo: C.cielo,
              tinta: C.cieloInk,
              icono: Icons.info_outline),
        ],
      );
}

/// Pestañas que llegan en las fases siguientes del plan.
class Proximamente extends StatelessWidget {
  const Proximamente(this.titulo, this.icono, {super.key});
  final String titulo;
  final IconData icono;
  @override
  Widget build(BuildContext context) => Pantalla(
        titulo: titulo,
        atras: false,
        children: [Vacio('$titulo llega en la siguiente fase.', icono: icono)],
      );
}
