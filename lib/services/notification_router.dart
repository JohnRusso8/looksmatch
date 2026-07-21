import 'package:flutter/foundation.dart';

/// Broadcasts which tab a notification tap wants [HomeShell] to switch to.
/// FCM tap handlers fire outside the widget tree, so they can't reach
/// HomeShell's own tab-selection method directly — this is the bridge,
/// simpler than wiring up a full global-navigator-key setup for what's
/// currently just "open this bottom-nav tab".
class NotificationRouter {
  NotificationRouter._();

  static final ValueNotifier<String?> pendingTab = ValueNotifier<String?>(null);

  static void requestTab(String tab) => pendingTab.value = tab;

  static void consume() => pendingTab.value = null;
}
