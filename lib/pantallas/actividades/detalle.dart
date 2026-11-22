import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';
import 'actividades.dart';

/// Lo que se muestra en el detalle; lo que el rol no puede ver queda en null (RN-CU04: el alumno no ve cuota ni asistencia).
class _Detalle {
  late Map<String, dynamic> a;
  ({int asisten, int noAsisten})? conteo;
  int familias = 0;
  int? autorizaron;
  Map<String, dynamic>? miAsistencia;
  bool autorice = false;
  Map<String, dynamic>? cuota;
  Map<String, dynamic>? miDeuda;
  Map<String, dynamic>? rendicion;
}

/// 16 · Detalle de actividad: asistencia, autorización y cuota juntas (R-CU25, R-CU37, R-CU38, R-CU47).
/// El hilo de comentarios (R-CU26) se agrega debajo.
class DetalleActividad extends StatefulWidget {
  const DetalleActividad({super.key, required this.id});
  final String id;
  @override
  State<DetalleActividad> createState() => _DetalleActividadState();
}

class _DetalleActividadState extends State<DetalleActividad> {
  int _version = 0;
  bool _enviando = false;
  CursoMio get _c => sesion.curso!;

  Future<_Detalle> _cargar() async {
    final d = _Detalle();
    d.a = await supa.from('actividades').select(selectActividad).eq('id', widget.id).single();
    if (_c.esAlumno) return d;
    final hijo = _c.esPadre ? _c.hijoId : null;
    if (d.a['pide_asistencia'] == true) {
      final r = await supa.rpc('conteo_asistencia', params: {'p_actividad': widget.id}) as List;
      final f = r.isEmpty ? {'asisten': 0, 'no_asisten': 0} : r.first as Map;
      d.conteo = (asisten: f['asisten'] as int, noAsisten: f['no_asisten'] as int);
      final al = await supa.from('alumnos').select('id').eq('curso_id', _c.id);
      d.familias = (al as List).length;
      if (hijo != null) {
        d.miAsistencia =
            await supa.from('asistencias').select('id, respuesta').eq('actividad_id', widget.id).eq('alumno_id', hijo).maybeSingle();
      }
    }
    if (d.a['pide_autorizacion'] == true) {
      final au = await supa.from('autorizaciones').select('alumno_id').eq('actividad_id', widget.id);
      if (_c.esDocente) d.autorizaron = (au as List).length;
      if (hijo != null) d.autorice = (au as List).any((x) => x['alumno_id'] == hijo);
    }
    d.cuota = await supa
        .from('cuotas')
        .select('id, concepto, monto_por_alumno, vence_el')
        .eq('actividad_id', widget.id)
        .isFilter('anulada_en', null)
        .order('creado_en', ascending: true)
        .limit(1)
        .maybeSingle();
    if (d.cuota != null) {
      if (_c.veCuentas) {
        d.rendicion = Map<String, dynamic>.from(
            await supa.rpc('rendicion', params: {'p_curso': _c.id, 'p_actividad': widget.id}) as Map);
      }
      if (_c.esPadre) {
        final mias = await supa.rpc('mis_cuotas', params: {'p_curso': _c.id}) as List;
        d.miDeuda = mias.map((e) => Map<String, dynamic>.from(e as Map)).where((m) => m['cuota_id'] == d.cuota!['id']).firstOrNull;
      }
    }
    return d;
  }

  void _recargar() => setState(() => _version++);

