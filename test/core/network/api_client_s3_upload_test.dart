import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the request it receives, including the bytes sent, and answers 200.
class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;
  List<int> sentBytes = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    sentBytes = [];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        sentBytes.addAll(chunk);
      }
    }
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

  test('sends a plain List<int> as the original binary bytes', () async {
    // A JPEG header followed by bytes that are not valid UTF-8 on their own.
    final bytes = <int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x80, 0xFE, 0x01];

    await client.uploadToS3(
      presignedUrl: 'https://bucket.s3.amazonaws.com/photos/u/1.jpg?X-Amz-Signature=abc',
      fileBytes: bytes,
      contentType: 'image/jpeg',
    );

    expect(adapter.sentBytes, bytes);
    final headers = adapter.lastRequest!.headers;
    expect(headers['content-length'] ?? headers['Content-Length'], '${bytes.length}');
  });

  test('reports upload progress up to 1', () async {
    final progress = <double>[];

    await client.uploadToS3(
      presignedUrl: 'https://bucket.s3.amazonaws.com/photos/u/1.jpg?X-Amz-Signature=abc',
      fileBytes: List.filled(200000, 1),
      contentType: 'image/jpeg',
      onProgress: progress.add,
    );

    expect(progress, isNotEmpty);
    expect(progress.last, 1.0);
  });
}
