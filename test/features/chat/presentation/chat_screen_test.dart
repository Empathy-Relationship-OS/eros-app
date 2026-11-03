import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/notifications/active_chat_provider.dart';
import 'package:eros_app/features/chat/data/models/chat_models.dart';
import 'package:eros_app/features/chat/data/repositories/chat_repository.dart';
import 'package:eros_app/features/chat/presentation/providers/chat_screen_providers.dart';
import 'package:eros_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:eros_app/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:eros_app/features/chat/presentation/widgets/chat_copy.dart';
import 'package:eros_app/features/chat/presentation/widgets/contact_tip_sheet.dart';
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

  group('quick replies (CH-F3)', () {
    testWidgets('shows the chips the response gives, and none of its own', (tester) async {
      const fromServer = [
        QuickReply(key: 'TEST_ONE', text: 'Copy only the server knows'),
        QuickReply(key: 'TEST_TWO', text: 'Another server reply'),
      ];
      final chat = FakeChatRepository()..chat = chatState(ChatStatus.open, quickReplies: fromServer);
      await _pump(tester, chat);

      expect(find.byType(ActionChip), findsNWidgets(2));
      expect(find.widgetWithText(ActionChip, 'Copy only the server knows'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Another server reply'), findsOneWidget);
      for (final reply in rfcQuickReplies) {
        expect(find.text(reply.text), findsNothing);
      }

      await _close(tester);
    });

    testWidgets('shows no chips when the response has none', (tester) async {
      final chat = FakeChatRepository()..chat = chatState(ChatStatus.open, quickReplies: const []);
      await _pump(tester, chat);

      expect(find.byType(ActionChip), findsNothing);
      expect(find.byType(TextField), findsOneWidget);

      await _close(tester);
    });

    testWidgets('a tap sends the key straight away and shows its text', (tester) async {
      final chat = FakeChatRepository();
      await _pump(tester, chat);

      await tester.tap(find.widgetWithText(ActionChip, 'Running 5 minutes late'));
      await tester.pump();

      expect(chat.stored.single.quickReplyKey, 'RUNNING_LATE');
      expect(chat.stored.single.kind, ChatMessageKind.quickReply);
      expect(find.widgetWithText(ChatBubble, 'Running 5 minutes late'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'I\'m here'));
      await tester.pump();
      expect(chat.sentClientIds.toSet(), hasLength(2));

      await _close(tester);
    });

    testWidgets('hide when the chat is CLOSED', (tester) async {
      await _pump(
        tester,
        FakeChatRepository(status: ChatStatus.closed)..addPartnerMessage('Thanks for tonight'),
        date: chatDate(state: DateState.completed, chat: ChatStatus.closed),
      );

      expect(find.byType(ActionChip), findsNothing);

      await _close(tester);
    });

    testWidgets('hide as soon as the chat closes while open', (tester) async {
      final chat = FakeChatRepository();
      await _pump(tester, chat);
      expect(find.byType(ActionChip), findsWidgets);

      chat.chat = chatState(ChatStatus.closed);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.byType(ActionChip), findsNothing);

      await _close(tester);
    });
  });

  group('"Seen" (CH-F3)', () {
    Finder seenUnder(String text) => find.descendant(
          of: find.widgetWithText(ChatBubble, text),
          matching: find.text(ChatCopy.seen),
        );

    testWidgets('shows under my newest read message, once, and moves on', (tester) async {
      final chat = FakeChatRepository()
        ..addMyMessage('On my way') // 1
        ..addPartnerMessage('Great') // 2
        ..addMyMessage('At the door') // 3
        ..addMyMessage('Inside now'); // 4
      chat.chat = chatState(ChatStatus.open, partnerLastReadSeq: 1);
      await _pump(tester, chat);

      expect(find.text(ChatCopy.seen), findsOneWidget);
      expect(seenUnder('On my way'), findsOneWidget);

      chat.chat = chatState(ChatStatus.open, partnerLastReadSeq: 3);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.text(ChatCopy.seen), findsOneWidget);
      expect(seenUnder('At the door'), findsOneWidget);

      chat.chat = chatState(ChatStatus.open, partnerLastReadSeq: 4);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.text(ChatCopy.seen), findsOneWidget);
      expect(seenUnder('Inside now'), findsOneWidget);

      await _close(tester);
    });

    testWidgets('isn\'t shown before the partner has read anything of mine', (tester) async {
      final chat = FakeChatRepository()
        ..addPartnerMessage('Hi')
        ..addMyMessage('Hello');
      chat.chat = chatState(ChatStatus.open, partnerLastReadSeq: 1);
      await _pump(tester, chat);

      expect(find.text(ChatCopy.seen), findsNothing);

      await _close(tester);
    });
  });

  group('mark as read (CH-F3)', () {
    testWidgets('posts the highest seq after a second on screen', (tester) async {
      final chat = FakeChatRepository()
        ..addPartnerMessage('Hi')
        ..addPartnerMessage('Where are you?');
      await _pump(tester, chat);

      expect(chat.readSeqs, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(chat.readSeqs, [2]);

      await _close(tester);
    });

    testWidgets('posts nothing while the app is in the background', (tester) async {
      final chat = FakeChatRepository()..addPartnerMessage('Hi');
      await _pump(tester, chat);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 2));
      expect(chat.readSeqs, isEmpty);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      expect(chat.readSeqs, [1]);

      await _close(tester);
    });
  });

  group('contact tip (CH-F3)', () {
    testWidgets('shows once, the first time a flagged message shows', (tester) async {
      final chat = FakeChatRepository()
        ..addPartnerMessage('Running late')
        ..addPartnerMessage('Text me on 07700 900123', contactDetected: true);
      final container = await _pump(tester, chat);
      await tester.pumpAndSettle();

      expect(find.byType(ContactTipSheet), findsOneWidget);
      expect(find.text(ChatCopy.contactTip), findsOneWidget);
      expect(container.read(contactTipStoreProvider).hasSeen('me'), isTrue);

      await tester.tap(find.text(ChatCopy.contactTipDismiss));
      await tester.pumpAndSettle();
      expect(find.byType(ContactTipSheet), findsNothing);

      // Another flagged message on the same screen doesn't bring it back.
      chat.addPartnerMessage('Or email me', contactDetected: true);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(ContactTipSheet), findsNothing);

      await _close(tester);
    });

    testWidgets('never shows again once seen, in any chat', (tester) async {
      final chat = FakeChatRepository()..addPartnerMessage('My number is 07700 900123', contactDetected: true);
      await _pump(tester, chat, prefs: {'chat_contact_tip_seen_me': true});
      await tester.pumpAndSettle();

      expect(find.byType(ContactTipSheet), findsNothing);

      await _close(tester);
    });

    testWidgets('shows to the sender too, once the server flags their message', (tester) async {
      final chat = FakeChatRepository();
      await _pump(tester, chat);
      expect(find.byType(ContactTipSheet), findsNothing);

      await _typeAndSend(tester, 'I\'m @alex_out');
      await tester.pumpAndSettle();

      expect(find.byType(ContactTipSheet), findsOneWidget);
      // It never blocks the send.
      expect(chat.stored.single.contactDetected, isTrue);

      await _close(tester);
    });

    testWidgets('doesn\'t show for unflagged messages', (tester) async {
      await _pump(tester, FakeChatRepository()..addPartnerMessage('See you at 7'));
      await tester.pumpAndSettle();

      expect(find.byType(ContactTipSheet), findsNothing);

      await _close(tester);
    });
  });
}
