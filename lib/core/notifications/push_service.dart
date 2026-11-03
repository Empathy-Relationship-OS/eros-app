import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/notifications/messaging_client.dart';

/// Keeps the backend's list of this device's push tokens current (RFC-006 §6.4).
///
/// The token is posted to `POST /users/me/devices` when a user is signed in ([userChanged], which
/// covers sign-in and startup) and whenever FCM refreshes it. [removeToken] takes it off the
/// account before sign-out. Every call is best-effort: a failure is logged and never thrown, as
/// push must not get in the way of signing in or out.
///
/// The token itself is never logged.
class PushService {
  PushService({
    required MessagingClient messaging,
    required ApiClient Function() apiClient,
    required String platform,
    Logger? logger,
  })  : _messaging = messaging,
        _apiClient = apiClient,
        _platform = platform,
        _logger = logger ?? Logger();

  final MessagingClient _messaging;

  /// Read at call time: `apiClientProvider` builds a new client for each user.
  final ApiClient Function() _apiClient;

  /// `IOS` or `ANDROID`, as `user_devices.platform` takes it.
  final String _platform;
  final Logger _logger;

  StreamSubscription<String>? _refreshSubscription;

  /// The signed-in user whose devices the token is synced to, or null. Cleared at the start of
  /// [removeToken], so a refresh that lands during sign-out isn't posted to the old account.
  String? _uid;

  /// Starts listening for token refreshes. Call once.
  void start() {
    _refreshSubscription ??= _messaging.onTokenRefresh.listen((token) {
      _logger.d('🔔 Push token refreshed');
      syncToken(token: token);
    });
  }

  /// Tells the service who is signed in, from auth state. A new user gets the token posted.
  Future<void> userChanged(String? uid) async {
    if (uid == _uid) return;
    _uid = uid;
    if (uid != null) await syncToken();
  }

  Future<PushPermission> permissionStatus() async {
    try {
      return await _messaging.permissionStatus();
    } catch (e) {
      _logger.w('⚠️  Could not read push permission', error: e);
      return PushPermission.notDetermined;
    }
  }

  /// Shows the OS prompt (if the user hasn't answered it before), then syncs the token, which on
  /// iOS may only exist once permission is granted.
  Future<PushPermission> requestPermission() async {
    try {
      final permission = await _messaging.requestPermission();
      _logger.i('🔔 Push permission: ${permission.name}');
      if (permission == PushPermission.granted) await syncToken();
      return permission;
    } catch (e) {
      _logger.w('⚠️  Push permission request failed', error: e);
      return PushPermission.notDetermined;
    }
  }

  /// Posts the token to `POST /users/me/devices`. Does nothing while no one is signed in, or while
  /// the token isn't available yet (it then arrives through `onTokenRefresh`).
  Future<void> syncToken({String? token}) async {
    if (_uid == null) return;
    try {
      final current = token ?? await _messaging.getToken();
      if (current == null) {
        _logger.d('🔔 No push token yet, will sync when it arrives');
        return;
      }
      if (_uid == null) return;
      await _apiClient().post<void>(
        ApiEndpoints.devices.register(),
        data: {'token': current, 'platform': _platform},
      );
      _logger.d('🔔 Push token synced');
    } catch (e) {
      _logger.w('⚠️  Push token sync failed', error: e);
    }
  }

  /// Takes this device off the signed-in account: `POST /users/me/devices/remove`, then deletes
  /// the token locally so the next account gets a fresh one. Needs a valid session, so call it
  /// before Firebase sign-out. Never throws.
  Future<void> removeToken() async {
    _uid = null;
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _apiClient().post<void>(
          ApiEndpoints.devices.remove(),
          data: {'token': token},
        );
        _logger.d('🔔 Push token removed from account');
      }
    } catch (e) {
      _logger.w('⚠️  Push token removal failed', error: e);
    }
    try {
      await _messaging.deleteToken();
    } catch (e) {
      _logger.w('⚠️  Push token delete failed', error: e);
    }
  }

  void dispose() {
    _refreshSubscription?.cancel();
    _refreshSubscription = null;
  }
}

/// `IOS` or `ANDROID`, the values `POST /users/me/devices` accepts.
String devicePlatform() => defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';

// Typed explicitly: it sits on a provider cycle (signOutServiceProvider reads it, and its
// apiClient closure reads apiClientProvider), which top-level inference can't follow.
final Provider<PushService> pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(
    messaging: ref.watch(messagingClientProvider),
    apiClient: () => ref.read(apiClientProvider),
    platform: devicePlatform(),
  );
  ref.onDispose(service.dispose);
  return service;
});
