import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eros_app/core/network/interceptors/logging_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

const _secret = 'meet me by the fountain';

/// Echoes the request body back, so a logged response would show it too.
class _EchoAdapter implements HttpClientAdapter {
  _EchoAdapter({this.status = 200});

  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final sent = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        sent.addAll(chunk);
      }
    }
    return ResponseBody.fromString(utf8.decode(sent), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

class _AlwaysLog extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => true;
}

class _Capture extends LogOutput {
  final List<String> lines = [];

  @override
  void output(OutputEvent event) => lines.addAll(event.lines);
}

({Dio dio, _Capture output}) _dio({int status = 200}) {
  final output = _Capture();
  final logger = Logger(filter: _AlwaysLog(), printer: SimplePrinter(colors: false), output: output);
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8940'))
    ..httpClientAdapter = _EchoAdapter(status: status)
    ..interceptors.add(LoggingInterceptor(logger: logger));
  return (dio: dio, output: output);
}

void main() {
  // The default ENV in tests is local, which logs in detail.

  test('prints no chat message body, only the method, path and status', () async {
    final (:dio, :output) = _dio();

    await dio.post('/dates/42/chat/messages', data: {'clientMessageId': 'c-1', 'text': _secret});

    final log = output.lines.join('\n');
    expect(log, isNot(contains(_secret)));
    expect(log, isNot(contains('c-1')));
    expect(log, contains('POST /dates/42/chat/messages'));
    expect(log, contains('200'));
  });

  test('prints no chat body or query on an error response', () async {
    final (:dio, :output) = _dio(status: 422);

    await expectLater(
      dio.post('/dates/42/chat/messages', data: {'text': _secret}),
      throwsA(isA<DioException>()),
    );

    final log = output.lines.join('\n');
    expect(log, isNot(contains(_secret)));
    expect(log, contains('422'));
  });

  test('prints no report description', () async {
    final (:dio, :output) = _dio();

    await dio.post('/dates/42/report', data: {'description': _secret});

    expect(output.lines.join('\n'), isNot(contains(_secret)));
  });

  test('still prints bodies for other paths', () async {
    final (:dio, :output) = _dio();

    await dio.post('/dates/42/cancel', data: {'reason': 'Something came up'});

    expect(output.lines.join('\n'), contains('Something came up'));
  });

  test('treats only /chat and /report paths as private', () {
    expect(LoggingInterceptor.isPrivatePath('/dates/42/chat'), isTrue);
    expect(LoggingInterceptor.isPrivatePath('/dates/42/chat/messages'), isTrue);
    expect(LoggingInterceptor.isPrivatePath('/dates/42/report/evidence-url'), isTrue);
    expect(LoggingInterceptor.isPrivatePath('/dates/42'), isFalse);
  });
}
