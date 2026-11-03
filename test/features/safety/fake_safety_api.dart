import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

dynamic safetyFixture(String name) =>
    jsonDecode(File('test/fixtures/safety/$name.json').readAsStringSync());

/// Stubs HTTP for the safety and dates endpoints with the RFC-006 §5 JSON.
///
/// Answers by `'METHOD path'` from [responses]. A response that is an [ApiException] is
/// thrown. Records every request, and every S3 upload.
class FakeSafetyApi implements ApiClient {
  FakeSafetyApi({Map<String, Object>? responses}) : responses = responses ?? defaultResponses();

  final Map<String, Object> responses;
  final List<({String method, String path, dynamic data})> requests = [];
  final List<String> uploadedUrls = [];

  /// Makes every S3 upload fail.
  bool failUploads = false;

  /// When set, every S3 upload waits for it, so a test can hold an upload in flight.
  Completer<void>? uploadGate;

  static Map<String, Object> defaultResponses() => {
        'GET /safety/reasons': safetyFixture('reasons'),
        'POST /dates/7/report/evidence-url': safetyFixture('evidence_url'),
        'POST /dates/7/report': safetyFixture('report_refunded'),
      };

  /// The requests to [path] with [method].
  List<dynamic> sent(String method, String path) =>
      [for (final r in requests) if (r.method == method && r.path == path) r.data];

  T _answer<T>(String method, String path, dynamic data) {
    requests.add((method: method, path: path, data: data));
    final body = responses['$method $path'];
    if (body == null) throw StateError('No stub for $method $path');
    if (body is ApiException) throw body;
    // A fresh copy, as a real response would be.
    return jsonDecode(jsonEncode(body)) as T;
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
  Future<void> uploadToS3({
    required String presignedUrl,
    required List<int> fileBytes,
    required String contentType,
    Map<String, String> extraHeaders = const {},
    void Function(double progress)? onProgress,
  }) async {
    await uploadGate?.future;
    if (failUploads) throw const NetworkException('S3 refused the upload: 403 AccessDenied');
    uploadedUrls.add(presignedUrl);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The first bytes of a PNG, enough to be recognised. Not a decodable image.
final Uint8List pngBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  ...List.filled(120, 0),
]);

/// Returns [next] from the gallery, without a platform channel.
class FakeImagePicker implements ImagePicker {
  XFile? next;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async =>
      next;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUser implements User {
  @override
  String get uid => 'user1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthService implements AuthService {
  @override
  User? get currentUser => FakeUser();

  @override
  Future<String> getIdToken({bool forceRefresh = false}) async => 'token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `GET /dates/7` for the signed-in user1 and Sam, in [cityName].
Map<String, dynamic> dateDetailJson({
  String state = 'BOOKED',
  bool cancellable = true,
  String updatedAt = '2026-10-23T12:00:00Z',
  bool? yourRefundUnderReview,
  String cityName = 'London',
  String? scheduledStart = '2026-11-20T19:00:00Z',
}) =>
    {
      'dateId': 7,
      'matchId': 1007,
      'user1Id': 'user1',
      'user2Id': 'user2',
      'partnerName': 'Sam',
      'partnerThumbnailUrl': null,
      'activityId': 1,
      'activityName': 'Dinner',
      'durationMinutes': 120,
      'tokenCost': '5.00',
      'cityId': 1,
      'cityName': cityName,
      'state': state,
      'availabilityRound': 1,
      'scheduledStart': scheduledStart,
      'scheduledEnd': null,
      'depositDeadline': null,
      'rankingDeadline': null,
      'venueId': null,
      'venueName': null,
      'venueAddress': null,
      'venuePriceRange': null,
      'venueMenuUrl': null,
      'venueBookedAt': null,
      'bookingReference': null,
      'depositStatus': {'user1': 'PAID', 'user2': 'PAID'},
      'cancellable': cancellable,
      'timeline': <dynamic>[],
      'createdAt': '2026-10-20T12:00:00Z',
      'updatedAt': updatedAt,
      'yourRefundUnderReview': ?yourRefundUnderReview,
    };
