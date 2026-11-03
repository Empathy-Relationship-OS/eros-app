import 'dart:async';

import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/time/server_clock.dart';
import 'package:eros_app/features/chat/data/models/chat_models.dart';
import 'package:eros_app/features/chat/data/repositories/chat_repository.dart';
import 'package:eros_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../fake_chat_repository.dart';

const _pollInterval = Duration(seconds: 3);

({ChatNotifier notifier, FakeChatRepository repo}) _setUp({
  ChatStatus status = ChatStatus.open,
  void Function(FakeChatRepository repo)? seed,
}) {
  final repo = FakeChatRepository(status: status);
  seed?.call(repo);
  var ids = 0;
  final notifier = ChatNotifier(
    repo,
    '42',
    clock: ServerClock(deviceNow: () => DateTime.utc(2026, 11, 7, 19)),
    newClientMessageId: () => 'cid-${++ids}',
    pollInterval: _pollInterval,
    logger: Logger(level: Level.off),
    autoLoad: false,
  );
  addTearDown(notifier.dispose);
  return (notifier: notifier, repo: repo);
}

List<int?> _seqs(ChatNotifier notifier) => notifier.state.messages.map((m) => m.seq).toList();

void main() {
  group('load', () {
    test('fetches the status, then the latest page', () async {
      final (:notifier, :repo) = _setUp(seed: (repo) {
        repo.addPartnerMessage('Hi');
        repo.addPartnerMessage('See you at 7');
      });

      await notifier.load();

      expect(repo.calls, ['getChat', 'getMessages']);
      expect(notifier.state.status, ChatStatus.open);
      expect(_seqs(notifier), [1, 2]);
      expect(notifier.isPolling, isTrue);
    });

    test('fetches no messages and doesn\'t poll while NOT_OPEN', () async {
      final (:notifier, :repo) = _setUp(status: ChatStatus.notOpen);

      await notifier.load();

      expect(repo.calls, ['getChat']);
      expect(notifier.state.status, ChatStatus.notOpen);
      expect(notifier.isPolling, isFalse);
    });

    test('reads a CLOSED chat without polling', () async {
      final (:notifier, :repo) = _setUp(
        status: ChatStatus.closed,
        seed: (repo) => repo.addPartnerMessage('Thanks for tonight'),
      );

      await notifier.load();

      expect(_seqs(notifier), [1]);
      expect(notifier.state.canSend, isFalse);
      expect(notifier.isPolling, isFalse);
    });
  });

  group('send', () {
    test('shows the message at once as sending, then replaces it by clientMessageId', () async {
      final (:notifier, :repo) = _setUp();
      await notifier.load();
      repo.sendGate = Completer<void>();

      final outcome = notifier.send('  Just parking  ');

      final pending = notifier.state.messages.single;
      expect(pending.clientMessageId, 'cid-1');
      expect(pending.seq, isNull);
      expect(pending.sendState, ChatSendState.sending);
      expect(pending.text, 'Just parking');

      repo.sendGate!.complete();
      expect(await outcome, SendOutcome.sent);

      final sent = notifier.state.messages.single;
      expect(sent.seq, 1);
      expect(sent.clientMessageId, 'cid-1');
      expect(sent.sendState, ChatSendState.sent);
    });

    test('a failure marks it failed, and retry re-posts with the same clientMessageId', () async {
      final (:notifier, :repo) = _setUp();
      await notifier.load();
      repo.sendError = const NetworkException('offline');

      expect(await notifier.send('Running late'), SendOutcome.failed);
      expect(notifier.state.messages.single.sendState, ChatSendState.failed);

      repo.sendError = null;
      expect(await notifier.retry('cid-1'), SendOutcome.sent);

      expect(repo.sentClientIds, ['cid-1', 'cid-1']);
      expect(notifier.state.messages, hasLength(1));
      expect(notifier.state.messages.single.seq, 1);
      expect(repo.stored, hasLength(1));
    });

    test('a retry after a send the server stored but never answered stays one message', () async {
      final (:notifier, :repo) = _setUp();
      await notifier.load();
      repo.sendGate = Completer<void>();

      final first = notifier.send('On the corner');
      repo.sendGate!.completeError(const NetworkException('timed out'));
      expect(await first, SendOutcome.failed);

      repo.sendGate = null;
      expect(await notifier.retry('cid-1'), SendOutcome.sent);

      expect(repo.stored, hasLength(1));
      expect(_seqs(notifier), [1]);
    });

    test('a 422 removes the bubble and shows the rejected notice', () async {
      final (:notifier, :repo) = _setUp();
      await notifier.load();
      repo.sendResult = const MessageRejected();

      expect(await notifier.send('something rude'), SendOutcome.rejected);

      expect(notifier.state.messages, isEmpty);
      expect(notifier.state.notice, ChatNotice.rejected);
    });

    test('a 429 marks it failed and shows the rate limit notice', () async {
      final (:notifier, :repo) = _setUp();
      await notifier.load();
      repo.sendResult = const RateLimited(retryAfter: Duration(seconds: 20));

      expect(await notifier.send('one more'), SendOutcome.rateLimited);

      expect(notifier.state.messages.single.sendState, ChatSendState.failed);
      expect(notifier.state.notice, ChatNotice.rateLimited);
    });

    test('a 409 marks it failed, refetches the status and goes read-only', () async {
      final (:notifier, :repo) = _setUp();
      await notifier.load();
      repo.chat = chatState(ChatStatus.closed);

      expect(await notifier.send('Are you here?'), SendOutcome.notOpen);

      expect(notifier.state.status, ChatStatus.closed);
      expect(notifier.state.canSend, isFalse);
      expect(notifier.state.messages.single.sendState, ChatSendState.failed);
      expect(notifier.isPolling, isFalse);
      expect(await notifier.retry('cid-1'), SendOutcome.invalid);
    });

    test('sends nothing that is empty, too long, or while not open', () async {
      final (:notifier, :repo) = _setUp();
      await notifier.load();

      expect(await notifier.send('   \n '), SendOutcome.invalid);
      expect(await notifier.send('a' * 1001), SendOutcome.invalid);
      expect(repo.sentClientIds, isEmpty);
      expect(notifier.state.messages, isEmpty);
    });
  });

  group('merging by seq', () {
    test('re-reading the same messages never duplicates a bubble', () async {
      final (:notifier, :repo) = _setUp(seed: (repo) => repo.addPartnerMessage('Hi'));
      await notifier.load();

      await notifier.poll();
      await notifier.poll();

      expect(_seqs(notifier), [1]);
    });

    test('a poll that returns my message before its send answers leaves one bubble', () async {
      final (:notifier, :repo) = _setUp();
      await notifier.load();
      repo.sendGate = Completer<void>();

      final outcome = notifier.send('By the door');
      // The server has stored seq 1, and a partner message lands after it.
      repo.addPartnerMessage('Coming over');
      await notifier.poll();

      expect(_seqs(notifier), [1, 2]);
      expect(notifier.state.messages.first.clientMessageId, 'cid-1');
      expect(notifier.state.messages.first.sendState, ChatSendState.sent);

      repo.sendGate!.complete();
      expect(await outcome, SendOutcome.sent);
      expect(_seqs(notifier), [1, 2]);
    });

    test('two identical messages in flight both end up shown once each', () async {
      final (:notifier, :repo) = _setUp();
      await notifier.load();
      repo.sendGate = Completer<void>();

      final first = notifier.send('ok');
      final second = notifier.send('ok');
      await notifier.poll();
      repo.sendGate!.complete();
      await Future.wait([first, second]);

      expect(_seqs(notifier), [1, 2]);
      expect(notifier.state.messages.map((m) => m.clientMessageId).toSet(), {'cid-1', 'cid-2'});
    });

    test('unconfirmed messages stay after the server\'s, in the order written', () async {
      final (:notifier, :repo) = _setUp();
      await notifier.load();
      repo.sendError = const NetworkException('offline');
      await notifier.send('first');

      repo.addPartnerMessage('Hello?');
      await notifier.poll();

      expect(notifier.state.messages.map((m) => m.seq ?? m.clientMessageId), [1, 'cid-1']);
    });
  });

  group('polling', () {
    testWidgets('polls every 3 seconds by cursor, and stops when the chat closes', (tester) async {
      final (:notifier, :repo) = _setUp(seed: (repo) => repo.addPartnerMessage('Hi'));
      await notifier.load();
      repo.calls.clear();

      repo.addPartnerMessage('Nearly there');
      await tester.pump(_pollInterval);
      await tester.pump();

      expect(repo.calls, ['getMessages after:1', 'getChat']);
      expect(_seqs(notifier), [1, 2]);

      repo.chat = chatState(ChatStatus.closed);
      repo.calls.clear();
      await tester.pump(_pollInterval);
      await tester.pump();

      expect(notifier.state.status, ChatStatus.closed);
      expect(notifier.isPolling, isFalse);

      repo.calls.clear();
      await tester.pump(_pollInterval * 3);
      expect(repo.calls, isEmpty);
    });

    testWidgets('a 409 while polling refetches the status and stops', (tester) async {
      final (:notifier, :repo) = _setUp();
      await notifier.load();
      repo.chat = chatState(ChatStatus.archived);

      await tester.pump(_pollInterval);
      await tester.pump();

      expect(notifier.state.status, ChatStatus.archived);
      expect(notifier.isPolling, isFalse);
    });

    testWidgets('disposing stops polling', (tester) async {
      final repo = FakeChatRepository();
      final notifier = ChatNotifier(
        repo,
        '42',
        clock: ServerClock(),
        pollInterval: _pollInterval,
        logger: Logger(level: Level.off),
        autoLoad: false,
      );
      await notifier.load();
      notifier.dispose();
      repo.calls.clear();

      await tester.pump(_pollInterval * 2);
      expect(repo.calls, isEmpty);
    });
  });

  group('loadOlder', () {
    test('fetches beforeSeq the lowest held while hasMore', () async {
      final (:notifier, :repo) = _setUp(seed: (repo) {
        for (var i = 0; i < ChatRepository.pageSize + 5; i++) {
          repo.addPartnerMessage('message $i');
        }
      });
      await notifier.load();
      expect(notifier.state.hasMoreOlder, isTrue);
      expect(notifier.state.lowestSeq, 6);

      await notifier.loadOlder();

      expect(repo.calls.last, 'getMessages before:6');
      expect(notifier.state.messages, hasLength(ChatRepository.pageSize + 5));
      expect(_seqs(notifier).first, 1);
      expect(notifier.state.hasMoreOlder, isFalse);

      repo.calls.clear();
      await notifier.loadOlder();
      expect(repo.calls, isEmpty);
    });
  });
}
