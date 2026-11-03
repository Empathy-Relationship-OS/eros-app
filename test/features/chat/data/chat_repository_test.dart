import 'package:dio/dio.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/chat/data/models/chat_models.dart';
import 'package:eros_app/features/chat/data/repositories/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../fake_chat_repository.dart';

/// Answers with [response], or throws [error] the way [ApiClient] maps a status.
class _FakeApi implements ApiClient {
  _FakeApi({this.response, this.error});

  final Object? response;
  final ApiException? error;
  final List<({String method, String path, dynamic data})> requests = [];

  T _answer<T>(String method, String path, dynamic data) {
    requests.add((method: method, path: path, data: data));
    if (error != null) throw error!;
    return response as T;
  }

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options}) async =>
      _answer<T>('GET', path, null);

  @override
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      _answer<T>('POST', path, data);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChatRepository _repository(_FakeApi api) => ChatRepository(api, logger: Logger(level: Level.off));

void main() {
  group('getChat', () {
    test('reads the RFC §5 response', () async {
      final api = _FakeApi(response: chatFixture('get_chat_open'));

      final chat = await _repository(api).getChat('42');

      expect(api.requests.single.path, '/dates/42/chat');
      expect(chat.status, ChatStatus.open);
      expect(chat.closesAt, DateTime.utc(2026, 11, 7, 21));
      expect(chat.unreadCount, 2);
      expect(chat.partnerName, 'Alex');
      expect(chat.quickReplies.single.key, 'ON_MY_WAY');
    });

    test('lets a 403 through', () async {
      final api = _FakeApi(error: const ForbiddenException('forbidden'));

      await expectLater(_repository(api).getChat('42'), throwsA(isA<ForbiddenException>()));
    });
  });

  group('getMessages', () {
    test('asks for the latest page with no cursor', () async {
      final api = _FakeApi(response: chatFixture('get_messages'));

      final result = await _repository(api).getMessages('42');

      expect(api.requests.single.path, '/dates/42/chat/messages?limit=50');
      final page = (result as MessagesLoaded).page;
      expect(page.messages.map((m) => m.seq), [17, 18]);
      expect(page.messages.last.kind, ChatMessageKind.quickReply);
      expect(page.hasMore, isTrue);
    });

    test('passes afterSeq or beforeSeq', () async {
      final api = _FakeApi(response: chatFixture('get_messages'));
      final repository = _repository(api);

      await repository.getMessages('42', afterSeq: 18);
      await repository.getMessages('42', beforeSeq: 17, limit: 20);

      expect(api.requests.map((r) => r.path), [
        '/dates/42/chat/messages?afterSeq=18&limit=50',
        '/dates/42/chat/messages?beforeSeq=17&limit=20',
      ]);
    });

    test('maps a 409 to ChatNotOpen', () async {
      final api = _FakeApi(error: const ConflictException('conflict'));

      expect(await _repository(api).getMessages('42'), isA<ChatNotOpen>());
    });
  });

  group('sendMessage', () {
    test('posts the client id and text, and returns the stored message', () async {
      final api = _FakeApi(response: chatFixture('post_message'));

      final result = await _repository(api).sendMessage('42', clientMessageId: 'c-1', text: 'Just parking');

      expect(api.requests.single.path, '/dates/42/chat/messages');
      expect(api.requests.single.data, {'clientMessageId': 'c-1', 'text': 'Just parking'});
      expect((result as MessageSent).message.seq, 19);
    });

    test('posts a quick reply key without text', () async {
      final api = _FakeApi(response: chatFixture('post_message'));

      await _repository(api).sendMessage('42', clientMessageId: 'c-2', quickReplyKey: 'ON_MY_WAY');

      expect(api.requests.single.data, {'clientMessageId': 'c-2', 'quickReplyKey': 'ON_MY_WAY'});
    });

    test('maps a 409 to ChatNotOpen', () async {
      final api = _FakeApi(error: const ConflictException('conflict'));

      expect(
        await _repository(api).sendMessage('42', clientMessageId: 'c', text: 'hi'),
        isA<ChatNotOpen>(),
      );
    });

    test('maps a 422 to MessageRejected', () async {
      // ApiClient has no 422 class, so it arrives as UnknownApiException with the status.
      final api = _FakeApi(error: const UnknownApiException('message_rejected', statusCode: 422));

      expect(
        await _repository(api).sendMessage('42', clientMessageId: 'c', text: 'hi'),
        isA<MessageRejected>(),
      );
    });

    test('maps a 429 to RateLimited, with Retry-After', () async {
      final api = _FakeApi(
        error: const RateLimitException('rate_limited', retryAfter: Duration(seconds: 12)),
      );

      final result = await _repository(api).sendMessage('42', clientMessageId: 'c', text: 'hi');

      expect((result as RateLimited).retryAfter, const Duration(seconds: 12));
    });

    test('lets a network error through, for the notifier to mark failed', () async {
      final api = _FakeApi(error: const NetworkException('offline'));

      await expectLater(
        _repository(api).sendMessage('42', clientMessageId: 'c', text: 'hi'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('markRead', () {
    test('posts the seq to /chat/read, and reads a 204', () async {
      final api = _FakeApi();

      await _repository(api).markRead('42', 18);

      expect(api.requests.single.method, 'POST');
      expect(api.requests.single.path, '/dates/42/chat/read');
      expect(api.requests.single.data, {'seq': 18});
    });

    test('lets a failure through, for the notifier to ignore', () async {
      final api = _FakeApi(error: const ValidationException('seq above lastSeq'));

      expect(() => _repository(api).markRead('42', 99), throwsA(isA<ValidationException>()));
    });
  });
}
