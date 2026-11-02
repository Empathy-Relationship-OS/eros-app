import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A push as the app sees it: the notification's title and body, and the data payload
/// (`{"type": "...", "dateId": "42"}`, RFC-006 §4.6).
///
/// It never contains message text (D-19), and its title and body are never logged.
@immutable
class PushMessage {
  const PushMessage({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;
  final Map<String, dynamic> data;

  String? get type => data['type'] as String?;

  /// The date id as a String, like every date route takes it. FCM data values are strings.
  String? get dateId => data['dateId']?.toString();

  factory PushMessage.fromRemote(RemoteMessage message) => PushMessage(
        title: message.notification?.title,
        body: message.notification?.body,
        data: message.data,
      );
}

/// Whether the user lets the app show notifications.
enum PushPermission {
  granted,
  denied,

  /// Not asked yet (iOS), or the OS gives no answer.
  notDetermined,
}

/// The parts of `FirebaseMessaging` the app uses, so tests can swap in a fake.
abstract class MessagingClient {
  /// The FCM token, or null if it isn't available yet (on iOS, before APNs has given one). A
  /// token that arrives later comes through [onTokenRefresh].
  Future<String?> getToken();

  Future<void> deleteToken();

  Stream<String> get onTokenRefresh;

  /// Shows the OS prompt if the user hasn't answered it yet.
  Future<PushPermission> requestPermission();

  Future<PushPermission> permissionStatus();

  /// The push the user tapped to launch the app from killed, if any.
  Future<PushMessage?> getInitialMessage();

  /// Pushes received while the app is in the foreground. The OS shows nothing for these.
  Stream<PushMessage> get onMessage;

  /// Pushes tapped while the app was in the background.
  Stream<PushMessage> get onMessageOpenedApp;
}

class FirebaseMessagingClient implements MessagingClient {
  FirebaseMessagingClient(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<String?> getToken() async {
    // On iOS, getToken throws until APNs has handed over its token. FCM then mints one and
    // announces it on onTokenRefresh, so there's nothing to wait for here.
    if (defaultTargetPlatform == TargetPlatform.iOS && await _messaging.getAPNSToken() == null) {
      return null;
    }
    return _messaging.getToken();
  }

  @override
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<PushPermission> requestPermission() async =>
      _permission((await _messaging.requestPermission()).authorizationStatus);

  @override
  Future<PushPermission> permissionStatus() async =>
      _permission((await _messaging.getNotificationSettings()).authorizationStatus);

  static PushPermission _permission(AuthorizationStatus status) => switch (status) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional => PushPermission.granted,
        AuthorizationStatus.denied => PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.notDetermined,
      };

  @override
  Future<PushMessage?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : PushMessage.fromRemote(message);
  }

  @override
  Stream<PushMessage> get onMessage => FirebaseMessaging.onMessage.map(PushMessage.fromRemote);

  @override
  Stream<PushMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(PushMessage.fromRemote);
}

final messagingClientProvider = Provider<MessagingClient>((ref) {
  return FirebaseMessagingClient(FirebaseMessaging.instance);
});
