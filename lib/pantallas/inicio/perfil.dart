import 'package:flutter/material.dart';

import '../../core/tema.dart';
import '../../estado/sesion.dart';
import '../../widgets/comunes.dart';
import 'marco.dart';

/// «Mi perfil»: quién tiene la sesión abierta (nombre, correo, celular) y sus cursos con el rol en cada uno.
/// El celular sólo se muestra aquí, a su dueño; el resto de las personas no lo ve.
class PerfilUsuario extends StatelessWidget {
  const PerfilUsuario({super.key});

  Future<String> _cargarNombre() async {
    final p = await supa.from('perfiles').select('nombre').eq('id', sesion.usuario!.id).single();
    return p['nombre'] as String;
  }

  Widget _dato(IconData icono, String etiqueta, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icono, color: C.lilaStrong, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(etiqueta.toUpperCase(), style: T.label),
              const SizedBox(height: 2),
              Text(valor, style: T.body),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final u = sesion.usuario;
    final celular = (u?.userMetadata?['telefono'] as String?)?.trim();
    return Cargador<String>(
      cargar: _cargarNombre,
      construir: (context, nombre, _) => Pantalla(
        titulo: 'Mi perfil',
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
          const SizedBox(height: 16),
          Tarjeta(
            child: Column(children: [
              _dato(Icons.mail_outline, 'Correo', u?.email ?? '—'),
              if (celular != null && celular.isNotEmpty) _dato(Icons.phone_outlined, 'Celular', celular),
            ]),
          ),
          const Seccion('Mis cursos'),
          for (final c in sesion.cursos)
            Tarjeta(
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.nombre, style: T.heading),
                    const SizedBox(height: 2),
                    Text('${c.colegio} · ${c.gestion}', style: T.caption),
                    Text(etiquetaRol(c) + (c.esPadre && c.hijo != null ? ' de ${c.hijoNombre}' : ''), style: T.caption),
                  ]),
                ),
                if (c.id == sesion.curso?.id) const Chip2('Actual'),
              ]),
            ),
        ],
      ),
    );
  }
}
