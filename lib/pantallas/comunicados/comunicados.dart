import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errores.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

const _selectComunicado = 'id, curso_id, tipo, titulo, cuerpo, actividad_id, pide_enterado, autor_id, creado_en, '
    'autor:perfiles!comunicados_autor_id_fkey(nombre)';

const _avisosDeCuentas = {
  'cuota_nueva', 'cuota_anulada', 'pago_confirmado', 'gasto_registrado', 'votacion_abierta', 'votacion_cerrada', 'ajuste',
  'recordatorio_cuota',
};

String _tipoTexto(String t) => switch (t) { 'urgente' => 'Urgente', 'recordatorio' => 'Recordatorio', _ => 'Aviso' };

(Color, Color) _colores(String tipo) => switch (tipo) {
      'urgente' => (C.rosa, C.rosaInk), // rosa: sólo errores y Urgente
      'recordatorio' => (C.durazno, C.duraznoInk),
      _ => (C.cielo, C.cieloInk),
    };

/// Texto prefabricado para WhatsApp (R-CU24, Q-CU-COM-05): tipo, título, fecha, curso y «Mira los detalles en Cursito».
Future<void> compartirWhatsApp(BuildContext context, {required String tipo, required String titulo, required DateTime fecha}) async {
  final c = sesion.curso!;
  final texto = '${tipo.toUpperCase()}: $titulo\n${fechaHora(fecha)}\n${c.nombre} · ${c.colegio}\nMira los detalles en Cursito';
  final ok = await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texto)}'), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) avisar(context, 'No se pudo abrir WhatsApp.');
}

/// 19 · Muro del curso (R-CU23, R-CU36): comunicados y avisos automáticos, con filtro Todo · De profesores · De cuentas.
/// El Urgente sin leer queda arriba (R-CU48). El alumno no tiene muro (RN-CU04).
class Muro extends StatefulWidget {
  const Muro({super.key});
  @override
  State<Muro> createState() => _MuroState();
}

class _Item {
  _Item.comunicado(this.datos, this.leido) : esComunicado = true, fecha = DateTime.parse(datos['creado_en'] as String);
  _Item.aviso(this.datos) : esComunicado = false, leido = true, fecha = DateTime.parse(datos['creado_en'] as String);
  final Map<String, dynamic> datos;
  final bool esComunicado, leido;
  final DateTime fecha;
  bool get urgenteSinLeer => esComunicado && datos['tipo'] == 'urgente' && !leido;
}

class _MuroState extends State<Muro> {
  String _filtro = 'todo';
  int _version = 0;
  CursoMio get _c => sesion.curso!;

  Future<List<_Item>> _cargar() async {
    final com = await supa.from('comunicados').select(_selectComunicado).eq('curso_id', _c.id).order('creado_en', ascending: false);
    final lec = await supa.from('lecturas_comunicado').select('comunicado_id').eq('usuario_id', sesion.usuario!.id);
    final leidos = {for (final l in lec) l['comunicado_id'] as String};
    final av = await supa
        .from('avisos')
        .select('id, tipo, texto, ref_tabla, ref_id, destinatario_id, creado_en')
        .eq('curso_id', _c.id)
        .order('creado_en', ascending: false)
        .limit(100);
    final items = [
      for (final c in com)
        _Item.comunicado(c, leidos.contains(c['id']) || c['autor_id'] == sesion.usuario!.id || !_c.esPadre),
      for (final a in av) _Item.aviso(a),
    ]..sort((a, b) {
        if (a.urgenteSinLeer != b.urgenteSinLeer) return a.urgenteSinLeer ? -1 : 1;
        return b.fecha.compareTo(a.fecha);
      });
    return items;
  }

