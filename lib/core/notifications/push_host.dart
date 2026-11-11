import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/notifications/active_chat_provider.dart';
import 'package:eros_app/core/notifications/messaging_client.dart';
import 'package:eros_app/core/notifications/notification_router.dart';
import 'package:eros_app/core/notifications/push_banner.dart';
import 'package:eros_app/core/notifications/push_service.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/verification/presentation/providers/verification_provider.dart';

/// Uid of the signed-in user, or null.
final signedInUidProvider = Provider<String?>((ref) => ref.watch(currentUserProvider)?.uid);

final notificationRouterProvider = Provider<NotificationRouter>((ref) {
  final router = NotificationRouter();
  ref.onDispose(router.dispose);
  return router;
});

/// Wires push into the app (RFC-006 §6.4). Sits in `MaterialApp.builder`, above the navigator, for
/// the life of the app:
///
/// - syncs the token for whoever is signed in, at startup and on every sign-in;
/// - routes a tapped push, from killed (`getInitialMessage`) and background (`onMessageOpenedApp`);
/// - in the foreground (`onMessage`), shows [PushBanner] over every screen, unless the push is
///   about the chat already on screen ([activeChatDateIdProvider]). Tapping it routes the same way.
/// - refetches the user's verification status on a foreground `VERIFICATION_DECIDED` push and
///   whenever the app resumes, since pushes are best-effort (RFC-008 VF-F3). An open date's wall
///   refetches its date when that status turns verified.
class PushHost extends ConsumerStatefulWidget {
  const PushHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushHost> createState() => _PushHostState();
}

class _PushHostState extends ConsumerState<PushHost> {
  final Logger _logger = Logger();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  AppLifecycleListener? _lifecycle;

  /// The foreground push on show, or null.
  PushMessage? _banner;

  /// Bumped for every new banner, so a newer push (say, a collapsed second message) replaces the
  /// one on show instead of animating beside it.
  int _bannerSerial = 0;

  @override
  void initState() {
    super.initState();
    // A verification decision may have landed while the app was in the background, push or no
    // push. Outside the push setup, so it still runs if that fails.
    _lifecycle = AppLifecycleListener(onResume: _refreshVerification);
    // Push must never take the app down with it: if Firebase Messaging can't start, the app
    // carries on without push.
    try {
      _start();
    } catch (e, stackTrace) {
      _logger.e('❌ Push setup failed, carrying on without push', error: e, stackTrace: stackTrace);
    }
  }

  void _start() {
    final push = ref.read(pushServiceProvider);
    final router = ref.read(notificationRouterProvider);
    final messaging = ref.read(messagingClientProvider);

    push.start();
    push.userChanged(ref.read(signedInUidProvider));
    ref.listenManual<String?>(signedInUidProvider, (previous, uid) {
      if (uid == null) {
        router.clearPending();
        _dismissBanner();
      }
      push.userChanged(uid);
    });

    _subscriptions
      ..add(messaging.onMessageOpenedApp.listen(router.open, onError: _logError))
      ..add(messaging.onMessage.listen(_onForegroundMessage, onError: _logError));
    _openInitialMessage(messaging, router);
  }

  Future<void> _openInitialMessage(MessagingClient messaging, NotificationRouter router) async {
    try {
      final message = await messaging.getInitialMessage();
      if (message != null) router.open(message);
    } catch (e) {
      _logError(e);
    }
  }

  void _logError(Object e) => _logger.w('⚠️  Push stream error', error: e);

  void _onForegroundMessage(PushMessage message) {
    if (!mounted) return;
    _logger.d('🔔 Push in foreground: type=${message.type} dateId=${message.dateId}');
    if (ref.read(signedInUidProvider) == null) return;
    if (message.type == PushType.verificationDecided) _refreshVerification();
    final activeChat = ref.read(activeChatDateIdProvider);
    if (PushType.isChat(message.type) && activeChat != null && activeChat == message.dateId) return;
    if ((message.title ?? '').isEmpty && (message.body ?? '').isEmpty) return;
    setState(() {
      _banner = message;
      _bannerSerial++;
    });
  }

  /// Refetches the signed-in user's verification status if anything on screen is showing it.
  /// If nothing is, the next screen that shows it loads it fresh, so there's nothing to fetch.
  void _refreshVerification() {
    if (!mounted) return;
    final uid = ref.read(signedInUidProvider);
    if (uid == null || !ref.exists(verificationStatusForUserProvider(uid))) return;
    unawaited(ref.read(verificationStatusNotifierProvider).refresh());
  }

  void _dismissBanner() {
    if (mounted && _banner != null) setState(() => _banner = null);
  }

  void _onBannerTap(PushMessage message) {
    _dismissBanner();
    ref.read(notificationRouterProvider).open(message);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (banner != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PushBanner(
              key: ValueKey(_bannerSerial),
              message: banner,
              onTap: () => _onBannerTap(banner),
              onDismissed: _dismissBanner,
            ),
          ),
      ],
    );
  }
}
