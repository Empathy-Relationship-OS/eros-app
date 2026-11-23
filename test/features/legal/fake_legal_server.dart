import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eros_app/core/network/api_client.dart';

import '../verification/fake_verification_http.dart' show FakeAuthService;

const String documentsPath = '/legal/documents';
const String consentsPath = '/users/me/consents';
const String usersMePath = '/users/me';
const String citiesPath = '/city/all';

/// `GET /legal/documents` item.
Map<String, dynamic> documentJson(String kind, {String version = '2026-11', bool required = false}) => {
      'kind': kind,
      'version': version,
      'url': 'https://meetmymuse.com/${kind.toLowerCase()}',
      'effectiveAt': '2026-11-01T00:00:00Z',
      'required': required,
    };

/// A request the fake answered.
typedef SentRequest = ({String method, String path, Map<String, String> query, Object? body});

/// A small stand-in for the backend's compliance routes, `GET /users/me`, `GET /city/all` and
/// `DELETE /users/me`, behind a real [ApiClient]. Consents are state: a `POST` changes what the
/// next `GET` answers, as on the server, so a test sees whether the app refetched.
class FakeLegalServer implements HttpClientAdapter {
  FakeLegalServer({
    List<Map<String, dynamic>>? documents,
    Map<String, bool>? granted,
    this.city = 'London',
  })  : documents = documents ??
            [
              documentJson('TERMS', required: true),
              documentJson('PRIVACY_NOTICE', required: true),
              documentJson('SAFETY_NOTICE', required: true),
              documentJson('SENSITIVE_DATA', version: 's-3', required: true),
              documentJson('LOCATION_PIN', version: 'p-2'),
              documentJson('MARKETING', version: 'm-1'),
            ],
        granted = granted ?? {'MARKETING': true, 'LOCATION_PIN': false, 'SENSITIVE_DATA': true};

  final List<Map<String, dynamic>> documents;

  /// The newest row per kind: granted or withdrawn.
  final Map<String, bool> granted;

  /// The profile's city name.
  final String city;

  /// The next `POST /users/me/consents` answers this instead, once.
  ({int status, Map<String, dynamic> body})? nextConsentRefusal;

  /// What `DELETE /users/me` answers.
  int deleteStatus = 204;

  final List<SentRequest> requests = [];

  List<SentRequest> sent(String method, String path) =>
      [for (final r in requests) if (r.method == method && r.path == path) r];

  Map<String, dynamic> _state({bool orientationRetained = false}) => {
        'consents': [
          for (final entry in granted.entries)
            {
              'kind': entry.key,
              'version': _versionOf(entry.key),
              'granted': entry.value,
              'at': '2026-11-20T10:00:00Z',
            },
        ],
        'outstanding': <String>[],
        if (orientationRetained) 'orientationRetained': true,
      };

  String _versionOf(String kind) =>
      documents.firstWhere((d) => d['kind'] == kind, orElse: () => {'version': '1'})['version']
          as String;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    final body = bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes));
    final path = options.uri.path;
    requests.add((
      method: options.method,
      path: path,
      query: options.uri.queryParameters,
      body: body,
    ));

    switch ('${options.method} $path') {
      case 'GET $usersMePath':
        final profile = jsonDecode(File('test/fixtures/users/get_users_me.json').readAsStringSync())
            as Map<String, dynamic>;
        return _json(200, profile..['city'] = city);
      case 'GET $citiesPath':
        return _json(200, [
          {'cityId': 1, 'cityName': 'london'},
          {'cityId': 2, 'cityName': 'Houston'},
        ]);
      case 'GET $documentsPath':
        return _json(200, documents);
      case 'GET $consentsPath':
        return _json(200, _state());
      case 'POST $consentsPath':
        final refusal = nextConsentRefusal;
        if (refusal != null) {
          nextConsentRefusal = null;
          return _json(refusal.status, refusal.body);
        }
        var withdrewSensitive = false;
        for (final choice in (body as Map<String, dynamic>)['consents'] as List<dynamic>) {
          final c = choice as Map<String, dynamic>;
          granted[c['kind'] as String] = c['granted'] as bool;
          if (c['kind'] == 'SENSITIVE_DATA' && c['granted'] == false) withdrewSensitive = true;
        }
        return _json(200, _state(orientationRetained: withdrewSensitive));
      case 'DELETE $usersMePath':
        return ResponseBody.fromString('', deleteStatus);
    }
    throw StateError('No stub for ${options.method} $path');
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// A real [ApiClient] whose requests land on [server].
ApiClient apiClientOverLegal(FakeLegalServer server) =>
    ApiClient(FakeAuthService(), httpClientAdapter: server);
