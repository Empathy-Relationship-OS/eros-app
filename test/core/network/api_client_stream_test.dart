import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/network/sse_parser.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService implements AuthService {
  final List<bool> tokenRequests = [];

  @override
  Future<String> getIdToken({bool forceRefresh = false}) async {
    tokenRequests.add(forceRefresh);
    return 'token-1';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers every request with [status] and a body the test writes to [body] as it goes.
class _StreamingAdapter implements HttpClientAdapter {
  _StreamingAdapter({this.status = 200, this.contentType = 'text/event-stream'}) {
    body.onCancel = () => bodyCancelled = true;
  }

  final int status;
  final String contentType;
  final StreamController<Uint8List> body = StreamController<Uint8List>();
  final List<RequestOptions> requests = [];
  bool bodyCancelled = false;
  bool requestCancelled = false;

  /// When set, the answer waits for it, so a test can cancel while connecting.
  Completer<void>? gate;

  void write(String text) => body.add(Uint8List.fromList(utf8.encode(text)));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    cancelFuture?.then((_) => requestCancelled = true);
    await gate?.future;
    return ResponseBody(body.stream, status, headers: {
      Headers.contentTypeHeader: [contentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeAuthService auth;

  ApiClient clientFor(_StreamingAdapter adapter) {
    auth = _FakeAuthService();
    return ApiClient(auth, httpClientAdapter: adapter);
  }

  test('sends an event-stream GET with the token and no receive timeout', () async {
    final adapter = _StreamingAdapter();
    final sub = clientFor(adapter).stream('/dates/42/chat/stream').listen((_) {});
    await pumpEventQueue();

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/dates/42/chat/stream');
    expect(request.headers['Accept'], 'text/event-stream');
    expect(request.headers['Authorization'], 'Bearer token-1');
    expect(request.responseType, ResponseType.stream);
    expect(request.receiveTimeout, Duration.zero);
    await sub.cancel();
  });

  test('runs onOpen once accepted, then passes every event through the interceptors untouched', () async {
    final adapter = _StreamingAdapter();
    final log = <String>[];
    final done = Completer<void>();
    clientFor(adapter).stream('/dates/42/chat/stream', onOpen: () => log.add('open')).listen(
          (event) => log.add('${event.event} ${event.data}'),
          onDone: done.complete,
        );
    await pumpEventQueue();
    expect(log, ['open']);

    // LoggingInterceptor runs on this response with detailed logging on (ENV=local). Had it
    // read the body, these events would never arrive.
    adapter.write('event: messages\ndata: {"lastSeq":3}\n\n');
    adapter.write('event: heartbeat\n\n');
    await adapter.body.close();
    await done.future;

    expect(log, ['open', 'messages {"lastSeq":3}', 'heartbeat null']);
  });

  test('a 409 is a ConflictException, then the stream closes without opening', () async {
    final adapter = _StreamingAdapter(status: 409, contentType: 'application/json');
    var opened = false;
    final result = clientFor(adapter).stream('/dates/42/chat/stream', onOpen: () => opened = true).toList();
    adapter.write('{"error":"conflict","message":"Chat is not open"}');
    await adapter.body.close();

    await expectLater(
      result,
      throwsA(isA<ConflictException>().having((e) => e.message, 'message', 'Chat is not open')),
    );
    expect(opened, isFalse);
  });

  test('a 403 is a ForbiddenException, sent once and never retried', () async {
    final adapter = _StreamingAdapter(status: 403, contentType: 'application/json');
    final result = clientFor(adapter).stream('/dates/42/chat/stream').toList();
    adapter.write('{"error":"forbidden","message":"Not a participant"}');
    await adapter.body.close();

    await expectLater(result, throwsA(isA<ForbiddenException>()));
    expect(adapter.requests, hasLength(1));
    expect(auth.tokenRequests, [false], reason: 'no forced token refresh');
  });

  test('a dropped connection is a NetworkException', () async {
    final adapter = _StreamingAdapter();
    final result = clientFor(adapter).stream('/dates/42/chat/stream').toList();
    await pumpEventQueue();
    adapter.body.addError(const SocketException('Connection reset by peer'));

    await expectLater(result, throwsA(isA<NetworkException>()));
  });

  test('cancelling closes the connection', () async {
    final adapter = _StreamingAdapter();
    final events = <SseEvent>[];
    final sub = clientFor(adapter).stream('/dates/42/chat/stream').listen(events.add);
    await pumpEventQueue();

    await sub.cancel();
    await pumpEventQueue();

    expect(adapter.bodyCancelled, isTrue);
  });

  test('cancelling while connecting cancels the request and never opens', () async {
    final adapter = _StreamingAdapter()..gate = Completer<void>();
    var opened = false;
    final sub = clientFor(adapter).stream('/dates/42/chat/stream', onOpen: () => opened = true).listen((_) {});
    await pumpEventQueue();

    await sub.cancel();
    adapter.gate!.complete();
    await pumpEventQueue();

    expect(adapter.requestCancelled, isTrue);
    expect(opened, isFalse);
  });
}
