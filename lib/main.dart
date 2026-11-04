import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const LoginScreen(),
    );
  }
}
