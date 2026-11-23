import 'package:eros_app/core/navigation/app_navigator.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/notifications/messaging_client.dart';
import 'package:eros_app/core/notifications/notification_router.dart';
import 'package:eros_app/core/notifications/push_banner.dart';
import 'package:eros_app/core/notifications/push_host.dart';
import 'package:eros_app/core/notifications/push_service.dart';
import 'package:eros_app/features/legal/data/repositories/notices_repository.dart';
import 'package:eros_app/features/legal/presentation/providers/safety_notice_controller.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_copy.dart';
import 'package:eros_app/features/legal/presentation/widgets/safety_notice_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/notifications/fake_messaging.dart';
import '../../core/notifications/notification_test_app.dart';
import 'fake_notices_api.dart';

final _uid = StateProvider<String?>((ref) => 'alice');

PushMessage _safetyPush() =>
    push(PushType.safetyNotice, dateId: null, title: 'A safety notice', body: null);

void main() {
  late FakeMessagingClient messaging;
  late FakeNoticesApi api;
  late GlobalKey<NavigatorState> navigatorKey;
  late HomeRouteObserver observer;
  late ProviderContainer container;
  late List<Uri> opened;

  setUp(() {
    messaging = FakeMessagingClient();
    api = FakeNoticesApi();
    navigatorKey = GlobalKey<NavigatorState>();
    observer = HomeRouteObserver();
    opened = [];
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    String? uid = 'alice',
    String initialRoute = homeRoute,
  }) async {
    container = ProviderContainer(overrides: [
      _uid.overrideWith((ref) => uid),
      signedInUidProvider.overrideWith((ref) => ref.watch(_uid)),
      messagingClientProvider.overrideWithValue(messaging),
      pushServiceProvider.overrideWith((ref) {
        final service =
            PushService(messaging: messaging, apiClient: () => FakeDevicesApi(), platform: 'IOS');
        ref.onDispose(service.dispose);
        return service;
      }),
      notificationRouterProvider.overrideWith((ref) => NotificationRouter(
            navigatorKey: navigatorKey,
            isHomeInStack: observer.isHomeInStack,
          )),
      noticesRepositoryProvider.overrideWithValue(NoticesRepository(api)),
      safetyNoticeControllerProvider.overrideWith((ref) {
        final controller = SafetyNoticeController(
          repository: () => ref.read(noticesRepositoryProvider),
          navigatorKey: navigatorKey,
          isHomeInStack: observer.isHomeInStack,
          openUrl: (url) async {
            opened.add(url);
            return true;
          },
        );
        ref.onDispose(controller.dispose);
        return controller;
      }),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: NotificationTestApp(
        navigatorKey: navigatorKey,
        observer: observer,
        initialRoute: initialRoute,
        builder: (context, child) => PushHost(child: child!),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> resume(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  final sheet = find.byType(SafetyNoticeSheet);

  group('on launch', () {
    testWidgets('an unread notice shows once and OK marks it read', (tester) async {
      api.notices.add(fraudNotice(7));
      await pumpApp(tester);

      expect(sheet, findsOneWidget);
      expect(find.text(SafetyNoticeCopy.title), findsOneWidget);
      expect(find.text(SafetyNoticeCopy.fraudContactBanned), findsOneWidget);

      await tester.tap(find.text(SafetyNoticeCopy.ok));
      await tester.pumpAndSettle();

      expect(sheet, findsNothing);
      expect(api.posts, ['/users/me/notices/7/read']);

      // The server now says it's read, so a resume shows nothing.
      await resume(tester);
      expect(sheet, findsNothing);
      expect(api.posts, hasLength(1));
    });

    testWidgets('no notice shows nothing', (tester) async {
      await pumpApp(tester);

      expect(api.gets, ['/users/me/notices']);
      expect(sheet, findsNothing);
    });

    testWidgets('a read notice shows nothing', (tester) async {
      api.notices.add(fraudNotice(7, read: true));
      await pumpApp(tester);

      expect(sheet, findsNothing);
    });

    testWidgets('a kind the app has no copy for shows nothing', (tester) async {
      api.notices.add(fraudNotice(7, kind: 'SOMETHING_NEW'));
      await pumpApp(tester);

      expect(sheet, findsNothing);
    });

    testWidgets('two unread notices show one after the other, oldest first', (tester) async {
      api.notices.addAll([fraudNotice(9), fraudNotice(7)]);
      await pumpApp(tester);

      await tester.tap(find.text(SafetyNoticeCopy.ok));
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);

      await tester.tap(find.text(SafetyNoticeCopy.ok));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(api.posts, ['/users/me/notices/7/read', '/users/me/notices/9/read']);
    });

    testWidgets('waits until the user reaches home', (tester) async {
      api.notices.add(fraudNotice(7));
      await pumpApp(tester, initialRoute: '/welcome');

      expect(api.gets, isEmpty);
      expect(sheet, findsNothing);

      navigatorKey.currentState!.pushReplacementNamed(homeRoute);
      await tester.pumpAndSettle();

      expect(sheet, findsOneWidget);
    });

    testWidgets('signed out, it fetches nothing', (tester) async {
      api.notices.add(fraudNotice(7));
      await pumpApp(tester, uid: null);
      await resume(tester);

      expect(api.gets, isEmpty);
      expect(sheet, findsNothing);
    });

    testWidgets('a failed fetch shows nothing and the next resume tries again', (tester) async {
      api
        ..notices.add(fraudNotice(7))
        ..getError = const NetworkException('offline');
      await pumpApp(tester);
      expect(sheet, findsNothing);

      await resume(tester);
      expect(sheet, findsOneWidget);
    });
  });

  group('dismissing', () {
    testWidgets('a swipe leaves it unread, and it shows again on resume', (tester) async {
      api.notices.add(fraudNotice(7));
      await pumpApp(tester);

      await tester.tapAt(const Offset(10, 10)); // The barrier.
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(api.posts, isEmpty);

      await resume(tester);
      expect(sheet, findsOneWidget);
    });

    testWidgets('a failed mark-read keeps it for the next resume', (tester) async {
      api
        ..notices.add(fraudNotice(7))
        ..postError = const NetworkException('offline');
      await pumpApp(tester);

      await tester.tap(find.text(SafetyNoticeCopy.ok));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);

      api.postError = null;
      await resume(tester);
      expect(sheet, findsOneWidget);
    });
  });

  group('push', () {
    testWidgets('a foreground SAFETY_NOTICE refetches and shows the sheet, not the banner',
        (tester) async {
      await pumpApp(tester);
      expect(api.gets, hasLength(1));

      api.notices.add(fraudNotice(7));
      messaging.foreground.add(_safetyPush());
      await tester.pumpAndSettle();

      expect(api.gets, hasLength(2));
      expect(sheet, findsOneWidget);
      expect(find.byType(PushBanner), findsNothing);
    });

    testWidgets('a tapped SAFETY_NOTICE from the background opens it', (tester) async {
      await pumpApp(tester);

      api.notices.add(fraudNotice(7));
      messaging.opened.add(_safetyPush());
      await tester.pumpAndSettle();

      expect(api.gets, hasLength(2));
      expect(sheet, findsOneWidget);
    });

    testWidgets('a SAFETY_NOTICE that launched the app opens it', (tester) async {
      messaging.initialMessage = _safetyPush();
      api.notices.add(fraudNotice(7));
      await pumpApp(tester);

      expect(sheet, findsOneWidget);
    });

    testWidgets('a push while the sheet is up does not stack a second one', (tester) async {
      api.notices.add(fraudNotice(7));
      await pumpApp(tester);

      messaging.foreground.add(_safetyPush());
      await resume(tester);

      expect(sheet, findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
    });
  });

  group('Read more', () {
    testWidgets('opens the notice document', (tester) async {
      api.notices.add(fraudNotice(7));
      await pumpApp(tester);

      await tester.tap(find.text(SafetyNoticeCopy.readMore));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse('https://muse.app/legal/fraud-notice')]);
      // Reading more doesn't acknowledge it; OK does.
      expect(sheet, findsOneWidget);
      expect(api.posts, isEmpty);
    });

    testWidgets('is hidden when the notice has no document', (tester) async {
      api.notices.add(fraudNotice(7, documentUrl: null));
      await pumpApp(tester);

      expect(sheet, findsOneWidget);
      expect(find.text(SafetyNoticeCopy.readMore), findsNothing);
      expect(find.text(SafetyNoticeCopy.ok), findsOneWidget);
    });
  });
}
