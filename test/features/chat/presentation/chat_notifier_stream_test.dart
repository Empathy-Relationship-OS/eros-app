import 'dart:async';

import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/time/server_clock.dart';
import 'package:eros_app/features/chat/data/models/chat_models.dart';
import 'package:eros_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../fake_chat_repository.dart';

const _fastPoll = Duration(seconds: 3);
const _slowPoll = Duration(seconds: 30);

ChatNotifier _notifier(FakeChatRepository repo) {
  var ids = 0;
  final notifier = ChatNotifier(
    repo,
    '42',
    clock: ServerClock(deviceNow: () => DateTime.utc(2026, 11, 7, 19)),
    newClientMessageId: () => 'cid-${++ids}',
    pollInterval: _fastPoll,
    connectedPollInterval: _slowPoll,
    logger: Logger(level: Level.off),
    autoLoad: false,
  );
  _live.add(notifier);
  return notifier;
}

/// Notifiers made by the running test.
final List<ChatNotifier> _live = [];

/// A fake-time test that disposes its notifiers before the end, so no timer is left pending.
void _test(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      for (final notifier in _live) {
        if (notifier.mounted) notifier.dispose();
      }
      _live.clear();
    }
  });
}

/// A loaded OPEN chat. [connected] opens its stream too.
Future<({ChatNotifier notifier, FakeChatRepository repo})> _loaded({
  ChatStatus status = ChatStatus.open,
  bool connected = true,
  void Function(FakeChatRepository repo)? seed,
}) async {
  final repo = FakeChatRepository(status: status);
  seed?.call(repo);
  final notifier = _notifier(repo);
  await notifier.load();
  if (connected) repo.stream.open();
  repo.calls.clear();
  return (notifier: notifier, repo: repo);
}

List<int?> _seqs(ChatNotifier notifier) => notifier.state.messages.map((m) => m.seq).toList();

int _fetches(FakeChatRepository repo) => repo.calls.where((c) => c.startsWith('getMessages')).length;

/// Lets fake-async microtasks (the fake repository's answers) run.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(Duration.zero);
  }
}