  bool _pasa(_Item i) => switch (_filtro) {
        'profesores' => i.esComunicado || !_avisosDeCuentas.contains(i.datos['tipo']),
        'cuentas' => !i.esComunicado && _avisosDeCuentas.contains(i.datos['tipo']),
        _ => true,
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Muro'), automaticallyImplyLeading: false),
        floatingActionButton: _c.esDocente
            ? FloatingActionButton.extended(
                onPressed: () async {
                  final ok = await context.push<bool>('/comunicados/nuevo');
                  if (ok == true) setState(() => _version++);
                },
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Nuevo comunicado'),
              )
            : null,
        body: RefreshIndicator(
          onRefresh: () async => setState(() => _version++),
          child: Cargador<List<_Item>>(
            key: ValueKey('${_c.id}-$_version'),
            cargar: _cargar,
            construir: (context, items, _) {
              final vista = items.where(_pasa).toList();
              return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
                Text('${_c.nombre} · ${_c.colegio}', style: T.caption),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final f in const [('todo', 'Todo'), ('profesores', 'De profesores'), ('cuentas', 'De cuentas')])
                    ChoiceChip(label: Text(f.$2), selected: _filtro == f.$1, onSelected: (_) => setState(() => _filtro = f.$1)),
                ]),
                const SizedBox(height: 12),
                if (vista.isEmpty) const Vacio('Todavía no hay nada en el muro.', icono: Icons.forum_outlined),
                for (final i in vista) i.esComunicado ? _comunicado(i) : _aviso(i),
              ]);
            },
          ),
        ),
      );

  Widget _comunicado(_Item i) {
    final c = i.datos;
    final (fondo, tinta) = _colores(c['tipo'] as String);
    return Tarjeta(
      onTap: () async {
        await context.push('/comunicado/${c['id']}');
        if (mounted) setState(() => _version++);
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Chip2(_tipoTexto(c['tipo'] as String), fondo: fondo, tinta: tinta),
          const SizedBox(width: 6),
          if (_c.esPadre && c['pide_enterado'] == true)
            i.leido
                ? const Chip2('Enterado', fondo: C.menta, tinta: C.mentaInk)
                : const Chip2('Sin leer', fondo: C.durazno, tinta: C.duraznoInk),
          const Spacer(),
          Text('${fechaCorta(i.fecha)} ${hora(i.fecha)}', style: T.caption),
        ]),
        const SizedBox(height: 8),
        Text(c['titulo'] as String, style: T.heading),
        const SizedBox(height: 2),
        Text(c['cuerpo'] as String, style: T.body, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text((c['autor'] as Map?)?['nombre'] as String? ?? '', style: T.caption),
      ]),
    );
  }

  Widget _aviso(_Item i) {
    final a = i.datos;
    final cuentas = _avisosDeCuentas.contains(a['tipo']);
    final votacion = a['tipo'] == 'votacion_abierta';
    final privado = a['destinatario_id'] != null;
    final etiqueta = votacion
        ? 'Votación abierta · Cuentas'
        : privado
            ? 'Solo para ti'
            : cuentas
                ? 'Aviso automático · Cuentas'
                : 'Aviso automático';
    return Tarjeta(
      color: votacion ? C.durazno : (cuentas ? C.menta : C.surfaceRaised),
      padding: 12,
      child: Row(children: [
        Icon(cuentas ? Icons.account_balance_wallet_outlined : Icons.notifications_none,
            color: votacion ? C.duraznoInk : (cuentas ? C.mentaInk : C.inkMuted)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(etiqueta.toUpperCase(), style: T.label.copyWith(fontSize: 11, color: votacion ? C.duraznoInk : (cuentas ? C.mentaInk : C.inkMuted))),
            Text(a['texto'] as String, style: T.body),
            Text('${fechaCorta(i.fecha)} ${hora(i.fecha)}', style: T.caption),
          ]),
        ),
        IconButton(
          tooltip: 'Compartir por WhatsApp',
          icon: const Icon(Icons.share_outlined, size: 20),
          onPressed: () => compartirWhatsApp(context, tipo: 'Aviso', titulo: a['texto'] as String, fecha: i.fecha),
        ),
      ]),
    );
  }
}

/// 21 · Nuevo comunicado (R-CU20, R-CU21): tipo, título, mensaje, «Pedir Enterado» (Q-CU-COM-02). No se edita después.
class NuevoComunicado extends StatefulWidget {
  const NuevoComunicado({super.key});
  @override
  State<NuevoComunicado> createState() => _NuevoComunicadoState();
}

class _NuevoComunicadoState extends State<NuevoComunicado> {
  final _form = GlobalKey<FormState>();
  final _titulo = TextEditingController(), _cuerpo = TextEditingController();
  String _tipo = 'aviso';
  String? _actividad;
  bool _enterado = true, _enviando = false;
  String? _error;
  CursoMio get _c => sesion.curso!;

  late final Future<(int, List<Map<String, dynamic>>)> _datos = () async {
    final al = await supa.from('alumnos').select('id').eq('curso_id', _c.id);
    final act = await supa
        .from('actividades')
        .select('id, titulo, fecha')
        .eq('curso_id', _c.id)
        .isFilter('cancelada_en', null)
        .gte('fecha', DateTime.now().toUtc().toIso8601String())
        .order('fecha', ascending: true);
    return ((al as List).length, List<Map<String, dynamic>>.from(act));
  }();

