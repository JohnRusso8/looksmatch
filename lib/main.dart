import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'services/auth_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const LooksMatchApp());
}

class LooksMatchApp extends StatefulWidget {
  const LooksMatchApp({super.key});

  @override
  State<LooksMatchApp> createState() => _LooksMatchAppState();
}

class _LooksMatchAppState extends State<LooksMatchApp> {
  final AuthController _auth = FirebaseAuthController();

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LooksMatch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: AuthGate(auth: _auth),
    );
  }
}
