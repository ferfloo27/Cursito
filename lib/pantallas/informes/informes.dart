import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

/// Períodos del informe (Q-CU-INF-02): tres por gestión.
const periodosInforme = ['1.er trimestre', '2.º trimestre', '3.er trimestre'];

/// Las cinco áreas de la libreta (RF-C03, RN-CU11).
const areasInforme = {
  'rendimiento': 'Rendimiento',
  'conducta': 'Conducta',
  'participacion': 'Participación',
  'puntualidad': 'Puntualidad',
  'tareas': 'Tareas',
};

/// En pantalla, «por_mejorar» se llama «Necesita mejorar» (Q-CU-INF-04).
const _calificaciones = {'bueno': 'Bueno', 'regular': 'Regular', 'por_mejorar': 'Necesita mejorar'};

const _selectInforme =
    'id, alumno_id, periodo, rendimiento, conducta, participacion, puntualidad, tareas, observaciones, enviado_en, leido_en';

/// Lista de alumnos del período (sólo el asesor redacta; el profesor sólo lee el estado).
class ListaInformes extends StatefulWidget {
  const ListaInformes({super.key});
  @override
  State<ListaInformes> createState() => _ListaInformesState();
}

class _ListaInformesState extends State<ListaInformes> {
  String _periodo = periodosInforme.first;
  VoidCallback? _refrescar;

  CursoMio get _c => sesion.curso!;

  Future<({List<Map<String, dynamic>> alumnos, Map<String, Map<String, dynamic>> informes})> _cargar() async {
    final al = await supa.from('alumnos').select('id, apellidos, nombres').eq('curso_id', _c.id).order('apellidos');
    final alumnos = [for (final a in al as List) Map<String, dynamic>.from(a as Map)];
    final ids = [for (final a in alumnos) a['id'] as String];
    final informes = <String, Map<String, dynamic>>{};
    if (ids.isNotEmpty) {
      final inf = await supa.from('informes_alumno').select(_selectInforme).eq('periodo', _periodo).inFilter('alumno_id', ids);
      for (final i in inf as List) {
        final m = Map<String, dynamic>.from(i as Map);
        informes[m['alumno_id'] as String] = m;
      }
    }
    return (alumnos: alumnos, informes: informes);
  }

  String _estado(Map<String, dynamic>? i) {
    if (i == null) return 'Sin redactar';
    if (i['leido_en'] != null) return 'Leído por la familia';
    if (i['enviado_en'] == null) return 'Borrador';
    return 'Enviado';
  }

  @override
  Widget build(BuildContext context) {
    return Cargador<({List<Map<String, dynamic>> alumnos, Map<String, Map<String, dynamic>> informes})>(
      cargar: _cargar,
      construir: (context, d, recargar) {
        _refrescar = recargar;
        return Pantalla(
          titulo: 'Informes',
          children: [
            Titulo('Informes del curso', sub: _c.esAsesor
                ? 'Redacta la libreta de cada alumno. Solo la ve su familia.'
                : 'Puedes ver el estado de los informes. Solo el asesor los redacta.'),
            Wrap(spacing: 8, children: [
              for (final p in periodosInforme)
                ChoiceChip(
                  label: Text(p),
                  selected: _periodo == p,
                  onSelected: (_) {
                    setState(() => _periodo = p);
                    _refrescar?.call();
                  },
                ),
            ]),
            const SizedBox(height: 8),
            if (d.alumnos.isEmpty) const Vacio('Aún no hay alumnos en la nómina.', icono: Icons.groups_outlined),
            for (final a in d.alumnos)
              Tarjeta(
                onTap: () async {
                  final i = d.informes[a['id']];
                  final guardado = await context.push<bool>('/informes/redactar', extra: {
                    'alumno_id': a['id'],
                    'alumno': '${a['apellidos']} ${a['nombres']}',
                    'periodo': _periodo,
                    'existente': i,
                  });
                  if (guardado == true) recargar();
                },
                child: Row(children: [
                  Expanded(
                    child: Text('${a['apellidos']} ${a['nombres']}', style: T.heading),
                  ),
                  Text(_estado(d.informes[a['id']]), style: T.caption),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: C.inkMuted),
                ]),
              ),
          ],
        );
      },
    );
  }
}

/// Redactar o corregir el informe de un alumno (RN-CU11). Se puede guardar borrador; al enviar, la familia lo ve.
class RedactarInforme extends StatefulWidget {
  const RedactarInforme({super.key, required this.datos});
  final Map<String, dynamic> datos; // alumno_id, alumno, periodo, existente
  @override
  State<RedactarInforme> createState() => _RedactarInformeState();
}

