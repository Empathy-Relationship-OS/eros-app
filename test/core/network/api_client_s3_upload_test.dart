import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the request it receives and answers 200.
class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    await requestStream?.drain<void>();
    return ResponseBody.fromString('', 200);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _RecordingAdapter adapter;
  late ApiClient client;

  setUp(() {
    adapter = _RecordingAdapter();
    client = ApiClient(
      AuthService(auth: _FakeFirebaseAuth()),
      s3DioFactory: () => Dio()..httpClientAdapter = adapter,
    );
  });

  test('sends the required headers from the presign response', () async {
    await client.uploadToS3(
      presignedUrl: 'https://bucket.s3.amazonaws.com/photos/u/1.jpg?X-Amz-Signature=abc',
      fileBytes: List.filled(10, 1),
      contentType: 'image/jpeg',
      extraHeaders: {'x-amz-tagging': 'upload_confirmed=false'},
    );

    final headers = adapter.lastRequest!.headers;
    expect(headers['x-amz-tagging'], 'upload_confirmed=false');
    expect(headers['content-type'] ?? headers['Content-Type'], 'image/jpeg');
  });

  test('sends no extra headers when none are required', () async {
    await client.uploadToS3(
      presignedUrl: 'https://bucket.s3.amazonaws.com/photos/u/1.jpg?X-Amz-Signature=abc',
      fileBytes: List.filled(10, 1),
      contentType: 'image/png',
    );

    final names = adapter.lastRequest!.headers.keys.map((k) => k.toLowerCase());
    expect(names, isNot(contains('x-amz-tagging')));
  });
}
