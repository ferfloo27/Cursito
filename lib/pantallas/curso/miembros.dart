import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

/// 12 · Miembros y roles (R-CU06, R-CU43, R-CU45; RN-CU02).
class Miembros extends StatefulWidget {
  const Miembros({super.key});
  @override
  State<Miembros> createState() => _MiembrosState();
}

class _Datos {
  _Datos(this.miembros, this.curso, this.alumnosConAcceso);
  final List<Map<String, dynamic>> miembros;
  final Map<String, dynamic> curso;
  final int alumnosConAcceso;
}

class _MiembrosState extends State<Miembros> {
  int _version = 0;
  CursoMio get _c => sesion.curso!;

  Future<_Datos> _cargar() async {
    final m = await supa
        .from('miembros_curso')
        .select('id, rol, es_tesorero, es_delegado, usuario_id, perfil:perfiles(nombre), profesor:profesores_curso(materia:materias(nombre))')
        .eq('curso_id', _c.id);
    final c = await supa.from('cursos').select('codigo, codigo_profesor').eq('id', _c.id).single();
    final al = await supa.from('alumnos').select('id').eq('curso_id', _c.id).not('usuario_alumno_id', 'is', null);
    return _Datos(List<Map<String, dynamic>>.from(m), c, (al as List).length);
  }

  void _recargar() => setState(() => _version++);

  static String nombre(Map<String, dynamic> m) => (m['perfil'] as Map?)?['nombre'] as String? ?? '—';
  static String? materia(Map<String, dynamic> m) {
    final p = m['profesor'];
    final fila = p is List ? (p.isEmpty ? null : p.first) : p;
    return ((fila as Map?)?['materia'] as Map?)?['nombre'] as String?;
  }

  Future<void> _cambiarTesorero(List<Map<String, dynamic>> miembros) async {
    final candidatos = miembros.where((m) => (m['rol'] == 'asesor' || m['rol'] == 'padre') && m['es_tesorero'] != true).toList()
      ..sort((a, b) => nombre(a).compareTo(nombre(b)));
    final elegido = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
          Text('Nuevo tesorero', style: T.title),
          const SizedBox(height: 4),
          Text('Los comprobantes en revisión pasan al nuevo tesorero. El QR de cobro actual se quita y el nuevo sube el suyo.',
              style: T.caption),
          const SizedBox(height: 8),
          for (final m in candidatos)
            ListTile(
              title: Text(nombre(m), style: T.heading),
              subtitle: Text(m['rol'] == 'asesor' ? 'Asesor' : 'Padre', style: T.caption),
              onTap: () => Navigator.pop(c, m),
            ),
        ]),
      ),
    );
    if (elegido == null || !mounted) return;
    if (await intentar(context, () => supa.rpc('designar_tesorero', params: {'p_miembro': elegido['id']}))) {
      await sesion.recargarCursos();
      if (mounted) avisar(context, '${nombre(elegido)} ahora es el tesorero.');
      _recargar();
    }
  }

  Future<void> _darAsesor(Map<String, dynamic> m) async {
    if (!await confirmar(context, 'Dar rol de asesor', '¿${nombre(m)} será el asesor del curso?', si: 'Dar rol')) return;
    if (!mounted) return;
    if (await intentar(context, () => supa.rpc('asignar_asesor', params: {'p_miembro': m['id']}))) {
      if (mounted) avisar(context, '${nombre(m)} ahora es el asesor del curso.');
      _recargar();
    }
  }

  Future<void> _regenerar(String para) async {
    if (!await confirmar(context, 'Generar código nuevo',
        'El código anterior para ${para == 'padres' ? 'padres' : 'profesores'} dejará de servir.', si: 'Generar')) {
      return;
    }
    if (!mounted) return;
    if (await intentar(context, () => supa.rpc('regenerar_codigo', params: {'p_curso': _c.id, 'p_para': para}))) {
      if (mounted) avisar(context, 'Código nuevo generado.');
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Miembros y roles')),
      body: Cargador<_Datos>(
        key: ValueKey(_version),
        cargar: _cargar,
        construir: (context, d, _) {
          final tesorero = d.miembros.where((m) => m['es_tesorero'] == true).firstOrNull;
          final docentes = d.miembros.where((m) => m['rol'] == 'asesor' || m['rol'] == 'profesor').toList()
            ..sort((a, b) => a['rol'] == 'asesor' ? -1 : (b['rol'] == 'asesor' ? 1 : nombre(a).compareTo(nombre(b))));
          final padres = d.miembros.where((m) => m['rol'] == 'padre').length;
          final hayAsesor = docentes.any((m) => m['rol'] == 'asesor');
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('${_c.nombre} · ${_c.colegio}', style: T.title),
            const Seccion('Tesorero'),
            Tarjeta(
              color: C.menta,
              child: Row(children: [
                const Icon(Icons.account_balance_wallet_outlined, color: C.mentaInk),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tesorero == null ? 'Sin tesorero' : nombre(tesorero), style: T.heading),
                  Text('Solo hay un tesorero activo. Es quien ve quién debe.', style: T.caption.copyWith(color: C.mentaInk)),
                ])),
                if (_c.gestiona) TextButton(onPressed: () => _cambiarTesorero(d.miembros), child: const Text('Cambiar')),
              ]),
            ),
            Seccion('Docentes (${docentes.length})'),
            for (final m in docentes)
              Tarjeta(
                padding: 12,
                child: Row(children: [
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nombre(m), style: T.heading),
                    Text([if (m['rol'] == 'asesor') 'Asesor del curso' else 'Profesor de materia', ?materia(m)].join(' · '),
                        style: T.caption),
                  ])),
                  if (m['rol'] == 'asesor') const Chip2('Asesor'),
                  if (m['rol'] == 'profesor' && _c.esDelegado && !hayAsesor)
                    TextButton(onPressed: () => _darAsesor(m), child: const Text('Dar rol de asesor')),
                ]),
              ),
            const SizedBox(height: 4),
            Text('$padres padres · ${d.alumnosConAcceso} alumnos con acceso', style: T.label),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => SharePlus.instance.share(ShareParams(
                  text: 'Te invito a ${_c.nombre} (${_c.colegio}) en Cursito. '
                      'Entra como profesor de materia con el código ${d.curso['codigo_profesor']}.')),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Invitar profesor de materia'),
            ),
            if (_c.esAsesor) ...[
              const Seccion('Gestionar el curso'),
              Tarjeta(
                padding: 4,
                child: Column(children: [
                  ListTile(
                    title: const Text('Código para padres'),
                    subtitle: Text('${d.curso['codigo']}'),
                    trailing: TextButton(onPressed: () => _regenerar('padres'), child: const Text('Generar nuevo')),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Código para profesores'),
                    subtitle: Text('${d.curso['codigo_profesor']}'),
                    trailing: TextButton(onPressed: () => _regenerar('profesores'), child: const Text('Generar nuevo')),
                  ),
                ]),
              ),
              Text('Para desvincular a un padre que eligió mal, entra a la nómina.', style: T.caption),
            ],
          ]);
        },
      ),
    );
  }
}
