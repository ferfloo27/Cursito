import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Config.completa) {
    await Supabase.initialize(
      url: Config.supabaseUrl,
      publishableKey: Config.supabaseKey,
    );
  }
  runApp(const ProviderScope(child: CursitoApp()));
}

class CursitoApp extends StatelessWidget {
  const CursitoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cursito',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            Config.completa
                ? 'Cursito'
                : 'Falta env.json (ver env.example.json)',
          ),
        ),
      ),
    );
  }
}
