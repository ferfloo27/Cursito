import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/tema.dart';
import 'estado/sesion.dart';
import 'rutas.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  if (!Config.completa) {
    runApp(const _SinConfiguracion());
    return;
  }
  await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseKey);
  sesion.iniciar();
  runApp(const CursitoApp());
}

class CursitoApp extends StatelessWidget {
  const CursitoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Cursito',
      debugShowCheckedModeBanner: false,
      theme: temaCursito(),
      routerConfig: rutas,
      locale: const Locale('es', 'BO'),
      supportedLocales: const [Locale('es', 'BO'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}

class _SinConfiguracion extends StatelessWidget {
  const _SinConfiguracion();
  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(body: Center(child: Text('Falta env.json (ver env.example.json)'))),
      );
}
