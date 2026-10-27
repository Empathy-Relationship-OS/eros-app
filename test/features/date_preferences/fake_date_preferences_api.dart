import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';

dynamic dpFixture(String name) =>
    jsonDecode(File('test/fixtures/date_preferences/$name.json').readAsStringSync());

/// Stubs the date preference endpoints: answers by path from [responses], or throws [error].
/// Records every request so tests can check what was sent.
class FakeDatePreferencesApi implements ApiClient {
  FakeDatePreferencesApi({Map<String, Object>? responses, this.error})
      : responses = responses ?? {};

  final Map<String, Object> responses;
  ApiException? error;
  final List<({String method, String path, dynamic data})> requests = [];

  T _answer<T>(String method, String path, dynamic data) {
    requests.add((method: method, path: path, data: data));
    if (error != null) throw error!;
    final body = responses['$method $path'];
    if (body == null) throw StateError('No stub for $method $path');
    return body as T;
  }

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options}) async =>
      _answer<T>('GET', path, null);

  @override
  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      _answer<T>('PATCH', path, data);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