void main() {
  group('connecting', () {
    _test('connects once loaded OPEN, and polls slower once connected', (tester) async {
      final (:notifier, :repo) = await _loaded(connected: false);

      expect(repo.streams, hasLength(1));
      expect(notifier.isStreamConnected, isFalse);
      expect(notifier.activePollInterval, _fastPoll);

      repo.stream.open();

      expect(notifier.isStreamConnected, isTrue);
      expect(notifier.activePollInterval, _slowPoll);
    });

    _test('never connects unless OPEN', (tester) async {
      for (final status in [ChatStatus.notOpen, ChatStatus.closed, ChatStatus.archived]) {
        final (notifier: _, :repo) = await _loaded(status: status, connected: false);
        expect(repo.streams, isEmpty, reason: '$status');
      }
    });
  });

  group('signals', () {
    _test('a burst of 10 messages signals causes one or two fetches', (tester) async {
      final (:notifier, :repo) = await _loaded();

      for (var i = 1; i <= 10; i++) {
        repo.addPartnerMessage('Message $i');
        repo.stream.send(MessagesSignal(i));
      }
      await _settle(tester);

      expect(_fetches(repo), inInclusiveRange(1, 2));
      expect(repo.calls.first, 'getMessages after:0');
      expect(_seqs(notifier), [for (var i = 1; i <= 10; i++) i]);
    });

    _test('signals arriving during a fetch cause one more fetch, not one each', (tester) async {
      final (:notifier, :repo) = await _loaded();

      repo.addPartnerMessage('First');
      repo.stream.send(const MessagesSignal(1));
      await tester.pump(); // The first fetch is under way.
      for (var i = 2; i <= 10; i++) {
        repo.addPartnerMessage('Message $i');
        repo.stream.send(MessagesSignal(i));
      }
      await _settle(tester);

      expect(_fetches(repo), lessThanOrEqualTo(2));
      expect(_seqs(notifier), [for (var i = 1; i <= 10; i++) i]);
    });

    _test('the signal for my own confirmed message fetches nothing', (tester) async {
      final (:notifier, :repo) = await _loaded();
      await notifier.send('On my way');
      repo.calls.clear();

      repo.stream.send(const MessagesSignal(1));
      await _settle(tester);

      expect(repo.calls, isEmpty);
      expect(_seqs(notifier), [1]);
    });

    _test('my message fetched by a signal before its send answers stays one bubble', (tester) async {
      final (:notifier, :repo) = await _loaded();
      repo.sendGate = Completer<void>();

      final sending = notifier.send('Just parking');
      await tester.pump(); // Stored on the server, answer held back.
      repo.stream.send(const MessagesSignal(1));
      await _settle(tester);
      repo.sendGate!.complete();
      await sending;

      expect(_seqs(notifier), [1]);
      expect(notifier.state.messages.single.clientMessageId, 'cid-1');
    });

    _test('read moves "Seen" forward, never back', (tester) async {
      final (:notifier, :repo) = await _loaded();
      await notifier.send('See you at 7');
      await notifier.send('Table by the window');

      repo.stream.send(const ReadSignal(2));
      await _settle(tester);
      expect(notifier.state.chat!.partnerLastReadSeq, 2);
      expect(notifier.state.seenSeq, 2);

      repo.stream.send(const ReadSignal(1));
      await _settle(tester);
      expect(notifier.state.chat!.partnerLastReadSeq, 2);
    });

    _test('heartbeat does nothing', (tester) async {
      final (:notifier, :repo) = await _loaded();

      repo.stream.send(const HeartbeatSignal());
      await _settle(tester);

      expect(repo.calls, isEmpty);
      expect(notifier.isStreamConnected, isTrue);
    });

    _test('closed refetches the status, goes read-only and never reconnects', (tester) async {
      final (:notifier, :repo) = await _loaded(seed: (repo) => repo.addPartnerMessage('Hi'));
      repo.addPartnerMessage('Sent just before it closed');
      repo.chat = chatState(ChatStatus.closed);

      repo.stream.send(const ClosedSignal());
      await _settle(tester);

      expect(repo.calls, contains('getChat'));
      expect(notifier.state.status, ChatStatus.closed);
      expect(notifier.state.canSend, isFalse);
      expect(_seqs(notifier), [1, 2]);
      expect(repo.stream.cancelled, isTrue);
      expect(notifier.isPolling, isFalse);

      repo.calls.clear();
      await tester.pump(const Duration(minutes: 2));
      expect(repo.streams, hasLength(1));
      expect(repo.calls, isEmpty);
    });
  });

  group('polling', () {
    _test('every 30 seconds while connected, every 3 while not', (tester) async {
      final (:notifier, :repo) = await _loaded();

      await tester.pump(_slowPoll - const Duration(seconds: 1));
      expect(repo.calls, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
      expect(repo.calls, ['getMessages after:0', 'getChat']);

      // The stream drops: polls speed up.
      repo.stream.fail(const NetworkException('Stream connection lost'));
      await _settle(tester);
      expect(notifier.isStreamConnected, isFalse);
      expect(notifier.activePollInterval, _fastPoll);

      // It comes back: polls slow down again.
      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
      expect(repo.streams, hasLength(2));
      repo.stream.open();
      expect(notifier.activePollInterval, _slowPoll);

      repo.calls.clear();
      await tester.pump(_slowPoll - const Duration(seconds: 1));
      expect(repo.calls, isEmpty);
    });
  });

  group('reconnecting', () {
    /// Fails the newest stream, then checks no new one comes before [delay] and one does at it.
    Future<void> failAndExpectReconnectAfter(WidgetTester tester, FakeChatRepository repo, Duration delay) async {
      final before = repo.streams.length;
      repo.stream.fail(const NetworkException('Connection error'));
      await _settle(tester);
      await tester.pump(delay - const Duration(milliseconds: 1));
      await _settle(tester);
      expect(repo.streams, hasLength(before), reason: 'not before $delay');
      await tester.pump(const Duration(milliseconds: 1));
      await _settle(tester);
      expect(repo.streams, hasLength(before + 1), reason: 'at $delay');
    }

    _test('backs off 1, 2, 4, 8, then 30 seconds', (tester) async {
      final (notifier: _, :repo) = await _loaded(connected: false);

      for (final seconds in [1, 2, 4, 8, 30, 30]) {
        await failAndExpectReconnectAfter(tester, repo, Duration(seconds: seconds));
      }
    });

    _test('the backoff resets once a connection delivers a signal', (tester) async {
      final (notifier: _, :repo) = await _loaded(connected: false);
      for (final seconds in [1, 2, 4]) {
        await failAndExpectReconnectAfter(tester, repo, Duration(seconds: seconds));
      }

      repo.stream.open();
      repo.stream.send(const HeartbeatSignal());
      await _settle(tester);

      await failAndExpectReconnectAfter(tester, repo, const Duration(seconds: 1));
    });

    _test('a clean end of a working stream (the 50 minute limit) reconnects at once, cursor first',
        (tester) async {
      final (:notifier, :repo) = await _loaded(seed: (repo) => repo.addPartnerMessage('Hi'));
      repo.stream.send(const HeartbeatSignal());
      await _settle(tester);
      repo.addPartnerMessage('Sent while reconnecting');
      repo.calls.clear();

      repo.stream.end();
      await _settle(tester);

      expect(repo.calls, ['getMessages after:1', 'getChat']);
      expect(repo.streams, hasLength(2));
      expect(_seqs(notifier), [1, 2]);
    });

    _test('a clean end before any signal backs off', (tester) async {
      final (notifier: _, :repo) = await _loaded();

      repo.stream.end();
      await _settle(tester);
      expect(repo.streams, hasLength(1));

      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
      expect(repo.streams, hasLength(2));
    });

    _test('a 409 refetches the status and stops', (tester) async {
      final (:notifier, :repo) = await _loaded(connected: false);
      repo.chat = chatState(ChatStatus.closed);

      repo.stream.fail(const ConflictException('Chat is not open', statusCode: 409));
      await _settle(tester);

      expect(repo.calls, contains('getChat'));
      expect(notifier.state.status, ChatStatus.closed);
      await tester.pump(const Duration(minutes: 2));
      expect(repo.streams, hasLength(1));
    });

    _test('a 403 never reconnects, and the 3 second poll carries on', (tester) async {
      final (:notifier, :repo) = await _loaded(connected: false);

      repo.stream.fail(const ForbiddenException('Access denied', statusCode: 403));
      await _settle(tester);
      await tester.pump(const Duration(minutes: 2));
      await _settle(tester);

      expect(repo.streams, hasLength(1));
      expect(notifier.activePollInterval, _fastPoll);
      expect(_fetches(repo), greaterThanOrEqualTo(30));
    });
  });

  group('lifecycle', () {
    _test('pause closes the stream and stops polling', (tester) async {
      final (:notifier, :repo) = await _loaded();

      notifier.pause();
      await _settle(tester);

      expect(repo.stream.cancelled, isTrue);
      expect(notifier.isPolling, isFalse);
      expect(notifier.isStreamConnected, isFalse);
      await tester.pump(const Duration(minutes: 2));
      expect(repo.calls, isEmpty);
      expect(repo.streams, hasLength(1));
    });

    _test('pause cancels a reconnect that is waiting', (tester) async {
      final (:notifier, :repo) = await _loaded();
      repo.stream.fail(const NetworkException('Connection error'));
      await _settle(tester);

      notifier.pause();
      await tester.pump(const Duration(minutes: 2));

      expect(repo.streams, hasLength(1));
    });

    _test('resume fetches by cursor, then reconnects', (tester) async {
      final (:notifier, :repo) = await _loaded(seed: (repo) => repo.addPartnerMessage('Hi'));
      notifier.pause();
      repo.addPartnerMessage('Sent while you were away');

      final resuming = notifier.resume();
      expect(repo.streams, hasLength(1), reason: 'not before the fetch');
      await resuming;

      expect(repo.calls, ['getMessages after:1', 'getChat']);
      expect(_seqs(notifier), [1, 2]);
      expect(repo.streams, hasLength(2));
      expect(notifier.activePollInterval, _fastPoll);
    });

    _test('resume tries again after a 403', (tester) async {
      final (:notifier, :repo) = await _loaded(connected: false);
      repo.stream.fail(const ForbiddenException('Access denied', statusCode: 403));
      await _settle(tester);

      notifier.pause();
      await notifier.resume();

      expect(repo.streams, hasLength(2));
    });

    _test('disposing closes the stream, and nothing runs after', (tester) async {
      final (:notifier, :repo) = await _loaded();
      final stream = repo.stream;

      notifier.dispose();
      await _settle(tester);

      expect(stream.cancelled, isTrue);
      await tester.pump(const Duration(minutes: 2));
      expect(repo.calls, isEmpty);
      expect(repo.streams, hasLength(1));
    });

    _test('disposing cancels a reconnect that is waiting', (tester) async {
      final (:notifier, :repo) = await _loaded();
      repo.stream.fail(const NetworkException('Connection error'));
      await _settle(tester);

      notifier.dispose();
      await tester.pump(const Duration(minutes: 2));

      expect(repo.calls, isEmpty);
      expect(repo.streams, hasLength(1));
    });
  });
}
