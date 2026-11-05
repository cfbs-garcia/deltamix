import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/account_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No Android, lê as configurações de android/app/google-services.json
  await Firebase.initializeApp();
  runApp(const DeltamixApp());
}

class DeltamixApp extends StatelessWidget {
  const DeltamixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deltamix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AccountGate(),
    );
  }
}
