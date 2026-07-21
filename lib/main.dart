import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'services/auth_controller.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';

// Notification-type messages (all of ours — see sendPushToUser in
// functions/index.js) are shown by the OS automatically even with no
// handler at all; this just needs to exist and be registered so the
// background isolate initializes correctly on Android. Must be a top-level
// function, not a class method — FCM runs it in a separate isolate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const LooksMatchApp());
}

class LooksMatchApp extends StatefulWidget {
  const LooksMatchApp({super.key});

  @override
  State<LooksMatchApp> createState() => _LooksMatchAppState();
}

class _LooksMatchAppState extends State<LooksMatchApp> {
  final AuthController _auth = FirebaseAuthController();
  late final PushNotificationService _pushService =
      PushNotificationService(_auth, scaffoldMessengerKey);

  @override
  void initState() {
    super.initState();
    _pushService.initialize();
  }

  @override
  void dispose() {
    _pushService.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LooksMatch',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: AuthGate(auth: _auth),
    );
  }
}
