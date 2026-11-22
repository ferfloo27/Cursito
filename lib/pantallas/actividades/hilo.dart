import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

/// Hilo de dudas y comentarios de una actividad (R-CU26, RN-CU09):
/// todos los miembros comentan (1 a 500 caracteres), nadie edita ni borra;
/// el asesor o el profesor de esa actividad ocultan, y los ocultos sólo los ven los docentes.
class HiloActividad extends StatefulWidget {
  const HiloActividad({super.key, required this.actividad});
  final Map<String, dynamic> actividad;
  @override
  State<HiloActividad> createState() => _HiloActividadState();
}

class _Hilo {
  _Hilo(this.comentarios, this.roles, this.puedeOcultar);
  final List<Map<String, dynamic>> comentarios;
  final Map<String, String> roles;
  final bool puedeOcultar;
}

class _HiloActividadState extends State<HiloActividad> {
  final _texto = TextEditingController();
  bool _enviando = false;
  int _version = 0;
  CursoMio get _c => sesion.curso!;
  String get _id => widget.actividad['id'] as String;

  Future<_Hilo> _cargar() async {
    final f = await supa
        .from('comentarios')
        .select('id, texto, creado_en, oculto, oculto_en, autor_id, '
            'autor:perfiles!comentarios_autor_id_fkey(nombre, es_alumno), ocultador:perfiles!comentarios_oculto_por_fkey(nombre)')
        .eq('actividad_id', _id)
        .order('creado_en', ascending: true);
    final roles = <String, String>{};
    if (!_c.esAlumno) {
      final m = await supa.from('miembros_curso').select('usuario_id, rol').eq('curso_id', _c.id);
      for (final x in m) {
        roles[x['usuario_id'] as String] = x['rol'] as String;
      }
    }
    // El asesor, o el profesor de esa actividad (su autor o el de su materia): Q-CU-ACT-01
    var puede = _c.esAsesor;
    if (!puede && _c.esProfesor) {
      puede = widget.actividad['creado_por'] == sesion.usuario!.id;
      if (!puede && widget.actividad['materia_id'] != null) {
        final mia = await supa
            .from('profesores_curso')
            .select('materia_id, miembro:miembros_curso!inner(usuario_id)')
            .eq('miembro.usuario_id', sesion.usuario!.id)
            .eq('materia_id', widget.actividad['materia_id']);
        puede = (mia as List).isNotEmpty;
      }
    }
    return _Hilo(List<Map<String, dynamic>>.from(f), roles, puede);
  }

  Future<void> _enviar() async {
    final t = _texto.text.trim();
    if (t.isEmpty) return;
    if (t.length > 500) return avisar(context, 'El comentario puede tener hasta 500 caracteres.');
    setState(() => _enviando = true);
    final ok = await intentar(context, () => supa.from('comentarios').insert({'actividad_id': _id, 'texto': t}));
    if (!mounted) return;
    setState(() {
      _enviando = false;
      if (ok) {
        _texto.clear();
        _version++;
      }
    });
  }

  Future<void> _ocultar(Map<String, dynamic> c) async {
    if (!await confirmar(context, 'Ocultar comentario',
        'Dejará de verse para las familias y los alumnos. No se borra: queda registro de quién lo ocultó y cuándo.',
        si: 'Ocultar')) {
      return;
    }
    if (!mounted) return;
    if (await intentar(context, () => supa.rpc('ocultar_comentario', params: {'p_comentario': c['id']}))) {
      setState(() => _version++);
    }
  }

  String _rol(_Hilo h, Map<String, dynamic> c) {
    if (c['autor_id'] == sesion.usuario?.id) return 'Tú';
    final autor = c['autor'] as Map? ?? {};
    if (autor['es_alumno'] == true) return 'Alumno';
    return switch (h.roles[c['autor_id']]) {
      'asesor' => 'Asesor',
      'profesor' => 'Profesor',
      'padre' => 'Familia',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final evento = widget.actividad['tipo'] == 'evento';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Seccion('Dudas y comentarios', accion: Text(evento ? 'Solo de este evento' : 'Solo de esta tarea', style: T.caption)),
      Cargador<_Hilo>(
        key: ValueKey(_version),
        cargar: _cargar,
        construir: (context, h, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (h.comentarios.isEmpty) const Vacio('Todavía no hay comentarios. ¿Tienes una duda? Pregúntala aquí.', icono: Icons.forum_outlined),
          for (final c in h.comentarios) _comentario(h, c),
        ]),
      ),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: TextField(
            controller: _texto,
            minLines: 1,
            maxLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Escribe tu duda', counterText: ''),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Enviar',
          onPressed: _enviando ? null : _enviar,
          icon: _enviando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send),
        ),
      ]),
      const SizedBox(height: 6),
      Text('Los comentarios no se editan. La asesora o el profesor pueden ocultar los que no correspondan.', style: T.caption),
    ]);
  }

  Widget _comentario(_Hilo h, Map<String, dynamic> c) {
    final autor = (c['autor'] as Map?)?['nombre'] ?? '';
    final rol = _rol(h, c);
    final oculto = c['oculto'] == true;
    final cuando = DateTime.parse(c['creado_en'] as String);
    return Tarjeta(
      padding: 12,
      color: oculto ? C.rosa : (rol == 'Tú' ? C.lila : C.surfaceRaised),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: autor, style: T.heading.copyWith(fontSize: 15)),
              if (rol.isNotEmpty) TextSpan(text: ' · $rol', style: T.caption),
            ])),
          ),
          Text('${fechaCorta(cuando)} ${hora(cuando)}', style: T.caption),
        ]),
        const SizedBox(height: 4),
        Text(c['texto'] as String, style: T.body),
        if (oculto)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                'Oculto por ${(c['ocultador'] as Map?)?['nombre'] ?? ''} el ${fechaCorta(DateTime.parse(c['oculto_en'] as String))}'
                ' · solo lo ven los docentes',
                style: T.caption.copyWith(color: C.rosaInk)),
          )
        else if (h.puedeOcultar)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: C.rosaInk, minimumSize: const Size(44, 36)),
              onPressed: () => _ocultar(c),
              child: const Text('Ocultar'),
            ),
          ),
      ]),
    );
  }
}
