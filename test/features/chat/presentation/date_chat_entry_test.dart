import 'package:eros_app/features/chat/data/models/chat_models.dart';
import 'package:eros_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:eros_app/features/chat/presentation/widgets/chat_copy.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/screens/date_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat_test_harness.dart';
import '../fake_chat_repository.dart';

late ProviderContainer _container;

Future<FakeChatRepository> _pumpDetail(
  WidgetTester tester, {
  required DateState state,
  required ChatStatus chat,
  int unreadCount = 0,
}) async {
  final repo = FakeChatRepository(status: chat);
  repo.chat = chatState(chat, unreadCount: unreadCount);
  final overrides = await chatOverrides(chat: repo, date: chatDate(state: state, chat: chat));
  _container = ProviderContainer(overrides: overrides);
  addTearDown(_container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: _container,
    child: const MaterialApp(home: DateDetailScreen(dateId: '42')),
  ));
  await tester.pump();
  await tester.pump();
  return repo;
}

/// Leaves the screen with the provider scope still mounted, so auto-dispose providers (and the
/// chat's poll) are disposed before the test ends.
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(UncontrolledProviderScope(
    container: _container,
    // A new key replaces the navigator, so pushed routes go too.
    child: const MaterialApp(key: ValueKey('closed'), home: SizedBox.shrink()),
  ));
  await tester.pump();
  await tester.pump();
}

final _messageAlex = find.text(ChatCopy.messagePartner('Alex'));
final _unreadDot = find.byKey(const ValueKey('chat-unread-dot'));

void main() {
  group('OPEN', () {
    testWidgets('a venueAssigned date with an open chat shows the button', (tester) async {
      await _pumpDetail(tester, state: DateState.venueAssigned, chat: ChatStatus.open);

      expect(_messageAlex, findsOneWidget);

      await _close(tester);
    });

    testWidgets('a ready date keeps its CTA text under the button', (tester) async {
      await _pumpDetail(tester, state: DateState.ready, chat: ChatStatus.open);

      expect(_messageAlex, findsOneWidget);
      expect(find.text('You\'re both confirmed. See you there.'), findsOneWidget);

      await _close(tester);
    });

    testWidgets('shows the unread dot from GET .../chat', (tester) async {
      final repo = await _pumpDetail(tester, state: DateState.ready, chat: ChatStatus.open, unreadCount: 2);

      expect(_unreadDot, findsOneWidget);
      expect(repo.calls, contains('getChat'));

      await _close(tester);
    });

    testWidgets('shows no dot with nothing unread', (tester) async {
      await _pumpDetail(tester, state: DateState.ready, chat: ChatStatus.open);

      expect(_unreadDot, findsNothing);

      await _close(tester);
    });

    testWidgets('the button opens the chat screen', (tester) async {
      await _pumpDetail(tester, state: DateState.ready, chat: ChatStatus.open);

      await tester.tap(_messageAlex);
      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);

      await _close(tester);
    });
  });

  group('CLOSED', () {
    testWidgets('shows a quiet "View messages" link', (tester) async {
      await _pumpDetail(tester, state: DateState.completed, chat: ChatStatus.closed);

      expect(find.text(ChatCopy.viewMessages), findsOneWidget);
      expect(_messageAlex, findsNothing);

      await _close(tester);
    });
  });

  group('NOT_OPEN', () {
    testWidgets('awaiting presence confirmation adds the "once you\'ve both confirmed" line', (tester) async {
      await _pumpDetail(tester, state: DateState.awaitingPresenceConfirmation, chat: ChatStatus.notOpen);

      expect(find.text(ChatCopy.opensAfterConfirming), findsOneWidget);
      expect(_messageAlex, findsNothing);

      await _close(tester);
    });

    testWidgets('shows nothing in other states, even ready', (tester) async {
      final repo = await _pumpDetail(tester, state: DateState.ready, chat: ChatStatus.notOpen);

      expect(find.text(ChatCopy.opensAfterConfirming), findsNothing);
      expect(_messageAlex, findsNothing);
      expect(find.text(ChatCopy.viewMessages), findsNothing);
      expect(repo.calls, isEmpty);

      await _close(tester);
    });
  });

  group('ARCHIVED', () {
    testWidgets('shows nothing', (tester) async {
      await _pumpDetail(tester, state: DateState.completed, chat: ChatStatus.archived);

      expect(_messageAlex, findsNothing);
      expect(find.text(ChatCopy.viewMessages), findsNothing);

      await _close(tester);
    });
  });
}
