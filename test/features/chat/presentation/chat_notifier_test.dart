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

  group('quick replies', () {
    test('sends the key with a new clientMessageId, and shows its text at once', () async {
      final (:notifier, :repo) = _setUp();
      await notifier.load();
      repo.sendGate = Completer<void>();
      const reply = QuickReply(key: 'RUNNING_LATE', text: 'Running 5 minutes late');

      final outcome = notifier.sendQuickReply(reply);

      final pending = notifier.state.messages.single;
      expect(pending.clientMessageId, 'cid-1');
      expect(pending.kind, ChatMessageKind.quickReply);
      expect(pending.quickReplyKey, 'RUNNING_LATE');
      expect(pending.text, 'Running 5 minutes late');
      expect(pending.sendState, ChatSendState.sending);

      repo.sendGate!.complete();
      expect(await outcome, SendOutcome.sent);
      expect(repo.stored.single.quickReplyKey, 'RUNNING_LATE');

      repo.sendGate = null;
      await notifier.sendQuickReply(reply);
      expect(repo.sentClientIds, ['cid-1', 'cid-2']);
      expect(_seqs(notifier), [1, 2]);
    });

    test('a failed quick reply retries with the same clientMessageId and key', () async {
      final (:notifier, :repo) = _setUp();
      await notifier.load();
      repo.sendError = const NetworkException('offline');

      await notifier.sendQuickReply(const QuickReply(key: 'HERE', text: 'I\'m here'));
      repo.sendError = null;
      expect(await notifier.retry('cid-1'), SendOutcome.sent);

      expect(repo.sentClientIds, ['cid-1', 'cid-1']);
      expect(repo.stored.single.quickReplyKey, 'HERE');
      expect(notifier.state.messages, hasLength(1));
    });

    test('sends nothing unless OPEN', () async {
      final (:notifier, :repo) = _setUp(status: ChatStatus.closed);
      await notifier.load();

      expect(
        await notifier.sendQuickReply(const QuickReply(key: 'HERE', text: 'I\'m here')),
        SendOutcome.invalid,
      );
      expect(repo.sentClientIds, isEmpty);
    });
  });

  group('mark as read', () {
    const debounce = ChatNotifier.defaultReadDebounce;

    testWidgets('posts the highest seq held a second after it changes', (tester) async {
      final (:notifier, :repo) = _readSetUp(seed: (repo) {
        repo.addPartnerMessage('Hi');
        repo.addPartnerMessage('See you at 7');
      });
      await notifier.load();

      await tester.pump(debounce - const Duration(milliseconds: 1));
      expect(repo.readSeqs, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(repo.readSeqs, [2]);

      // Nothing new, nothing posted.
      await tester.pump(_pollInterval * 2);
      expect(repo.readSeqs, [2]);

      repo.addPartnerMessage('Nearly there');
      await tester.pump(_pollInterval);
      await tester.pump(debounce);
      expect(repo.readSeqs, [2, 3]);

      notifier.dispose();
    });

    testWidgets('rapid updates post at most once a second, and never backwards', (tester) async {
      final (:notifier, :repo) = _readSetUp(
        pollInterval: const Duration(milliseconds: 200),
        seed: (repo) => repo.addPartnerMessage('message 0'),
      );
      await notifier.load();

      const step = Duration(milliseconds: 100);
      final postedAt = <Duration>[];
      var elapsed = Duration.zero;
      for (var i = 1; elapsed < const Duration(seconds: 5); i++) {
        if (i.isEven) repo.addPartnerMessage('message $i');
        final before = repo.readSeqs.length;
        await tester.pump(step);
        elapsed += step;
        if (repo.readSeqs.length > before) postedAt.add(elapsed);
      }

      expect(postedAt.length, greaterThanOrEqualTo(3));
      for (var i = 1; i < postedAt.length; i++) {
        expect(postedAt[i] - postedAt[i - 1], greaterThanOrEqualTo(debounce));
      }
      for (var i = 1; i < repo.readSeqs.length; i++) {
        expect(repo.readSeqs[i], greaterThan(repo.readSeqs[i - 1]));
      }

      repo.chat = chatState(ChatStatus.closed);
      await tester.pump(const Duration(seconds: 2));
      notifier.dispose();
    });

    testWidgets('posts nothing the server already holds', (tester) async {
      final (:notifier, :repo) = _readSetUp(
        chat: chatState(ChatStatus.open, yourLastReadSeq: 2),
        seed: (repo) {
          repo.addPartnerMessage('Hi');
          repo.addPartnerMessage('See you at 7');
        },
      );
      await notifier.load();

      await tester.pump(debounce * 2);
      expect(repo.readSeqs, isEmpty);

      repo.addPartnerMessage('Nearly there');
      await tester.pump(_pollInterval);
      await tester.pump(debounce);
      expect(repo.readSeqs, [3]);

      notifier.dispose();
    });

    testWidgets('a failure is ignored, and the next update catches up', (tester) async {
      final (:notifier, :repo) = _readSetUp(seed: (repo) => repo.addPartnerMessage('Hi'));
      repo.readError = const NetworkException('offline');
      await notifier.load();

      await tester.pump(debounce);
      expect(repo.readSeqs, [1]);
      expect(notifier.state.hasError, isFalse);

      repo.readError = null;
      repo.addPartnerMessage('Hello?');
      await tester.pump(_pollInterval);
      await tester.pump(debounce);
      expect(repo.readSeqs, [1, 2]);

      notifier.dispose();
    });

    testWidgets('marks a CLOSED chat read too, so the unread dot clears', (tester) async {
      final (:notifier, :repo) = _readSetUp(
        chat: chatState(ChatStatus.closed),
        seed: (repo) => repo.addPartnerMessage('Thanks for tonight'),
      );
      await notifier.load();

      await tester.pump(debounce);
      expect(repo.readSeqs, [1]);

      notifier.dispose();
    });

    testWidgets('posts nothing while in the background, and catches up on return', (tester) async {
      final (:notifier, :repo) = _readSetUp(seed: (repo) => repo.addPartnerMessage('Hi'));
      notifier.setForeground(false);
      await notifier.load();

      await tester.pump(_pollInterval * 2);
      expect(repo.readSeqs, isEmpty);

      notifier.setForeground(true);
      await tester.pump(debounce);
      expect(repo.readSeqs, [1]);

      notifier.dispose();
    });

    testWidgets('leaving the screen posts a read still waiting', (tester) async {
      final (:notifier, :repo) = _readSetUp(seed: (repo) => repo.addPartnerMessage('Hi'));
      await notifier.load();

      notifier.dispose();
      await tester.pump();

      expect(repo.readSeqs, [1]);
    });
  });

  group('seenSeq', () {
    test('is my newest message the partner has read', () async {
      final (:notifier, :repo) = _setUp(seed: (repo) {
        repo.addMyMessage('On my way'); // 1
        repo.addPartnerMessage('Great'); // 2
        repo.addMyMessage('At the door'); // 3
        repo.addMyMessage('Inside now'); // 4
      });

      repo.chat = chatState(ChatStatus.open, partnerLastReadSeq: 0);
      await notifier.load();
      expect(notifier.state.seenSeq, isNull);

      repo.chat = chatState(ChatStatus.open, partnerLastReadSeq: 2);
      await notifier.poll();
      expect(notifier.state.seenSeq, 1);

      repo.chat = chatState(ChatStatus.open, partnerLastReadSeq: 3);
      await notifier.poll();
      expect(notifier.state.seenSeq, 3);
    });
  });
}

/// Like [_setUp], for tests that dispose the notifier themselves, so its timers can't
/// outlive a widget test.
({ChatNotifier notifier, FakeChatRepository repo}) _readSetUp({
  ChatState? chat,
  Duration pollInterval = _pollInterval,
  void Function(FakeChatRepository repo)? seed,
}) {
  final repo = FakeChatRepository();
  if (chat != null) repo.chat = chat;
  seed?.call(repo);
  final notifier = ChatNotifier(
    repo,
    '42',
    clock: ServerClock(deviceNow: () => DateTime.utc(2026, 11, 7, 19)),
    pollInterval: pollInterval,
    logger: Logger(level: Level.off),
    autoLoad: false,
  );
  return (notifier: notifier, repo: repo);
}
