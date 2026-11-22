import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

/// 7 · Nómina del curso (R-CU03): asesor o delegado cargan, corrigen y quitan alumnos.
/// Desvincular a un padre (R-CU44, Should) también vive aquí.
class Nomina extends StatefulWidget {
  const Nomina({super.key});
  @override
  State<Nomina> createState() => _NominaState();
}

class _NominaState extends State<Nomina> {
  final _nuevo = TextEditingController();
  final _clave = GlobalKey<State>();
  int _version = 0;

  CursoMio get _c => sesion.curso!;

  Future<List<Map<String, dynamic>>> _cargar() async {
    final filas = await supa
        .from('alumnos')
        .select('id, nombres, apellidos, padre_id, usuario_alumno_id, padre:perfiles!alumnos_padre_id_fkey(nombre)')
        .eq('curso_id', _c.id)
        .order('apellidos', ascending: true)
        .order('nombres', ascending: true);
    return List<Map<String, dynamic>>.from(filas);
  }

  void _recargar() => setState(() => _version++);

  Future<void> _agregar(List<String> lineas) async {
    final filas = <Map<String, dynamic>>[];
    final malas = <String>[];
    for (final l in lineas.where((l) => l.trim().isNotEmpty)) {
      final n = separarNombre(l);
      if (n == null) {
        malas.add(l.trim());
      } else {
        filas.add({'curso_id': _c.id, 'apellidos': n.apellidos, 'nombres': n.nombres});
      }
    }
    if (filas.isEmpty) {
      avisar(context, 'Escribe apellidos y nombres, por ejemplo «Condori Sofía».');
      return;
    }
    final ok = await intentar(context, () => supa.from('alumnos').insert(filas));
    if (!mounted) return;
    if (ok) {
      _nuevo.clear();
      avisar(context,
          '${filas.length == 1 ? 'Alumno agregado' : '${filas.length} alumnos agregados'}${malas.isEmpty ? '' : ' · sin agregar: ${malas.join(', ')}'}');
      _recargar();
    }
  }

  Future<void> _pegarLista() async {
    final t = TextEditingController();
    final lineas = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Pegar una lista completa', style: T.title),
          const SizedBox(height: 8),
          Text('Un alumno por línea: Apellidos Nombres.', style: T.caption),
          const SizedBox(height: 8),
          TextField(controller: t, minLines: 6, maxLines: 12, decoration: const InputDecoration(hintText: 'Condori Sofía\nGutiérrez Mateo')),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pop(c, t.text.split('\n')), child: const Text('Agregar a la nómina')),
        ]),
      ),
    );
    if (lineas != null) await _agregar(lineas);
  }

  Future<void> _editar(Map<String, dynamic> a) async {
    final ap = TextEditingController(text: a['apellidos'] as String);
    final no = TextEditingController(text: a['nombres'] as String);
    final guardar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Corregir nombre', style: T.heading),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Campo(etiqueta: 'Apellidos', controller: ap),
          Campo(etiqueta: 'Nombres', controller: no),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (guardar != true || !mounted) return;
    if (ap.text.trim().isEmpty || no.text.trim().isEmpty) return avisar(context, 'Escribe apellidos y nombres.');
    if (await intentar(context, () => supa.from('alumnos').update({'apellidos': ap.text.trim(), 'nombres': no.text.trim()}).eq('id', a['id']))) {
      _recargar();
    }
  }

  Future<void> _quitar(Map<String, dynamic> a) async {
    if (!await confirmar(context, 'Quitar de la nómina', '¿Quitar a ${a['nombres']} ${a['apellidos']} de la nómina?', si: 'Quitar')) {
      return;
    }
    if (!mounted) return;
    if (await intentar(context, () => supa.from('alumnos').delete().eq('id', a['id']))) _recargar();
  }

  Future<void> _desvincular(Map<String, dynamic> a) async {
    final padre = (a['padre'] as Map?)?['nombre'] ?? 'el padre';
    if (!await confirmar(context, 'Desvincular padre',
        '$padre dejará de estar ligado a ${a['nombres']} y podrá volver a elegir. Sus pagos y comentarios quedan registrados.',
        si: 'Desvincular')) {
      return;
    }
    if (!mounted) return;
    if (await intentar(context, () => supa.rpc('desvincular_padre', params: {'p_alumno': a['id']}))) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nómina del curso')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${_c.nombre} · ${_c.colegio}', style: T.title),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Campo(etiqueta: 'Nombre del alumno', controller: _nuevo, hint: 'Apellidos Nombres')),
          const SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
              onPressed: () => _agregar([_nuevo.text]),
              child: const Text('Agregar'),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Un alumno por línea: Apellidos Nombres.', style: T.caption),
        TextButton.icon(onPressed: _pegarLista, icon: const Icon(Icons.content_paste), label: const Text('Pegar una lista completa')),
        Cargador<List<Map<String, dynamic>>>(
          key: ValueKey(_version),
          cargar: _cargar,
          construir: (context, alumnos, _) {
            if (alumnos.isEmpty) return const Vacio('Todavía no hay alumnos. Agrega el primero o pega la lista.');
            final conPadre = alumnos.where((a) => a['padre_id'] != null).length;
            final vinculados = alumnos.where((a) => a['usuario_alumno_id'] != null).length;
            return Column(key: _clave, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 8),
              Text('Con padre: $conPadre de ${alumnos.length} · Alumno vinculado: $vinculados de ${alumnos.length}', style: T.label),
              const SizedBox(height: 8),
              for (final a in alumnos) _fila(a),
            ]);
          },
        ),
      ]),
    );
  }

  Widget _fila(Map<String, dynamic> a) {
    final padre = (a['padre'] as Map?)?['nombre'] as String?;
    final vinculado = a['usuario_alumno_id'] != null;
    final (estado, fondo, tinta) = vinculado
        ? ('Alumno vinculado', C.menta, C.mentaInk)
        : padre != null
            ? ('Solo padre', C.cielo, C.cieloInk)
            : ('Sin padre', C.durazno, C.duraznoInk);
    final puedeQuitar = padre == null && !vinculado;
    return Tarjeta(
      padding: 12,
      child: Row(children: [
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${a['apellidos']} ${a['nombres']}', style: T.heading),
          const SizedBox(height: 2),
          Text(padre ?? 'Sin padre todavía', style: T.caption),
          const SizedBox(height: 6),
          Chip2(estado, fondo: fondo, tinta: tinta),
        ])),
        PopupMenuButton<String>(
          tooltip: 'Opciones',
          onSelected: (v) => switch (v) { 'editar' => _editar(a), 'quitar' => _quitar(a), _ => _desvincular(a) },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'editar', child: Text('Editar nombre')),
            if (padre != null) const PopupMenuItem(value: 'desvincular', child: Text('Desvincular padre')),
            if (puedeQuitar) const PopupMenuItem(value: 'quitar', child: Text('Quitar de la nómina')),
          ],
        ),
      ]),
    );
  }
}
