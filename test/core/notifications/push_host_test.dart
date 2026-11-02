import 'package:eros_app/core/navigation/app_navigator.dart';
import 'package:eros_app/core/notifications/active_chat_provider.dart';
import 'package:eros_app/core/notifications/messaging_client.dart';
import 'package:eros_app/core/notifications/notification_router.dart';
import 'package:eros_app/core/notifications/push_banner.dart';
import 'package:eros_app/core/notifications/push_host.dart';
import 'package:eros_app/core/notifications/push_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_messaging.dart';
import 'notification_test_app.dart';

final _uid = StateProvider<String?>((ref) => 'alice');

void main() {
  late FakeMessagingClient messaging;
  late FakeDevicesApi api;
  late GlobalKey<NavigatorState> navigatorKey;
  late HomeRouteObserver observer;
  late ProviderContainer container;

  setUp(() {
    messaging = FakeMessagingClient();
    api = FakeDevicesApi();
    navigatorKey = GlobalKey<NavigatorState>();
    observer = HomeRouteObserver();
  });

  Future<void> pumpApp(WidgetTester tester, {String? uid = 'alice'}) async {
    container = ProviderContainer(overrides: [
      _uid.overrideWith((ref) => uid),
      signedInUidProvider.overrideWith((ref) => ref.watch(_uid)),
      messagingClientProvider.overrideWithValue(messaging),
      pushServiceProvider.overrideWith((ref) {
        final service = PushService(messaging: messaging, apiClient: () => api, platform: 'IOS');
        ref.onDispose(service.dispose);
        return service;
      }),
      notificationRouterProvider.overrideWith((ref) => NotificationRouter(
            navigatorKey: navigatorKey,
            isHomeInStack: observer.isHomeInStack,
            chatRouteEnabled: true,
          )),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: NotificationTestApp(
        navigatorKey: navigatorKey,
        observer: observer,
        builder: (context, child) => PushHost(child: child!),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('token sync', () {
    testWidgets('syncs at startup for a signed-in user', (tester) async {
      await pumpApp(tester);

      expect(api.posts.single.path, '/users/me/devices');
    });

    testWidgets('syncs on sign-in, not before', (tester) async {
      await pumpApp(tester, uid: null);
      expect(api.posts, isEmpty);

      container.read(_uid.notifier).state = 'alice';
      await tester.pumpAndSettle();

      expect(api.posts.single.data, {'token': 'fcm-token-1', 'platform': 'IOS'});
    });

    testWidgets('syncs on token refresh', (tester) async {
      await pumpApp(tester);
      messaging.tokenRefresh.add('fcm-token-2');
      await tester.pumpAndSettle();

      expect(api.posts.last.data, {'token': 'fcm-token-2', 'platform': 'IOS'});
    });
  });

  group('tap routing', () {
    testWidgets('killed: the launching push opens its screen', (tester) async {
      messaging.initialMessage = push('chat_opened', dateId: '5');
      await pumpApp(tester);

      expect(find.text('/date-chat 5'), findsOneWidget);
    });

    testWidgets('background: a tapped push opens its screen', (tester) async {
      await pumpApp(tester);

      messaging.opened.add(push('date_cancelled', dateId: '8'));
      await tester.pumpAndSettle();

      expect(find.text('/dates/detail 8'), findsOneWidget);
    });

    testWidgets('background: an unknown type does nothing', (tester) async {
      await pumpApp(tester);

      messaging.opened.add(push('something_new'));
      await tester.pumpAndSettle();

      expect(find.text('/match'), findsOneWidget);
    });
  });

  group('foreground banner', () {
    testWidgets('shows the title and body, and a tap opens the screen', (tester) async {
      await pumpApp(tester);

      messaging.foreground.add(push('chat_message', title: 'Muse', body: 'New message from Alex'));
      await tester.pumpAndSettle();
      expect(find.text('New message from Alex'), findsOneWidget);
      // Nothing navigates until it is tapped.
      expect(find.text('/match'), findsOneWidget);

      await tester.tap(find.byType(PushBanner));
      await tester.pumpAndSettle();

      expect(find.text('/date-chat 42'), findsOneWidget);
      expect(find.byType(PushBanner), findsNothing);
    });

    testWidgets('is skipped while that chat is on screen', (tester) async {
      await pumpApp(tester);
      container.read(activeChatDateIdProvider.notifier).state = '42';

      messaging.foreground.add(push('chat_message', dateId: '42'));
      await tester.pumpAndSettle();

      expect(find.byType(PushBanner), findsNothing);
    });

    testWidgets('still shows for a different date\'s chat', (tester) async {
      await pumpApp(tester);
      container.read(activeChatDateIdProvider.notifier).state = '42';

      messaging.foreground.add(push('chat_message', dateId: '43'));
      await tester.pumpAndSettle();

      expect(find.byType(PushBanner), findsOneWidget);
    });

    testWidgets('a newer push replaces the one on show', (tester) async {
      await pumpApp(tester);

      messaging.foreground.add(push('chat_opened', body: 'Your chat with Alex is open'));
      await tester.pumpAndSettle();
      messaging.foreground.add(push('chat_message', body: 'New message from Alex'));
      await tester.pumpAndSettle();

      expect(find.byType(PushBanner), findsOneWidget);
      expect(find.text('New message from Alex'), findsOneWidget);
      expect(find.text('Your chat with Alex is open'), findsNothing);
    });

    testWidgets('hides itself after a few seconds', (tester) async {
      await pumpApp(tester);

      messaging.foreground.add(push('chat_message'));
      await tester.pumpAndSettle();
      expect(find.byType(PushBanner), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.byType(PushBanner), findsNothing);
    });

    testWidgets('is not shown when signed out', (tester) async {
      await pumpApp(tester, uid: null);

      messaging.foreground.add(push('chat_message'));
      await tester.pumpAndSettle();

      expect(find.byType(PushBanner), findsNothing);
    });
  });

  test('PushMessage reads the date id as a String', () {
    expect(const PushMessage(data: {'type': 'chat_message', 'dateId': 42}).dateId, '42');
  });
}
