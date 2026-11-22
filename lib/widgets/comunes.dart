import 'package:flutter/material.dart';

import '../core/errores.dart';
import '../core/tema.dart';

/// Pantalla con barra superior y contenido desplazable con margen de 16 px.
class Pantalla extends StatelessWidget {
  const Pantalla({super.key, this.titulo, required this.children, this.abajo, this.acciones, this.atras = true});
  final String? titulo;
  final List<Widget> children;
  final Widget? abajo;
  final List<Widget>? acciones;
  final bool atras;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: titulo == null && !atras
          ? null
          : AppBar(title: titulo == null ? null : Text(titulo!), automaticallyImplyLeading: atras, actions: acciones),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: children),
      ),
      bottomNavigationBar: abajo == null
          ? null
          : SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: abajo)),
    );
  }
}

class Titulo extends StatelessWidget {
  const Titulo(this.texto, {super.key, this.sub});
  final String texto;
  final String? sub;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(texto, style: T.display),
          if (sub != null) ...[const SizedBox(height: 8), Text(sub!, style: T.body.copyWith(color: C.inkMuted))],
        ]),
      );
}

class Seccion extends StatelessWidget {
  const Seccion(this.texto, {super.key, this.accion});
  final String texto;
  final Widget? accion;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Row(children: [Expanded(child: Text(texto, style: T.title)), ?accion]),
      );
}

class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key});
  final String texto;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 6, top: 12), child: Text(texto.toUpperCase(), style: T.label));
}

class Campo extends StatelessWidget {
  const Campo({
    super.key,
    required this.etiqueta,
    required this.controller,
    this.ayuda,
    this.teclado,
    this.oculto = false,
    this.validar,
    this.mayusculas = false,
    this.lineas = 1,
    this.hint,
  });
  final String etiqueta;
  final TextEditingController controller;
  final String? ayuda, hint;
  final TextInputType? teclado;
  final bool oculto, mayusculas;
  final String? Function(String?)? validar;
  final int lineas;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Etiqueta(etiqueta),
        TextFormField(
          controller: controller,
          keyboardType: teclado,
          obscureText: oculto,
          validator: validar,
          minLines: lineas,
          maxLines: oculto ? 1 : (lineas == 1 ? 1 : lineas + 4),
          textCapitalization: mayusculas ? TextCapitalization.characters : TextCapitalization.sentences,
          style: T.body,
          decoration: InputDecoration(hintText: hint),
        ),
        if (ayuda != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(ayuda!, style: T.caption)),
      ]);
}

class Tarjeta extends StatelessWidget {
  const Tarjeta({super.key, required this.child, this.color = C.surfaceRaised, this.onTap, this.padding = 16});
  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final double padding;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(R.md),
              side: color == C.surfaceRaised ? const BorderSide(color: C.line) : BorderSide.none),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: EdgeInsets.all(padding), child: child)),
        ),
      );
}

class Chip2 extends StatelessWidget {
  const Chip2(this.texto, {super.key, this.fondo = C.lila, this.tinta = C.ink});
  final String texto;
  final Color fondo, tinta;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
        child: Text(texto.toUpperCase(), style: T.label.copyWith(color: tinta, fontSize: 11)),
      );
}

class AvisoCaja extends StatelessWidget {
  const AvisoCaja(this.texto, {super.key, this.fondo = C.rosa, this.tinta = C.rosaInk, this.icono = Icons.error_outline});
  final String texto;
  final Color fondo, tinta;
  final IconData icono;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(R.md)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icono, color: tinta, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: T.body.copyWith(color: tinta))),
        ]),
      );
}

/// Botón principal con estado de envío (se deshabilita mientras se envía).
class BotonPrincipal extends StatelessWidget {
  const BotonPrincipal(this.texto, {super.key, required this.onPressed, this.cargando = false, this.icono});
  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;
  final IconData? icono;
  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: cargando ? null : onPressed,
        child: cargando
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (icono != null) ...[Icon(icono, size: 20), const SizedBox(width: 8)],
                Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
              ]),
      );
}

class Cargando extends StatelessWidget {
  const Cargando({super.key});
  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
}

class Vacio extends StatelessWidget {
  const Vacio(this.texto, {super.key, this.icono = Icons.inbox_outlined});
  final String texto;
  final IconData icono;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(children: [
          Icon(icono, color: C.inkMuted, size: 36),
          const SizedBox(height: 8),
          Text(texto, style: T.body.copyWith(color: C.inkMuted), textAlign: TextAlign.center),
        ]),
      );
}

class ErrorConReintento extends StatelessWidget {
  const ErrorConReintento(this.error, {super.key, required this.reintentar});
  final Object error;
  final VoidCallback reintentar;
  @override
  Widget build(BuildContext context) => Column(children: [
        AvisoCaja(mensajeDeError(error)),
        const SizedBox(height: 8),
        TextButton(onPressed: reintentar, child: const Text('Reintentar')),
      ]);
}

/// Carga datos con FutureBuilder y muestra cargando / error con reintento.
class Cargador<D> extends StatefulWidget {
  const Cargador({super.key, required this.cargar, required this.construir});
  final Future<D> Function() cargar;
  final Widget Function(BuildContext, D, VoidCallback recargar) construir;
  @override
  State<Cargador<D>> createState() => _CargadorState<D>();
}

class _CargadorState<D> extends State<Cargador<D>> {
  late Future<D> _f = widget.cargar();
  void _recargar() => setState(() => _f = widget.cargar());
  @override
  Widget build(BuildContext context) => FutureBuilder<D>(
        future: _f,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) return const Cargando();
          if (s.hasError) return ErrorConReintento(s.error!, reintentar: _recargar);
          return widget.construir(context, s.data as D, _recargar);
        },
      );
}

void avisar(BuildContext context, String texto) =>
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(texto)));

/// Ejecuta una acción y muestra el error traducido si falla. Devuelve true si salió bien.
Future<bool> intentar(BuildContext context, Future<void> Function() accion) async {
  try {
    await accion();
    return true;
  } catch (e) {
    if (context.mounted) avisar(context, mensajeDeError(e));
    return false;
  }
}

Future<bool> confirmar(BuildContext context, String titulo, String texto, {String si = 'Sí', String no = 'Cancelar'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo, style: T.heading),
      content: Text(texto, style: T.body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(no)),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text(si)),
      ],
    ),
  );
  return r ?? false;
}