  Future<void> _publicar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await supa.from('comunicados').insert({
        'curso_id': _c.id,
        'tipo': _tipo,
        'titulo': _titulo.text.trim(),
        'cuerpo': _cuerpo.text.trim(),
        'actividad_id': _actividad,
        'pide_enterado': _enterado,
      });
      if (mounted) context.pop(true);
    } catch (e) {
      setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(int, List<Map<String, dynamic>>)>(
        future: _datos,
        builder: (context, s) {
          final familias = s.data?.$1;
          return Form(
            key: _form,
            child: Pantalla(
              titulo: 'Nuevo comunicado',
              abajo: BotonPrincipal(familias == null ? 'Publicar' : 'Publicar a las $familias familias',
                  onPressed: _publicar, cargando: _enviando),
              children: [
                const Titulo('Nuevo comunicado'),
                const Etiqueta('Tipo'),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'aviso', label: Text('Aviso')),
                    ButtonSegment(value: 'recordatorio', label: Text('Recordatorio')),
                    ButtonSegment(value: 'urgente', label: Text('Urgente')),
                  ],
                  selected: {_tipo},
                  onSelectionChanged: (v) => setState(() => _tipo = v.first),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      switch (_tipo) {
                        'urgente' => 'Queda arriba del muro de cada familia hasta que lo lea.',
                        'recordatorio' => 'Para recordar algo ya anunciado.',
                        _ => 'Información general para las familias.',
                      },
                      style: T.caption),
                ),
                Campo(
                    etiqueta: 'Título',
                    controller: _titulo,
                    validar: (v) => (v ?? '').trim().isEmpty ? 'Escribe el título' : null),
                Campo(
                    etiqueta: 'Mensaje',
                    controller: _cuerpo,
                    lineas: 4,
                    validar: (v) => (v ?? '').trim().isEmpty ? 'Escribe el mensaje' : null),
                if ((s.data?.$2 ?? []).isNotEmpty) ...[
                  const Etiqueta('Sobre una actividad (opcional)'),
                  DropdownButtonFormField<String?>(
                    initialValue: _actividad,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Ninguna')),
                      for (final a in s.data!.$2)
                        DropdownMenuItem(value: a['id'] as String, child: Text(a['titulo'] as String, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _actividad = v),
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Pedir «Enterado»', style: T.body),
                  subtitle: Text('Verás quién lo leyó', style: T.caption),
                  value: _enterado,
                  onChanged: (v) => setState(() => _enterado = v),
                ),
                const AvisoCaja('Un comunicado publicado no se edita. Si hace falta, publica uno nuevo.',
                    fondo: C.cielo, tinta: C.cieloInk, icono: Icons.info_outline),
                if (_error != null) AvisoCaja(_error!),
              ],
            ),
          );
        },
      );
}

/// 20 · Detalle de comunicado: «Enterado» del padre (una vez, no se deshace), WhatsApp y, para el autor o el asesor, «Quién leyó».
class DetalleComunicado extends StatefulWidget {
  const DetalleComunicado({super.key, required this.id});
  final String id;
  @override
  State<DetalleComunicado> createState() => _DetalleComunicadoState();
}

class _DetalleComunicadoState extends State<DetalleComunicado> {
  int _version = 0;
  bool _enviando = false;
  CursoMio get _c => sesion.curso!;

  Future<(Map<String, dynamic>, Map<String, dynamic>?)> _cargar() async {
    final c = await supa.from('comunicados').select(_selectComunicado).eq('id', widget.id).single();
    final l = await supa
        .from('lecturas_comunicado')
        .select('leido_en')
        .eq('comunicado_id', widget.id)
        .eq('usuario_id', sesion.usuario!.id)
        .maybeSingle();
    return (c, l);
  }

