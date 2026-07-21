import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'auth_controller.dart';
import 'notification_router.dart';

/// Wires FCM into the app: requests permission, keeps this device's push
/// token registered against whichever user is currently signed in, shows a
/// snackbar for messages that arrive while the app is open, and routes a
/// notification tap to the right tab via [NotificationRouter]. What
/// actually sends these lives server-side — see sendPushToUser in
/// functions/index.js.
class PushNotificationService {
  PushNotificationService(this._auth, this._scaffoldMessengerKey) {
    _auth.addListener(_onAuthChanged);
  }

  final AuthController _auth;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey;
  final _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    _messaging.onTokenRefresh.listen((_) => _registerCurrentToken());
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_routeFromMessage);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _routeFromMessage(initialMessage);

    await _registerCurrentToken();
  }

  void _onAuthChanged() {
    if (_auth.isSignedIn) _registerCurrentToken();
  }

  Future<void> _registerCurrentToken() async {
    if (!_auth.isSignedIn) return;

    try {
      final token = await _messaging.getToken();
      if (token != null) await _auth.registerFcmToken(token);
    } catch (error) {
      debugPrint('Could not register push token: $error');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final title = notification.title;
    final body = notification.body ?? '';
    final text = (title == null || title.isEmpty) ? body : '$title: $body';
    if (text.isEmpty) return;

    _scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
  }

  void _routeFromMessage(RemoteMessage message) {
    final type = message.data['type'];
    if (type == 'match' || type == 'message') {
      NotificationRouter.requestTab('matches');
    } else if (type == 'like') {
      NotificationRouter.requestTab('likes');
    }
  }

  void dispose() {
    _auth.removeListener(_onAuthChanged);
  }
}
