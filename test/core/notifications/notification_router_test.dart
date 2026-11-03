import 'package:eros_app/core/navigation/app_navigator.dart';
import 'package:eros_app/core/notifications/notification_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_messaging.dart';
import 'notification_test_app.dart';

void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late HomeRouteObserver observer;

  setUp(() {
    navigatorKey = GlobalKey<NavigatorState>();
    observer = HomeRouteObserver();
  });

  NotificationRouter router({bool chatRouteEnabled = true}) => NotificationRouter(
        navigatorKey: navigatorKey,
        isHomeInStack: observer.isHomeInStack,
        chatRouteEnabled: chatRouteEnabled,
      );

  group('targetFor', () {
    test('chat_opened and chat_message open the chat for data.dateId', () {
      final r = router();
      expect(r.targetFor(push('chat_opened')), const NotificationTarget('/date-chat', '42'));
      expect(r.targetFor(push('chat_message')), const NotificationTarget('/date-chat', '42'));
    });

    test('until the chat route lands, chat pushes open date detail', () {
      final r = router(chatRouteEnabled: false);
      expect(r.targetFor(push('chat_message')), const NotificationTarget('/dates/detail', '42'));
    });

    test('date_cancelled opens date detail', () {
      expect(router().targetFor(push('date_cancelled')), const NotificationTarget('/dates/detail', '42'));
    });

    test('an unknown type, no type, or no date id routes nowhere', () {
      final r = router();
      expect(r.targetFor(push('match_found')), isNull);
      expect(r.targetFor(push(null)), isNull);
      expect(r.targetFor(push('chat_message', dateId: null)), isNull);
    });
  });

  group('open', () {
    testWidgets('pushes the target over home', (tester) async {
      await tester.pumpWidget(NotificationTestApp(navigatorKey: navigatorKey, observer: observer));
      final r = router();

      r.open(push('chat_message'));
      await tester.pumpAndSettle();
      expect(find.text('/date-chat 42'), findsOneWidget);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('/match'), findsOneWidget);
    });

    testWidgets('date_cancelled pushes date detail', (tester) async {
      await tester.pumpWidget(NotificationTestApp(navigatorKey: navigatorKey, observer: observer));

      router().open(push('date_cancelled', dateId: '9'));
      await tester.pumpAndSettle();

      expect(find.text('/dates/detail 9'), findsOneWidget);
    });

    testWidgets('an unknown type does nothing', (tester) async {
      await tester.pumpWidget(NotificationTestApp(navigatorKey: navigatorKey, observer: observer));
      final r = router();

      r.open(push('something_new'));
      await tester.pumpAndSettle();

      expect(find.text('/match'), findsOneWidget);
      expect(r.pending, isNull);
    });

    testWidgets('does not stack a second copy of the screen already on top', (tester) async {
      await tester.pumpWidget(NotificationTestApp(navigatorKey: navigatorKey, observer: observer));
      final r = router();

      r.open(push('chat_message'));
      await tester.pumpAndSettle();
      r.open(push('chat_message'));
      await tester.pumpAndSettle();

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('/match'), findsOneWidget);
    });

    testWidgets('before home is reached (cold start), waits and opens once home is pushed', (tester) async {
      await tester.pumpWidget(NotificationTestApp(
        navigatorKey: navigatorKey,
        observer: observer,
        initialRoute: '/',
      ));
      final r = router();

      r.open(push('chat_opened', dateId: '7'));
      await tester.pumpAndSettle();
      expect(find.text('/'), findsOneWidget);
      expect(r.pending, const NotificationTarget('/date-chat', '7'));

      // The auth screen replaces itself with home.
      navigatorKey.currentState!.pushReplacementNamed(homeRoute);
      await tester.pumpAndSettle();

      expect(find.text('/date-chat 7'), findsOneWidget);
      expect(r.pending, isNull);
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('/match'), findsOneWidget);
    });
  });
}
