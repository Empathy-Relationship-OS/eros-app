import 'package:eros_app/features/chat/data/models/chat_models.dart';
import 'package:eros_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:eros_app/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat_test_harness.dart';
import '../fake_chat_repository.dart';

Future<ProviderContainer> _pump(WidgetTester tester, FakeChatRepository chat) async {
  final container = ProviderContainer(overrides: await chatOverrides(chat: chat, date: chatDate()));
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: ChatScreen(dateId: '42')),
  ));
  await tester.pump();
  await tester.pump();
  return container;
}

/// Closes the screen, so its notifier is disposed before the test ends.
Future<void> _close(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(key: ValueKey('closed'), home: SizedBox.shrink()),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('a messages signal shows the new message straight away', (tester) async {
    final chat = FakeChatRepository()..addPartnerMessage('Hi');
    final container = await _pump(tester, chat);
    chat.stream.open();

    chat.addPartnerMessage('Just parking');
    chat.stream.send(const MessagesSignal(2));
    await tester.pump();
    await tester.pump();

    expect(find.byType(ChatBubble), findsNWidgets(2));
    await _close(tester, container);
  });

  testWidgets('backgrounding closes the stream, and returning catches up and reconnects', (tester) async {
    final chat = FakeChatRepository()..addPartnerMessage('Hi');
    final container = await _pump(tester, chat);
    chat.stream.open();
    expect(chat.streams, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(chat.stream.cancelled, isTrue);

    chat.addPartnerMessage('Sent while you were away');
    chat.calls.clear();
    await tester.pump(const Duration(minutes: 1));
    expect(chat.calls, isEmpty, reason: 'no polling in the background');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(chat.calls.first, 'getMessages after:1');
    expect(find.byType(ChatBubble), findsNWidgets(2));
    expect(chat.streams, hasLength(2));

    await _close(tester, container);
  });

  testWidgets('leaving the screen closes the stream', (tester) async {
    final chat = FakeChatRepository();
    final container = await _pump(tester, chat);
    chat.stream.open();

    await _close(tester, container);

    expect(chat.stream.cancelled, isTrue);
  });
}
