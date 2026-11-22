import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/errores.dart';
import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';

/// 5 · Crear curso (R-CU02, RN-CU01): sólo asesor o padre delegado.
class CrearCurso extends StatefulWidget {
  const CrearCurso({super.key});
  @override
  State<CrearCurso> createState() => _CrearCursoState();
}

class _CrearCursoState extends State<CrearCurso> {
  final _form = GlobalKey<FormState>();
  String _rol = 'asesor';
  String _nivel = 'primaria';
  final _colegio = TextEditingController(), _curso = TextEditingController();
  final _gestion = TextEditingController(text: '${DateTime.now().year}');
  final _umbral = TextEditingController(text: '100');
  bool _enviando = false;
  String? _error;

  Future<void> _crear() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final r = await supa.rpc('crear_curso', params: {
        'p_nombre': _curso.text.trim(),
        'p_colegio': _colegio.text.trim(),
        'p_nivel': _nivel,
        'p_gestion': int.parse(_gestion.text.trim()),
        'p_rol': _rol,
        'p_umbral': num.parse(_umbral.text.trim().replaceAll(',', '.')),
      }) as Map<String, dynamic>;
      await sesion.recargarCursos();
      sesion.elegirCurso(r['id'] as String);
      if (mounted) context.go('/curso-creado');
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
          titulo: 'Crear curso',
          abajo: BotonPrincipal('Crear curso', onPressed: _crear, cargando: _enviando),
          children: [
            const Titulo('Crear curso'),
            const Etiqueta('En el curso soy'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'asesor', label: Text('Asesor')),
                ButtonSegment(value: 'delegado', label: Text('Padre delegado')),
              ],
              selected: {_rol},
              onSelectionChanged: (s) => setState(() => _rol = s.first),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  _rol == 'asesor'
                      ? 'Serás el asesor del curso. Luego designas al tesorero en «Miembros y roles».'
                      : 'Quedarás como tesorero del curso. El asesor se une con el código de profesor y tú le das el rol.',
                  style: T.caption),
            ),
            Campo(
                etiqueta: 'Colegio',
                controller: _colegio,
                hint: 'U.E. San Andrés',
                validar: (v) => (v ?? '').trim().isEmpty ? 'Escribe el colegio' : null),
            Campo(
                etiqueta: 'Curso',
                controller: _curso,
                hint: '4.º B',
                validar: (v) => (v ?? '').trim().isEmpty ? 'Escribe el curso' : null),
            const Etiqueta('Nivel'),
            Wrap(spacing: 8, children: [
              for (final n in const [('primaria', 'Primaria'), ('secundaria', 'Secundaria'), ('inicial', 'Inicial')])
                ChoiceChip(label: Text(n.$2), selected: _nivel == n.$1, onSelected: (_) => setState(() => _nivel = n.$1)),
            ]),
            Campo(
                etiqueta: 'Gestión',
                controller: _gestion,
                teclado: TextInputType.number,
                validar: (v) => (int.tryParse(v ?? '') ?? 0) < 2000 ? 'Escribe el año' : null),
            Campo(
                etiqueta: 'Gastos que necesitan votación desde Bs',
                controller: _umbral,
                teclado: const TextInputType.numberWithOptions(decimal: true),
                ayuda: 'Se aprueban por mayoría de los padres que voten, con al menos 3 votos.',
                validar: (v) => (num.tryParse((v ?? '').replaceAll(',', '.')) ?? 0) <= 0 ? 'Escribe un monto' : null),
            if (_error != null) AvisoCaja(_error!),
          ],
        ),
      );
}

/// 6 · Curso creado: código y QR (también se abre desde «Más» para volver a compartir).
class CursoCreado extends StatelessWidget {
  const CursoCreado({super.key});

  @override
  Widget build(BuildContext context) {
    final c = sesion.curso!;
    return Scaffold(
      appBar: AppBar(title: const Text('Códigos del curso')),
      body: Cargador<Map<String, dynamic>>(
        cargar: () => supa.from('cursos').select('codigo, codigo_profesor, nivel').eq('id', c.id).single(),
        construir: (context, d, _) {
          final codigo = d['codigo'] as String, codProf = d['codigo_profesor'] as String;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: C.lila, borderRadius: BorderRadius.circular(R.lg)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CURSO', style: T.label.copyWith(color: C.ink)),
                const SizedBox(height: 4),
                Text('${c.nombre} · ${_nivel(d['nivel'] as String)}', style: T.title),
                Text('${c.colegio} · gestión ${c.gestion}', style: T.body),
              ]),
            ),
            const SizedBox(height: 16),
            Tarjeta(
              child: Column(children: [
                Text('CÓDIGO PARA PADRES', style: T.label),
                const SizedBox(height: 8),
                Text(codigo, style: T.display.copyWith(letterSpacing: 6)),
                const SizedBox(height: 12),
                QrImageView(data: codigo, size: 180, backgroundColor: Colors.white),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => SharePlus.instance.share(ShareParams(
                      text: 'Únete a ${c.nombre} (${c.colegio}) en Cursito con el código $codigo.\n'
                          'Mira los detalles en Cursito.')),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Compartir por WhatsApp'),
                ),
              ]),
            ),
            Tarjeta(
              child: Row(children: [
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('CÓDIGO PARA PROFESORES DE MATERIA', style: T.label),
                  const SizedBox(height: 4),
                  Text(codProf, style: T.title.copyWith(letterSpacing: 2)),
                ])),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: codProf));
                    if (context.mounted) avisar(context, 'Código copiado');
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copiar'),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => context.push('/nomina'), child: const Text('Siguiente: cargar la nómina')),
            const SizedBox(height: 8),
            TextButton(onPressed: () => context.go('/inicio'), child: const Text('Ir al inicio del curso')),
          ]);
        },
      ),
    );
  }

  static String _nivel(String n) => switch (n) { 'inicial' => 'Inicial', 'secundaria' => 'Secundaria', _ => 'Primaria' };
}
