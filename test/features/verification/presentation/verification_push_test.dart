import 'package:eros_app/core/navigation/app_navigator.dart';
import 'package:eros_app/core/notifications/messaging_client.dart';
import 'package:eros_app/core/notifications/notification_router.dart';
import 'package:eros_app/core/notifications/push_host.dart';
import 'package:eros_app/core/notifications/push_service.dart';
import 'package:eros_app/features/verification/presentation/screens/verification_status_screen.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_profile_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/fake_messaging.dart';
import '../fake_verification_http.dart';
import 'verification_status_harness.dart';

/// The decision push (VF-B6's `{ type: "VERIFICATION_DECIDED" }`) and the refresh on resume,
/// through the app's real [PushHost] and [NotificationRouter].
void main() {
  late StubHttp http;
  late SharedPreferences prefs;
  late FakeMessagingClient messaging;
  late GlobalKey<NavigatorState> navigatorKey;
  late HomeRouteObserver observer;

  setUp(() async {
    http = StubHttp();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    messaging = FakeMessagingClient();
    navigatorKey = GlobalKey<NavigatorState>();
    observer = HomeRouteObserver();
    http.responses['GET $statusPath'] = reply(200, statusJson('IN_REVIEW', canStart: false));
  });

  PushMessage decided({String? title = 'You\'re verified', String? body = 'Your date is waiting.'}) =>
      // The wire value VF-B6 sends, spelled out.
      push('VERIFICATION_DECIDED', dateId: null, title: title, body: body);

  /// Home is the Profile row, which keeps the status loaded as the Profile tab does.
  /// [home] replaces it, for a home that shows no status.
  Future<void> pumpApp(WidgetTester tester, {Widget? home}) async {
    tester.view.physicalSize = const Size(600, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...verificationOverrides(http: http, prefs: prefs),
        messagingClientProvider.overrideWithValue(messaging),
        pushServiceProvider.overrideWith((ref) => PushService(
              messaging: messaging,
              apiClient: () => FakeDevicesApi(),
              platform: 'IOS',
            )),
        notificationRouterProvider.overrideWith((ref) {
          final router = NotificationRouter(
            navigatorKey: navigatorKey,
            isHomeInStack: observer.isHomeInStack,
          );
          ref.onDispose(router.dispose);
          return router;
        }),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [observer],
        initialRoute: homeRoute,
        builder: (context, child) => PushHost(child: child!),
        routes: {
          homeRoute: (_) => Scaffold(body: home ?? const VerificationProfileRow()),
          VerificationStatusScreen.routeName: (_) => const VerificationStatusScreen(),
        },
      ),
    ));
    await settle(tester);
  }

  group('in the foreground', () {
    testWidgets('a decision push refreshes the status', (tester) async {
      await pumpApp(tester);
      expect(find.text('In review'), findsOneWidget);
      expect(statusFetches(http), 1);

      http.responses['GET $statusPath'] = reply(200, statusJson('VERIFIED', canStart: false));
      messaging.foreground.add(decided());
      await settle(tester);

      expect(statusFetches(http), 2);
      expect(find.text('Verified'), findsOneWidget);
      // The banner still shows, worded by the server.
      expect(find.text('You\'re verified'), findsOneWidget);
    });

    testWidgets('a decision push with nothing showing the status fetches nothing',
        (tester) async {
      await pumpApp(tester, home: const Text('Elsewhere'));

      messaging.foreground.add(decided());
      await settle(tester);

      expect(statusFetches(http), 0);
    });

    testWidgets('tapping its banner opens the status screen', (tester) async {
      await pumpApp(tester);

      messaging.foreground.add(decided());
      await settle(tester);
      await tester.tap(find.text('Your date is waiting.'));
      await settle(tester);

      expect(find.byType(VerificationStatusScreen), findsOneWidget);
    });

    testWidgets('another type of push leaves the status alone', (tester) async {
      await pumpApp(tester);

      messaging.foreground.add(push('chat_message', dateId: '5'));
      await settle(tester);

      expect(statusFetches(http), 1);
    });
  });

  testWidgets('a tapped decision push opens the status screen, once', (tester) async {
    await pumpApp(tester);

    messaging.opened.add(decided());
    await settle(tester);
    expect(find.byType(VerificationStatusScreen), findsOneWidget);
    expect(find.text(VerificationCopy.inReview), findsOneWidget);

    // Tapped again while it's on top: no second copy.
    messaging.opened.add(decided());
    await settle(tester);
    expect(find.byType(VerificationStatusScreen), findsOneWidget);
  });

  testWidgets('from killed, the launching decision push opens the status screen',
      (tester) async {
    messaging.initialMessage = decided();
    await pumpApp(tester);

    expect(find.byType(VerificationStatusScreen), findsOneWidget);
  });

  testWidgets('resuming the app refreshes the status, push or no push', (tester) async {
    await pumpApp(tester);
    expect(statusFetches(http), 1);

    http.responses['GET $statusPath'] = reply(200, statusJson('RETRY', reason: 'UNCLEAR'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);

    expect(statusFetches(http), 2);
    expect(find.text('Action needed'), findsOneWidget);
  });
}
