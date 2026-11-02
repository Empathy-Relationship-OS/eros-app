import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eros_app/core/network/interceptors/logging_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

// CH-F5's check of primer rule 20 for report paths. CH-F2 has its own test for the same
// interceptor (logging_interceptor_test.dart); this one is separate so both can merge.

/// Answers every request with [body] and [statusCode].
class _FakeAdapter implements HttpClientAdapter {
  int statusCode = 200;
  Object body = const {'ok': true};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(jsonEncode(body), statusCode, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

class _Everything extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => true;
}

/// Keeps every printed line.
class _Capture extends LogOutput {
  final List<String> lines = [];

  @override
  void output(OutputEvent event) => lines.addAll(event.lines);
}

void main() {
  const description = 'They kept messaging after I asked them to stop';

  late _FakeAdapter adapter;
  late _Capture capture;
  late Dio dio;

  setUp(() {
    adapter = _FakeAdapter();
    capture = _Capture();
    dio = Dio(BaseOptions(baseUrl: 'https://api.test', validateStatus: (_) => true))
      ..httpClientAdapter = adapter
      ..interceptors.add(LoggingInterceptor(
        logger: Logger(filter: _Everything(), output: capture, printer: SimplePrinter()),
      ));
  });

  String printed() => capture.lines.join('\n');

  test('prints no report body, only the method, path and status', () async {
    adapter.body = {'reportId': 7, 'dateEnded': true, 'yourRefund': 'REFUNDED'};

    await dio.post('/dates/7/report', data: {
      'origin': 'REPORT',
      'reason': 'HARASSMENT',
      'description': description,
      'evidenceIds': <String>[],
    });

    expect(printed(), contains('/dates/7/report'));
    expect(printed(), contains('200'));
    expect(printed(), isNot(contains(description)));
    expect(printed(), isNot(contains('HARASSMENT')));
    expect(printed(), isNot(contains('REFUNDED')));
  });

  test('prints no body for an evidence upload request', () async {
    await dio.post('/dates/7/report/evidence-url', data: {'contentType': 'image/png'});

    expect(printed(), isNot(contains('image/png')));
  });

  test('prints no report body from an error response either', () async {
    adapter
      ..statusCode = 400
      ..body = {'error': 'VALIDATION', 'message': description};
    dio.options.validateStatus = (status) => status != null && status < 400;

    await expectLater(
      dio.post('/dates/7/report', data: {'description': description}),
      throwsA(isA<DioException>()),
    );

    expect(printed(), isNot(contains(description)));
  });

  test('prints no chat body', () async {
    await dio.post('/dates/7/chat/messages', data: {'text': 'See you at 8'});

    expect(printed(), isNot(contains('See you at 8')));
  });

  test('still prints other bodies', () async {
    await dio.post('/dates/7/cancel', data: {'reason': 'Work trip'});

    expect(printed(), contains('Work trip'));
  });
}
