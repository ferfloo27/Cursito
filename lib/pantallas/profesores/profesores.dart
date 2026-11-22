import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

const _dias = {1: 'Lunes', 2: 'Martes', 3: 'Miércoles', 4: 'Jueves', 5: 'Viernes'};

String _nombre(Map<String, dynamic> m) => ((m['perfil'] as Map?)?['nombre'] as String?) ?? '';

String? _materia(Map<String, dynamic> m) => (((m['profesor'] as Map?)?['materia']) as Map?)?['nombre'] as String?;

String _cargoDe(Map<String, dynamic> m) {
  final materia = _materia(m);
  if (m['rol'] == 'asesor') return materia == null ? 'Asesora del curso' : 'Asesora · $materia';
  return materia ?? 'Profesor';
}

/// Directorio de profesores del curso (R-CU28, RF-C09). Apartado propio para padres y docentes.
class ListaProfesores extends StatelessWidget {
  const ListaProfesores({super.key});

  Future<List<Map<String, dynamic>>> _cargar() async {
    final f = await supa
        .from('miembros_curso')
        .select('id, rol, usuario_id, perfil:perfiles(nombre), profesor:profesores_curso(materia:materias(id, nombre))')
        .eq('curso_id', sesion.curso!.id)
        .inFilter('rol', ['profesor', 'asesor']);
    final lista = [for (final x in f as List) Map<String, dynamic>.from(x as Map)];
    // La asesora primero; luego por nombre.
    lista.sort((a, b) {
      final ra = a['rol'] == 'asesor' ? 0 : 1, rb = b['rol'] == 'asesor' ? 0 : 1;
      return ra != rb ? ra.compareTo(rb) : _nombre(a).compareTo(_nombre(b));
    });
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return Cargador<List<Map<String, dynamic>>>(
      cargar: _cargar,
      construir: (context, lista, _) => Pantalla(
        titulo: 'Profesores',
        children: [
          const Titulo('Profesores del curso', sub: 'Toca a un profesor para ver su materia, su horario y cómo contactarlo.'),
          if (lista.isEmpty) const Vacio('Todavía no hay profesores en el curso.', icono: Icons.co_present_outlined),
          for (final p in lista)
            Tarjeta(
              onTap: () => context.push('/profesor', extra: p),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: C.lila,
                  child: Text(_nombre(p).isEmpty ? '?' : _nombre(p).characters.first.toUpperCase(), style: T.heading),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_nombre(p), style: T.heading),
                    Text(_cargoDe(p), style: T.caption),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: C.inkMuted),
              ]),
            ),
        ],
      ),
    );
  }
}

class _DatosProfesor {
  _DatosProfesor(this.horario, this.celular, this.contactoDisponible);
  final List<Map<String, dynamic>> horario;
  final String? celular;
  final bool contactoDisponible; // false si la función de contacto no está en la base
}

/// Perfil de un profesor: materia, sus clases de la semana y el contacto (celular) que registró.
/// En Cursito no hay chat: las dudas de una tarea van en el hilo de la actividad (SRC-CU01 §0).
class PerfilProfesor extends StatelessWidget {
  const PerfilProfesor({super.key, required this.profesor});
  final Map<String, dynamic> profesor;

  Future<_DatosProfesor> _cargar() async {
    final materiaId = ((((profesor['profesor'] as Map?)?['materia']) as Map?)?['id']) as String?;
    var horario = <Map<String, dynamic>>[];
    if (materiaId != null) {
      final h = await supa
          .from('horario_bloques')
          .select('dia, hora_inicio, hora_fin')
          .eq('curso_id', sesion.curso!.id)
          .eq('materia_id', materiaId)
          .order('dia')
          .order('hora_inicio');
      horario = [for (final x in h as List) Map<String, dynamic>.from(x as Map)];
    }
    String? celular;
    var disponible = true;
    try {
      celular = await supa.rpc('contacto_docente', params: {'p_miembro': profesor['id']}) as String?;
    } catch (_) {
      disponible = false; // la base todavía no tiene la función 20261122150000_contacto_docente
    }
    return _DatosProfesor(horario, celular, disponible);
  }

  static String _hora(dynamic t) => (t as String).substring(0, 5);

  Future<void> _abrir(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) avisar(context, 'No se pudo abrir la aplicación.');
  }

  /// WhatsApp pide el código de país: un celular de 8 dígitos es de Bolivia (591).
  static String _paraWhatsApp(String celular) {
    final d = celular.replaceAll(RegExp(r'\D'), '');
    return d.length == 8 ? '591$d' : d;
  }

  @override
  Widget build(BuildContext context) {
    return Cargador<_DatosProfesor>(
      cargar: _cargar,
      construir: (context, d, _) {
        final nombre = _nombre(profesor);
        final celular = d.celular;
        return Pantalla(
          titulo: 'Profesor',
          children: [
            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: C.lila,
                child: Text(nombre.isEmpty ? '?' : nombre.characters.first.toUpperCase(),
                    style: T.display.copyWith(color: C.lilaStrong)),
              ),
            ),
            const SizedBox(height: 12),
            Center(child: Text(nombre, style: T.title, textAlign: TextAlign.center)),
            Center(child: Text(_cargoDe(profesor), style: T.caption)),
            const Seccion('Contacto'),
            Tarjeta(
              child: !d.contactoDisponible
                  ? Text('El contacto no está disponible por ahora.', style: T.body)
                  : celular == null
                      ? Text('Este profesor todavía no registró su celular.', style: T.body)
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.phone_outlined, color: C.lilaStrong, size: 20),
                            const SizedBox(width: 12),
                            Text(celular, style: T.heading),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _abrir(context, Uri(scheme: 'tel', path: celular)),
                                icon: const Icon(Icons.call_outlined, size: 18),
                                label: const Text('Llamar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _abrir(context, Uri.parse('https://wa.me/${_paraWhatsApp(celular)}')),
                                icon: const Icon(Icons.chat_outlined, size: 18),
                                label: const Text('WhatsApp'),
                              ),
                            ),
                          ]),
                        ]),
            ),
            const AvisoCaja(
              'En Cursito no hay chat. Para dudas de una tarea, escribe en el hilo de esa actividad.',
              fondo: C.cielo,
              tinta: C.cieloInk,
              icono: Icons.info_outline,
            ),
            if (d.horario.isNotEmpty) ...[
              const Seccion('Sus clases'),
              for (final b in d.horario)
                Tarjeta(
                  padding: 12,
                  child: Row(children: [
                    SizedBox(width: 96, child: Text(_dias[b['dia']] ?? '', style: T.heading)),
                    Text('${_hora(b['hora_inicio'])} – ${_hora(b['hora_fin'])}', style: T.body),
                  ]),
                ),
            ],
          ],
        );
      },
    );
  }
}
