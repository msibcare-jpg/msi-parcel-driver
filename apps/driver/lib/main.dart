import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'ui/kit.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'services/backend.dart';
import 'services/demo_backend.dart';
import 'services/firebase_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.useFirebase) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    Backend.instance = FirebaseBackend();
  } else {
    Backend.instance = DemoBackend();
  }
  runApp(const MsiParcelDriverApp());
}

class MsiParcelDriverApp extends StatelessWidget {
  const MsiParcelDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