class _RedactarInformeState extends State<RedactarInforme> {
  late final Map<String, dynamic>? _existente = widget.datos['existente'] as Map<String, dynamic>?;
  late final Map<String, String?> _valores = {
    for (final k in areasInforme.keys) k: _existente?[k] as String?,
  };
  late final _obs = TextEditingController(text: _existente?['observaciones'] as String? ?? '');
  bool _enviando = false;
  String? _error;

  CursoMio get _c => sesion.curso!;
  bool get _soloLectura => !_c.esAsesor || _existente?['leido_en'] != null;

  Future<void> _guardar({required bool enviar}) async {
    if (enviar && _valores.values.any((v) => v == null)) {
      return setState(() => _error = 'Marca las cinco áreas antes de enviar.');
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    final datos = <String, dynamic>{
      ..._valores,
      'observaciones': _obs.text.trim().isEmpty ? null : _obs.text.trim(),
    };
    final ahora = DateTime.now().toUtc().toIso8601String();
    final ok = await intentar(context, () async {
      if (_existente == null) {
        await supa.from('informes_alumno').insert({
          'alumno_id': widget.datos['alumno_id'],
          'periodo': widget.datos['periodo'],
          ...datos,
          if (enviar) 'enviado_en': ahora,
        });
      } else {
        await supa.from('informes_alumno').update({
          ...datos,
          if (enviar) 'enviado_en': ahora,
        }).eq('id', _existente['id']);
      }
    });
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok) {
      avisar(context, enviar ? 'Informe enviado a la familia.' : 'Borrador guardado.');
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lectura = _soloLectura;
    return Pantalla(
      titulo: 'Informe',
      abajo: lectura
          ? null
          : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              BotonPrincipal('Enviar a la familia', icono: Icons.send, cargando: _enviando, onPressed: () => _guardar(enviar: true)),
              TextButton(
                onPressed: _enviando ? null : () => _guardar(enviar: false),
                child: const Text('Guardar borrador'),
              ),
            ]),
      children: [
        Titulo(widget.datos['alumno'] as String, sub: widget.datos['periodo'] as String),
        if (_existente?['leido_en'] != null)
          const AvisoCaja('La familia ya leyó el informe: no se puede corregir.',
              fondo: C.cielo, tinta: C.cieloInk, icono: Icons.visibility_outlined)
        else if (!_c.esAsesor)
          const AvisoCaja('Solo el asesor redacta los informes. Aquí puedes ver el estado.',
              fondo: C.cielo, tinta: C.cieloInk, icono: Icons.info_outline),
        for (final e in areasInforme.entries) ...[
          Etiqueta(e.value),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in _calificaciones.entries)
              ChoiceChip(
                label: Text(c.value),
                selected: _valores[e.key] == c.key,
                onSelected: lectura ? null : (_) => setState(() => _valores[e.key] = c.key),
              ),
          ]),
        ],
        Campo(
          etiqueta: 'Observaciones',
          controller: _obs,
          lineas: 3,
          hint: 'Lo que la familia debe saber',
        ),
        if (_error != null) AvisoCaja(_error!),
      ],
    );
  }
}

/// «Mi informe» del padre (RN-CU11): sólo los informes enviados de su hijo. Al abrirlo quedan marcados como leídos.
class MiInforme extends StatelessWidget {
  const MiInforme({super.key});

  CursoMio get _c => sesion.curso!;

  Future<List<Map<String, dynamic>>> _cargar() async {
    final f = await supa
        .from('informes_alumno')
        .select(_selectInforme)
        .eq('alumno_id', _c.hijoId!)
        .not('enviado_en', 'is', null)
        .order('enviado_en', ascending: false);
    final lista = [for (final i in f as List) Map<String, dynamic>.from(i as Map)];
    for (final i in lista.where((i) => i['leido_en'] == null)) {
      try {
        await supa.rpc('marcar_informe_leido', params: {'p_informe': i['id']});
      } catch (_) {
        // sin conexión: queda sin marcar y se intenta al volver a abrir
      }
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return Cargador<List<Map<String, dynamic>>>(
      cargar: _cargar,
      construir: (context, lista, _) => Pantalla(
        titulo: 'Mi informe',
        children: [
          Titulo('Informe de ${_c.hijoNombre}', sub: 'Lo redacta el asesor y solo tu familia lo ve.'),
          if (lista.isEmpty) const Vacio('Todavía no hay informes enviados.', icono: Icons.description_outlined),
          for (final i in lista)
            Tarjeta(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(i['periodo'] as String, style: T.heading),
                const SizedBox(height: 8),
                for (final e in areasInforme.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Expanded(child: Text(e.value, style: T.body)),
                      Text(_calificaciones[i[e.key]] ?? '—', style: T.heading),
                    ]),
                  ),
                if ((i['observaciones'] as String?)?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 6),
                  Text(i['observaciones'] as String, style: T.body.copyWith(color: C.inkMuted)),
                ],
              ]),
            ),
        ],
      ),
    );
  }
}
