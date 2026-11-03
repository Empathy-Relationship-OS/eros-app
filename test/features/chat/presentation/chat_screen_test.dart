import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/notifications/active_chat_provider.dart';
import 'package:eros_app/features/chat/data/models/chat_models.dart';
import 'package:eros_app/features/chat/data/repositories/chat_repository.dart';
import 'package:eros_app/features/chat/presentation/providers/chat_screen_providers.dart';
import 'package:eros_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:eros_app/features/chat/presentation/widgets/chat_copy.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/safety/presentation/screens/report_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../chat_test_harness.dart';
import '../fake_chat_repository.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeChatRepository chat, {
  DateDetail? date,
  bool notificationsEnabled = true,
  Map<String, Object> prefs = const {},
}) async {
  final overrides = await chatOverrides(
    chat: chat,
    date: date ?? chatDate(),
    notificationsEnabled: notificationsEnabled,
    prefs: prefs,
  );
  final container = _container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: ChatScreen(dateId: '42')),
  ));
  await tester.pump();
  await tester.pump();
  return container;
}

late ProviderContainer _container;

/// Closes the screen, so its notifier stops polling before the test ends. The provider scope
/// stays mounted: Riverpod disposes auto-dispose providers on the scope's next frame.
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(UncontrolledProviderScope(
    container: _container,
    // A new key replaces the navigator, so pushed routes go too.
    child: const MaterialApp(key: ValueKey('closed'), home: SizedBox.shrink()),
  ));
  await tester.pump();
  await tester.pump();
}

Future<void> _typeAndSend(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.byTooltip(ChatCopy.send));
  await tester.pump();
}

void main() {
  group('OPEN', () {
    testWidgets('shows the header, the intro once, messages and the input', (tester) async {
      final chat = FakeChatRepository()..addPartnerMessage('Just parking, 5 minutes');

      final container = await _pump(tester, chat);

      expect(find.text('Alex'), findsOneWidget);
      final closes = DateFormat('HH:mm').format(DateTime.utc(2026, 11, 7, 21).toLocal());
      expect(find.textContaining(ChatCopy.closesAt('')), findsOneWidget);
      expect(find.textContaining(closes), findsOneWidget);
      expect(find.text(ChatCopy.intro), findsOneWidget);
      expect(find.text('Just parking, 5 minutes'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(container.read(chatIntroStoreProvider).hasSeen('me', '42'), isTrue);

      await _close(tester);
    });

    testWidgets('doesn\'t show the intro again for a chat already opened', (tester) async {
      await _pump(tester, FakeChatRepository(), prefs: {'chat_intro_seen_me_42': true});

      expect(find.text(ChatCopy.intro), findsNothing);

      await _close(tester);
    });

    testWidgets('sets activeChatDateIdProvider while open, and clears it on close', (tester) async {
      final container = await _pump(tester, FakeChatRepository());

      expect(container.read(activeChatDateIdProvider), '42');

      await _close(tester);
      expect(container.read(activeChatDateIdProvider), isNull);
    });

    testWidgets('sends a message and shows it', (tester) async {
      final chat = FakeChatRepository();
      await _pump(tester, chat);

      await _typeAndSend(tester, 'By the door');

      expect(find.text('By the door'), findsOneWidget);
      expect(chat.stored.single.text, 'By the door');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

      await _close(tester);
    });

    testWidgets('a failed send says "Not sent, tap to retry", and a tap retries', (tester) async {
      final chat = FakeChatRepository()..sendError = const NetworkException('offline');
      await _pump(tester, chat);

      await _typeAndSend(tester, 'Running late');

      expect(find.text(ChatCopy.notSentRetry), findsOneWidget);

      chat.sendError = null;
      await tester.tap(find.text(ChatCopy.notSentRetry));
      await tester.pump();

      expect(find.text(ChatCopy.notSentRetry), findsNothing);
      expect(chat.sentClientIds.toSet(), hasLength(1));
      expect(find.text('Running late'), findsOneWidget);

      await _close(tester);
    });

    testWidgets('a 422 puts the text back in the box and explains', (tester) async {
      final chat = FakeChatRepository()..sendResult = const MessageRejected();
      await _pump(tester, chat);

      await _typeAndSend(tester, 'something rude');

      expect(find.text(ChatCopy.rejected), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'something rude');
      // Only the text in the box, no bubble.
      expect(find.text('something rude'), findsOneWidget);

      await _close(tester);
    });

    testWidgets('shows a slim banner when notifications are off', (tester) async {
      await _pump(tester, FakeChatRepository(), notificationsEnabled: false);

      expect(find.text(ChatCopy.notificationsOff('Alex')), findsOneWidget);
      expect(find.text(ChatCopy.openSettings), findsOneWidget);

      await _close(tester);
    });

    testWidgets('"Report and block" in the ⋯ menu opens the report sheet', (tester) async {
      await _pump(tester, FakeChatRepository());

      await tester.tap(find.byTooltip(ChatCopy.moreOptions));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ChatCopy.reportAndBlock));
      await tester.pumpAndSettle();

      expect(find.byType(ReportSheet), findsOneWidget);

      await _close(tester);
    });

    testWidgets('goes read-only when the chat closes while open', (tester) async {
      final chat = FakeChatRepository();
      await _pump(tester, chat, date: chatDate(state: DateState.ready));

      chat.chat = chatState(ChatStatus.closed);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
      expect(find.text(ChatCopy.closedDateEnded), findsOneWidget);

      await _close(tester);
    });
  });

  group('CLOSED', () {
    testWidgets('shows the messages and "when your date ended" in place of the input', (tester) async {
      final chat = FakeChatRepository(status: ChatStatus.closed)..addPartnerMessage('Thanks for tonight');

      await _pump(tester, chat, date: chatDate(state: DateState.completed, chat: ChatStatus.closed));

      expect(find.text('Thanks for tonight'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text(ChatCopy.closedDateEnded), findsOneWidget);
      expect(find.text(ChatCopy.chatClosed), findsOneWidget);

      await _close(tester);
    });

    testWidgets('says "when the date was cancelled" for a cancelled date', (tester) async {
      await _pump(
        tester,
        FakeChatRepository(status: ChatStatus.closed),
        date: chatDate(state: DateState.cancelled, chat: ChatStatus.closed),
      );

      expect(find.text(ChatCopy.closedDateCancelled), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await _close(tester);
    });

    testWidgets('a failed message can\'t be retried', (tester) async {
      final chat = FakeChatRepository()..sendError = const NetworkException('offline');
      await _pump(tester, chat);
      await _typeAndSend(tester, 'Here');

      chat.chat = chatState(ChatStatus.closed);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.text(ChatCopy.notSent), findsOneWidget);
      expect(find.text(ChatCopy.notSentRetry), findsNothing);

      await _close(tester);
    });
  });

  group('NOT_OPEN', () {
    testWidgets('explains when it opens, with no input', (tester) async {
      await _pump(
        tester,
        FakeChatRepository(status: ChatStatus.notOpen),
        date: chatDate(state: DateState.awaitingPresenceConfirmation, chat: ChatStatus.notOpen),
      );

      expect(find.text(ChatCopy.opensAfterConfirming), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await _close(tester);
    });
  });

  group('ARCHIVED', () {
    testWidgets('says the messages are no longer available', (tester) async {
      await _pump(
        tester,
        FakeChatRepository(status: ChatStatus.archived),
        date: chatDate(state: DateState.completed, chat: ChatStatus.archived),
      );

      expect(find.text(ChatCopy.archived), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await _close(tester);
    });
  });
}
