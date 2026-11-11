import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/network/api_client.dart';

dynamic verificationFixture(String name) =>
    jsonDecode(File('test/fixtures/verification/$name.json').readAsStringSync());

const String statusPath = '/users/me/verification';
const String attemptsPath = '/users/me/verification/attempts';
const String attemptId = '3f2504e0-4f89-11d3-9a0c-0305e82c3301';
const String submitPath = '/users/me/verification/attempts/$attemptId/submit';

/// `GET /users/me/verification` in [state].
Map<String, dynamic> statusJson(
  String state, {
  String? reason,
  int attemptsLeftToday = 3,
  bool canStart = true,
}) =>
    {
      'state': state,
      'reason': ?reason,
      'attemptsLeftToday': attemptsLeftToday,
      'canStart': canStart,
      'consentVersion': '1',
    };

/// The backend's `ApiError`.
Map<String, dynamic> apiError(String code, [String message = 'Refused']) =>
    {'error': code, 'message': message};

typedef StubResponse = ({int status, Object? body, Map<String, String> headers});

StubResponse reply(int status, Object? body, {Map<String, String> headers = const {}}) =>
    (status: status, body: body, headers: headers);

/// The network under a real [ApiClient]: answers by `'METHOD path'` from [responses] and
/// records every request, so the tests cover the client's own error mapping too.
class StubHttp implements HttpClientAdapter {
  final Map<String, StubResponse> responses = {};
  final List<RequestOptions> requests = [];
  final List<List<int>> sentBodies = [];

  /// The requests sent with [method] to [path].
  List<RequestOptions> sent(String method, String path) =>
      [for (final r in requests) if (r.method == method && r.uri.path == path) r];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    sentBodies.add(bytes);

    final stub = responses['${options.method} ${options.uri.path}'];
    if (stub == null) throw StateError('No stub for ${options.method} ${options.uri.path}');
    return ResponseBody.fromString(
      stub.body == null ? '' : jsonEncode(stub.body),
      stub.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        for (final h in stub.headers.entries) h.key: [h.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeAuthService implements AuthService {
  @override
  Future<String> getIdToken({bool forceRefresh = false}) async => 'token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A real [ApiClient] whose API calls and S3 uploads both land on [http].
ApiClient apiClientOver(StubHttp http) => ApiClient(
      FakeAuthService(),
      httpClientAdapter: http,
      s3DioFactory: () => Dio()..httpClientAdapter = http,
    );
