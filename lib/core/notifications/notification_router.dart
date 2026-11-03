import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/navigation/app_navigator.dart';
import 'package:eros_app/core/notifications/messaging_client.dart';

/// Whether chat pushes open the chat screen (CH-F2). When false, they open date detail instead,
/// where the chat button is.
const bool dateChatRouteEnabled = true;

/// Route name of the chat screen, registered by CH-F2. Takes the date id as a String.
const String dateChatRoute = '/date-chat';

/// Route name of date detail. Takes the date id as a String.
const String dateDetailRoute = '/dates/detail';

/// Push `data.type` values (RFC-006 §4.6).
abstract final class PushType {
  static const chatOpened = 'chat_opened';
  static const chatMessage = 'chat_message';
  static const dateCancelled = 'date_cancelled';

  static bool isChat(String? type) => type == chatOpened || type == chatMessage;
}

/// Where a push opens.
@immutable
class NotificationTarget {
  const NotificationTarget(this.routeName, this.dateId);

  final String routeName;
  final String dateId;

  @override
  bool operator ==(Object other) =>
      other is NotificationTarget && other.routeName == routeName && other.dateId == dateId;

  @override
  int get hashCode => Object.hash(routeName, dateId);

  @override
  String toString() => 'NotificationTarget($routeName, $dateId)';
}

/// Opens the screen a push is about, from a tap in any app state (RFC-006 §6.4): killed
/// (`getInitialMessage`), background (`onMessageOpenedApp`) and foreground (the in-app banner).
///
/// A tap that arrives before the user has reached home (on a cold start the auth screen is still
/// deciding where to go, and would replace whatever was pushed) waits, and opens once home is in
/// the stack. Only the latest waiting tap is kept.
class NotificationRouter {
  NotificationRouter({
    GlobalKey<NavigatorState>? navigatorKey,
    ValueListenable<bool>? isHomeInStack,
    this.chatRouteEnabled = dateChatRouteEnabled,
    Logger? logger,
  })  : _navigatorKey = navigatorKey ?? appNavigatorKey,
        _isHomeInStack = isHomeInStack ?? appRouteObserver.isHomeInStack,
        _logger = logger ?? Logger() {
    _isHomeInStack.addListener(_openPending);
  }

  final GlobalKey<NavigatorState> _navigatorKey;
  final ValueListenable<bool> _isHomeInStack;
  final bool chatRouteEnabled;
  final Logger _logger;

  NotificationTarget? _pending;

  /// The tap waiting for home, if any.
  NotificationTarget? get pending => _pending;

  /// Where [message] opens, or null for a type the app doesn't route (or no date id).
  NotificationTarget? targetFor(PushMessage message) {
    final dateId = message.dateId;
    if (dateId == null || dateId.isEmpty) return null;
    final type = message.type;
    if (PushType.isChat(type)) {
      return NotificationTarget(chatRouteEnabled ? dateChatRoute : dateDetailRoute, dateId);
    }
    if (type == PushType.dateCancelled) return NotificationTarget(dateDetailRoute, dateId);
    return null;
  }

  /// Opens the screen for a tapped [message]. Does nothing for a type it doesn't route.
  void open(PushMessage message) {
    final target = targetFor(message);
    _logger.i('🔔 Push tapped: type=${message.type} dateId=${message.dateId} -> ${target?.routeName}');
    if (target == null) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null || !_isHomeInStack.value) {
      _pending = target;
      return;
    }
    _push(navigator, target);
  }

  void _openPending() {
    final target = _pending;
    final navigator = _navigatorKey.currentState;
    if (target == null || navigator == null || !_isHomeInStack.value) return;
    _pending = null;
    // Home has just been pushed; let that navigation finish first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navigatorKey.currentState;
      if (navigator != null) _push(navigator, target);
    });
  }

  void _push(NavigatorState navigator, NotificationTarget target) {
    // Already showing it (say, the chat was open when the app went to the background).
    final top = topRoute(navigator)?.settings;
    if (top?.name == target.routeName && top?.arguments == target.dateId) return;
    navigator.pushNamed(target.routeName, arguments: target.dateId);
  }

  /// Forgets a waiting tap, for sign-out.
  void clearPending() => _pending = null;

  void dispose() => _isHomeInStack.removeListener(_openPending);
}