  Future<void> _enterado() async {
    setState(() => _enviando = true);
    final ok = await intentar(context, () => supa.from('lecturas_comunicado').insert({'comunicado_id': widget.id}));
    if (!mounted) return;
    setState(() {
      _enviando = false;
      if (ok) _version++;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Comunicado')),
        body: Cargador<(Map<String, dynamic>, Map<String, dynamic>?)>(
          key: ValueKey(_version),
          cargar: _cargar,
          construir: (context, d, _) {
            final c = d.$1;
            final lectura = d.$2;
            final fecha = DateTime.parse(c['creado_en'] as String);
            final (fondo, tinta) = _colores(c['tipo'] as String);
            final soyAutor = c['autor_id'] == sesion.usuario!.id;
            return ListView(padding: const EdgeInsets.all(16), children: [
              Align(alignment: Alignment.centerLeft, child: Chip2(_tipoTexto(c['tipo'] as String), fondo: fondo, tinta: tinta)),
              const SizedBox(height: 8),
              Text(c['titulo'] as String, style: T.display),
              const SizedBox(height: 4),
              Text('${(c['autor'] as Map?)?['nombre'] ?? ''} · ${fechaHora(fecha)}', style: T.caption),
              const SizedBox(height: 16),
              Text(c['cuerpo'] as String, style: T.body),
              if (c['actividad_id'] != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push('/actividad/${c['actividad_id']}'),
                  icon: const Icon(Icons.event_note_outlined),
                  label: const Text('Ir a la actividad'),
                ),
              ],
              if (_c.esPadre && c['pide_enterado'] == true) ...[
                const SizedBox(height: 24),
                if (lectura == null) ...[
                  Text('${(c['autor'] as Map?)?['nombre'] ?? 'El docente'} quiere saber que lo leíste.', style: T.caption),
                  const SizedBox(height: 8),
                  BotonPrincipal('Enterado', icono: Icons.check, onPressed: _enterado, cargando: _enviando),
                ] else
                  AvisoCaja(
                      'Marcaste Enterado · ${fechaHora(DateTime.parse(lectura['leido_en'] as String))} · no se puede deshacer',
                      fondo: C.menta,
                      tinta: C.mentaInk,
                      icono: Icons.check_circle_outline),
              ],
              if ((soyAutor || _c.esAsesor) && c['pide_enterado'] == true) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.push('/comunicado/${widget.id}/lectores', extra: c['titulo']),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Quién leyó'),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => compartirWhatsApp(context, tipo: _tipoTexto(c['tipo'] as String), titulo: c['titulo'] as String, fecha: fecha),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Compartir por WhatsApp'),
              ),
              const SizedBox(height: 4),
              Text('Se comparte un resumen del aviso, sin datos de otras familias.', style: T.caption, textAlign: TextAlign.center),
            ]);
          },
        ),
      );
}

/// 22 · Quién leyó (R-CU21, R-CU48): porcentaje sobre las familias, pendientes con «Recordar» y enterados con hora.
/// Sólo el autor o el asesor (la base lo valida en `lectores()`).
class QuienLeyo extends StatefulWidget {
  const QuienLeyo({super.key, required this.id, this.titulo});
  final String id;
  final String? titulo;
  @override
  State<QuienLeyo> createState() => _QuienLeyoState();
}

class _QuienLeyoState extends State<QuienLeyo> {
  bool _recordando = false;

  Future<void> _recordar() async {
    setState(() => _recordando = true);
    await intentar(context, () async {
      final n = await supa.rpc('recordar_comunicado', params: {'p_comunicado': widget.id}) as int;
      if (mounted) avisar(context, n == 0 ? 'No hay familias pendientes para recordar.' : 'Se recordó a $n familia${n == 1 ? '' : 's'}.');
    });
    if (mounted) setState(() => _recordando = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Quién leyó')),
        body: Cargador<List<Map<String, dynamic>>>(
          cargar: () async {
            final f = await supa.rpc('lectores', params: {'p_comunicado': widget.id}) as List;
            return f.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          },
          construir: (context, filas, _) {
            final leyeron = filas.where((f) => f['leido_en'] != null).toList();
            final pendientes = filas.where((f) => f['leido_en'] == null).toList();
            final pct = filas.isEmpty ? 0 : (leyeron.length * 100 / filas.length).round();
            Widget fila(Map<String, dynamic> f) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(f['padre'] as String? ?? 'Sin padre todavía', style: T.heading),
                  subtitle: Text('Familia de ${f['alumno']}', style: T.caption),
                  trailing: f['leido_en'] == null
                      ? null
                      : Text(hora(DateTime.parse(f['leido_en'] as String)), style: T.caption),
                );
            return ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: C.cielo, borderRadius: BorderRadius.circular(R.lg)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$pct %', style: T.display.copyWith(fontSize: 44, color: C.cieloInk)),
                  if (widget.titulo != null) Text(widget.titulo!, style: T.heading),
                  Text('${leyeron.length} de ${filas.length} familias marcaron Enterado', style: T.body),
                  const SizedBox(height: 4),
                  Text('Solo tú ves esta lista', style: T.caption.copyWith(color: C.cieloInk)),
                ]),
              ),
              Seccion('Pendientes · ${pendientes.length}',
                  accion: pendientes.isEmpty
                      ? null
                      : TextButton(onPressed: _recordando ? null : _recordar, child: const Text('Recordar'))),
              for (final f in pendientes) fila(f),
              Seccion('Enterados · ${leyeron.length}'),
              for (final f in leyeron) fila(f),
            ]);
          },
        ),
      );
}
