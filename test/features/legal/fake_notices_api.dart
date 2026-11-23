import 'package:dio/dio.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';

/// Stubs `GET /users/me/notices` and `POST /users/me/notices/{id}/read` as RFC-009 §6 has them.
/// [notices] is the server's state, newest first; a read marks the notice read in it.
class FakeNoticesApi implements ApiClient {
  FakeNoticesApi([List<Map<String, dynamic>>? notices]) : notices = notices ?? [];

  final List<Map<String, dynamic>> notices;
  final List<String> gets = [];
  final List<String> posts = [];

  /// Thrown by the next GET, then cleared.
  ApiException? getError;

  /// Thrown by every POST while set.
  ApiException? postError;

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    gets.add(path);
    final error = getError;
    if (error != null) {
      getError = null;
      throw error;
    }
    if (path != '/users/me/notices') throw const NotFoundException('No such route');
    return notices.map((n) => Map<String, dynamic>.of(n)).toList() as T;
  }

  @override
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    posts.add(path);
    if (postError != null) throw postError!;
    final match = RegExp(r'^/users/me/notices/(\d+)/read$').firstMatch(path);
    final notice = notices.where((n) => '${n['noticeId']}' == match?.group(1)).firstOrNull;
    if (notice == null) throw const NotFoundException('Not found');
    notice['read'] = true;
    return null as T;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A `FRAUD_CONTACT_BANNED` notice as the server sends it.
Map<String, dynamic> fraudNotice(
  int id, {
  bool read = false,
  String? documentUrl = 'https://muse.app/legal/fraud-notice',
  String kind = 'FRAUD_CONTACT_BANNED',
}) =>
    {
      'noticeId': id,
      'kind': kind,
      'createdAt': '2026-11-20T10:00:00Z',
      'read': read,
      'documentUrl': documentUrl,
    };
