import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errores.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

/// Busca un curso por código y muestra lo que devuelve la RPC (RN-CU13).
mixin _BuscarPorCodigo<W extends StatefulWidget> on State<W> {
  final codigo = TextEditingController();
  bool buscando = false, enviando = false;
  String? error;
  List<Map<String, dynamic>>? filas;

  Future<void> buscar(String rpc) async {
    if (codigo.text.trim().isEmpty) return;
    setState(() {
      buscando = true;
      error = null;
      filas = null;
    });
    try {
      final r = await supa.rpc(rpc, params: {'p_codigo': codigo.text.trim()}) as List<dynamic>;
      setState(() => filas = r.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (e) {
      setState(() => error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => buscando = false);
    }
  }

  Future<void> unirme(String rpc, Map<String, dynamic> params) async {
    setState(() {
      enviando = true;
      error = null;
    });
    try {
      final cursoId = await supa.rpc(rpc, params: params) as String;
      await sesion.recargarCursos();
      sesion.elegirCurso(cursoId);
      if (mounted) context.go('/inicio');
    } catch (e) {
      setState(() => error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  Widget campoCodigo(String etiqueta, String hint, String rpc) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Campo(etiqueta: etiqueta, controller: codigo, hint: hint, mayusculas: true)),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(96, 48)),
            onPressed: buscando ? null : () => buscar(rpc),
            child: buscando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Buscar'),
          ),
        ),
      ]);

  Widget cursoEncontrado(Map<String, dynamic> f) => Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.lila, borderRadius: BorderRadius.circular(R.lg)),
        child: Row(children: [
          const Icon(Icons.school_outlined, color: C.lilaStrong),
          const SizedBox(width: 12),
          Expanded(child: Text('Curso encontrado: ${f['curso']} · ${f['colegio']}', style: T.heading)),
        ]),
      );
}

/// 8 · Unirme como padre (R-CU04): elige a su hijo entre los alumnos sin padre.
class UnirmePadre extends StatefulWidget {
  const UnirmePadre({super.key});
  @override
  State<UnirmePadre> createState() => _UnirmePadreState();
}

class _UnirmePadreState extends State<UnirmePadre> with _BuscarPorCodigo {
  String? _alumno;

  @override
  Widget build(BuildContext context) {
    final f = filas;
    final elegido = f?.where((a) => a['alumno_id'] == _alumno).firstOrNull;
    return Pantalla(
      titulo: 'Unirme como padre',
      abajo: elegido == null
          ? null
          : BotonPrincipal('Unirme como familia de ${(elegido['alumno'] as String).split(' ').last}',
              cargando: enviando,
              onPressed: () => unirme('unirme_como_padre', {'p_codigo': codigo.text.trim(), 'p_alumno': _alumno})),
      children: [
        const Titulo('Unirme al curso', sub: 'Escribe el código que te pasó el asesor o el delegado.'),
        campoCodigo('Código del curso', 'SAN4B7', 'nomina_por_codigo'),
        if (error != null) AvisoCaja(error!),
        if (f != null && f.isEmpty)
          const AvisoCaja('Todos los alumnos de este curso ya tienen un padre vinculado. Habla con el asesor.',
              fondo: C.durazno, tinta: C.duraznoInk, icono: Icons.info_outline),
        if (f != null && f.isNotEmpty) ...[
          cursoEncontrado(f.first),
          const Seccion('¿Quién es tu hijo o hija?'),
          Text('Solo aparecen los alumnos que todavía no tienen un padre vinculado.', style: T.caption),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _alumno,
            onChanged: (v) => setState(() => _alumno = v),
            child: Column(children: [
              for (final a in f)
                Tarjeta(
                  padding: 4,
                  color: _alumno == a['alumno_id'] ? C.lila : C.surfaceRaised,
                  child: RadioListTile<String>(value: a['alumno_id'] as String, title: Text(a['alumno'] as String, style: T.heading)),
                ),
            ]),
          ),
        ],
      ],
    );
  }
}

/// 9 · Unirme como profesor de materia (R-CU05): una materia de la lista fija, una por curso.
class UnirmeProfesor extends StatefulWidget {
  const UnirmeProfesor({super.key});
  @override
  State<UnirmeProfesor> createState() => _UnirmeProfesorState();
}

class _UnirmeProfesorState extends State<UnirmeProfesor> with _BuscarPorCodigo {
  String? _materia;

  @override
  Widget build(BuildContext context) {
    final f = filas;
    final elegida = f?.where((m) => m['materia_id'] == _materia).firstOrNull;
    return Pantalla(
      titulo: 'Unirme como profesor',
      abajo: elegida == null
          ? null
          : BotonPrincipal('Unirme como profesor de ${elegida['materia']}',
              cargando: enviando,
              onPressed: () => unirme('unirme_como_profesor', {'p_codigo': codigo.text.trim(), 'p_materia': _materia})),
      children: [
        const Titulo('Soy profesor de materia', sub: 'Escribe el código de invitación que te pasó el asesor.'),
        campoCodigo('Código de invitación', 'PRF-K2Q9', 'materias_por_codigo_profesor'),
        if (error != null) AvisoCaja(error!),
        if (f != null && f.isNotEmpty) ...[
          cursoEncontrado(f.first),
          const Seccion('¿Qué materia das en este curso?'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in f)
              ChoiceChip(
                label: Text(m['ocupada'] == true ? '${m['materia']} · ocupada' : m['materia'] as String),
                selected: _materia == m['materia_id'],
                onSelected: m['ocupada'] == true ? null : (_) => setState(() => _materia = m['materia_id'] as String),
              ),
          ]),
          const Etiqueta('Contacto visible para los padres'),
          Tarjeta(
            child: Row(children: [
              const Icon(Icons.mail_outline, color: C.inkMuted),
              const SizedBox(width: 8),
              Expanded(child: Text(sesion.usuario?.email ?? '', style: T.body)),
            ]),
          ),
          Text('Aparecerá en el directorio de profesores del curso.', style: T.caption),
        ],
      ],
    );
  }
}