  Future<void> _responder(_Detalle d, String respuesta) async {
    if (_enviando) return;
    setState(() => _enviando = true);
    final ok = await intentar(context, () async {
      if (d.miAsistencia == null) {
        await supa.from('asistencias').insert({'actividad_id': widget.id, 'alumno_id': _c.hijoId, 'respuesta': respuesta});
      } else {
        await supa.from('asistencias').update({'respuesta': respuesta}).eq('id', d.miAsistencia!['id']);
      }
    });
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok) _recargar();
  }

  Future<void> _autorizar() async {
    if (!await confirmar(context, 'Autorizo', 'Autorizas a ${_c.hijoNombre} a participar en esta actividad.', si: 'Autorizo')) return;
    if (!mounted) return;
    if (await intentar(context, () => supa.from('autorizaciones').insert({'actividad_id': widget.id, 'alumno_id': _c.hijoId}))) {
      _recargar();
    }
  }

  Future<void> _cancelar(Map<String, dynamic> a) async {
    if (!await confirmar(context, 'Cancelar actividad', 'Se avisará en el muro que «${a['titulo']}» se canceló. No se puede deshacer.',
        si: 'Cancelar actividad', no: 'Volver')) {
      return;
    }
    if (!mounted) return;
    if (await intentar(
        context, () => supa.from('actividades').update({'cancelada_en': DateTime.now().toUtc().toIso8601String()}).eq('id', a['id']))) {
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: Cargador<_Detalle>(
          key: ValueKey(_version),
          cargar: _cargar,
          construir: (context, d, _) {
            final a = d.a;
            final evento = a['tipo'] == 'evento';
            final fecha = DateTime.parse(a['fecha'] as String);
            final cancelada = a['cancelada_en'] != null;
            final abierta = !cancelada && DateTime.now().isBefore(fecha);
            final soyAutor = a['creado_por'] == sesion.usuario?.id;
            final autor = (a['autor'] as Map?)?['nombre'] ?? '';
            return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
              Wrap(spacing: 6, children: [
                chipTipo(a),
                if (d.cuota != null) const Chip2('Con cuota', fondo: C.menta, tinta: C.mentaInk),
                if (cancelada) const Chip2('Cancelada', fondo: C.rosa, tinta: C.rosaInk),
              ]),
              const SizedBox(height: 8),
              Text(a['titulo'] as String, style: T.display),
              const SizedBox(height: 4),
              Text([fechaHora(fecha), if (a['lugar'] != null) a['lugar']].join(' · '), style: T.body.copyWith(color: C.inkMuted)),
              if ((a['descripcion'] as String?)?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                Text(a['descripcion'] as String, style: T.body),
              ],
              const SizedBox(height: 8),
              Text('Publicado por $autor', style: T.caption),
              if (cancelada) const AvisoCaja('Esta actividad se canceló.'),
              if (soyAutor && !cancelada && !_c.esAlumno) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () async {
                            final ok = await context.push<bool>('/actividad/${a['id']}/editar', extra: a);
                            if (ok == true) _recargar();
                          },
                          child: const Text('Editar'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextButton(
                          style: TextButton.styleFrom(foregroundColor: C.rosaInk),
                          onPressed: () => _cancelar(a),
                          child: const Text('Cancelar actividad'))),
                ]),
                Text('Puedes cambiar fecha, lugar y descripción. Cada cambio avisa en el muro.', style: T.caption),
              ],
              if (evento && d.conteo != null) ..._asistencia(d, abierta),
              if (d.a['pide_autorizacion'] == true && !_c.esAlumno) ..._autorizacion(d, abierta),
              if (d.cuota != null) ..._cuota(d),
            ]);
          },
        ),
      );

  List<Widget> _asistencia(_Detalle d, bool abierta) {
    final c = d.conteo!;
    final sinResponder = (d.familias - c.asisten - c.noAsisten).clamp(0, 999);
    if (!_c.esPadre) {
      return [
        const Seccion('Asistencia'),
        Tarjeta(
          color: C.durazno,
          child: Text(
              '${c.asisten} asistirán · ${c.noAsisten} no asistirán · '
              '${sinResponder == 0 ? 'ninguna familia sin responder' : '$sinResponder sin responder'}',
              style: T.heading.copyWith(color: C.duraznoInk)),
        ),
      ];
    }
    final mia = d.miAsistencia?['respuesta'] as String?;
    Widget boton(String valor, String texto) => Expanded(
          child: mia == valor
              ? FilledButton(onPressed: abierta ? () => _responder(d, valor) : null, child: Text(texto))
              : OutlinedButton(onPressed: abierta ? () => _responder(d, valor) : null, child: Text(texto)),
        );
    return [
      const Seccion('¿Vas a asistir?'),
      Row(children: [boton('asiste', 'Asistiré'), const SizedBox(width: 8), boton('no_asiste', 'No asistiré')]),
      const SizedBox(height: 8),
      Text('${c.asisten} confirmaron · Ves cuántos confirmaron, no quiénes.', style: T.caption),
      if (!abierta) Text('Ya pasó la fecha: la respuesta no se puede cambiar.', style: T.caption),
    ];
  }

  List<Widget> _autorizacion(_Detalle d, bool abierta) => [
        const Seccion('Autorización'),
        if (_c.esPadre)
          d.autorice
              ? const AvisoCaja('Autorizaste la participación.', fondo: C.menta, tinta: C.mentaInk, icono: Icons.check_circle_outline)
              : FilledButton.icon(
                  onPressed: abierta ? _autorizar : null, icon: const Icon(Icons.verified_outlined), label: const Text('Autorizo'))
        else
          Text('${d.autorizaron ?? 0} de ${d.familias} familias autorizaron.', style: T.body),
      ];

  List<Widget> _cuota(_Detalle d) {
    final q = d.cuota!;
    final r = d.rendicion;
    final m = d.miDeuda;
    final total = aNum(q['monto_por_alumno']) * (r?['familias'] as int? ?? d.familias);
    String? estado;
    if (m != null) {
      final pendiente = aNum(m['pendiente']), pagado = aNum(m['pagado']), revision = aNum(m['en_revision']);
      estado = pendiente == 0
          ? 'Pagada'
          : revision > 0
              ? 'Comprobante en revisión (${bs(revision)})'
              : pagado > 0
                  ? 'Pagado ${bs(pagado)} de ${bs(m['monto'])} · faltan ${bs(pendiente)}'
                  : 'Pendiente';
    }
    return [
      const Seccion('Cuota del evento'),
      Tarjeta(
        color: C.menta,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(q['concepto'] as String, style: T.heading),
              Text('Vence el ${fechaCorta(DateTime.parse(q['vence_el'] as String))} · creada por el tesorero',
                  style: T.caption.copyWith(color: C.mentaInk)),
            ])),
            Text(bs(q['monto_por_alumno']), style: T.amount.copyWith(color: C.mentaInk)),
          ]),
          if (r != null) ...[
            const SizedBox(height: 8),
            Text(
                'Recaudado ${bs(r['recaudado'])}${total > 0 ? ' de ${bs(total)}' : ''} · gastado ${bs(r['gastado'])} · saldo ${bs(r['saldo'])}',
                style: T.body.copyWith(color: C.mentaInk)),
          ],
          if (estado != null) ...[
            const SizedBox(height: 8),
            Chip2(estado, fondo: C.surfaceRaised, tinta: estado == 'Pagada' ? C.mentaInk : C.duraznoInk),
          ],
          if (m != null && aNum(m['pendiente']) > 0) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => avisar(context, 'El pago con comprobante llega en la fase de finanzas.'),
              child: const Text('Pagar mi cuota'),
            ),
          ],
        ]),
      ),
    ];
  }
}
