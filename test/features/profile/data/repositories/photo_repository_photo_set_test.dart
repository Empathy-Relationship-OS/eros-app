import 'dart:io';

import 'package:dio/dio.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/profile/data/repositories/photo_repository.dart';
import 'package:eros_app/features/profile/domain/models/photo_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

/// `UserMediaCollectionDTO` as the backend serialises it (eros-backend `UserMedia.kt`), with the
/// items deliberately out of order.
Map<String, dynamic> _collectionJson({bool verificationReset = false}) => {
      'userId': 'dev_alice',
      'media': [
        {
          'id': 42, 'mediaUrl': 'https://cdn/photos/dev_alice/b.jpg?sig', 'thumbnailUrl': null,
          'mediaType': 'PHOTO', 'displayOrder': 2, 'isPrimary': false, 'isVerificationPhoto': true,
        },
        {
          'id': 41, 'mediaUrl': 'https://cdn/photos/dev_alice/a.jpg?sig', 'thumbnailUrl': null,
          'mediaType': 'PHOTO', 'displayOrder': 1, 'isPrimary': true, 'isVerificationPhoto': false,
        },
        {
          'id': 43, 'mediaUrl': 'https://cdn/photos/dev_alice/c.jpg?sig', 'thumbnailUrl': null,
          'mediaType': 'PHOTO', 'displayOrder': 3, 'isPrimary': false, 'isVerificationPhoto': false,
        },
      ],
      'totalCount': 3,
      'revision': '9f2c41aa07d3e1b8',
      'verificationReset': verificationReset,
    };

/// Records calls; [putError] makes PUT throw.
class _FakeApiClient implements ApiClient {
  final calls = <(String, String, dynamic)>[];
  Object? putError;
  Map<String, String>? s3Headers;
  void Function(double)? s3Progress;

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    calls.add(('GET', path, null));
    return _collectionJson() as T;
  }

  @override
  Future<T> put<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    calls.add(('PUT', path, data));
    if (putError != null) throw putError!;
    return _collectionJson(verificationReset: true) as T;
  }

  @override
  Future<T> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    calls.add(('POST', path, data));
    return {
      'uploadUrl': 'https://s3/put?sig',
      'objectKey': 'photos/dev_alice/new.jpg',
      'expiresInMinutes': 15,
      'requiredHeaders': {'x-amz-tagging': 'upload_confirmed=false'},
    } as T;
  }

  @override
  Future<void> uploadToS3({
    required String presignedUrl,
    required List<int> fileBytes,
    required String contentType,
    Map<String, String> extraHeaders = const {},
    void Function(double progress)? onProgress,
  }) async {
    calls.add(('S3', presignedUrl, contentType));
    s3Headers = extraHeaders;
    s3Progress = onProgress;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeApiClient api;
  late PhotoRepository repository;

  setUp(() {
    api = _FakeApiClient();
    repository = PhotoRepository(
      apiClient: api,
      authService: AuthService(auth: _FakeFirebaseAuth()),
      logger: Logger(level: Level.off),
    );
  });

  test('getMyPhotos reads GET /users/me/photos in position order, with the revision', () async {
    final photos = await repository.getMyPhotos();

    expect(api.calls.single.$2, '/users/me/photos');
    expect(photos.photos.map((p) => p.id), [41, 42, 43]);
    expect(photos.photos.map((p) => p.isVerificationPhoto), [false, true, false]);
    expect(photos.revision, '9f2c41aa07d3e1b8');
    expect(photos.verificationReset, isFalse);
  });

  test('stageUpload presigns, uploads with the required headers, and never confirms', () async {
    final file = File('${Directory.systemTemp.createTempSync().path}/new.jpg')..writeAsBytesSync(List.filled(200000, 1));
    double? progress;

    final key = await repository.stageUpload(
      file: file,
      contentType: 'image/jpeg',
      sizeBytes: 200000,
      displayOrder: 4,
      onProgress: (p) => progress = p,
    );
    api.s3Progress!(0.4);

    expect(key, 'photos/dev_alice/new.jpg');
    expect(api.calls.map((c) => c.$1), ['POST', 'S3'], reason: 'presign then S3; no confirm POST');
    expect((api.calls.first.$3 as Map)['displayOrder'], 4);
    expect(api.s3Headers, {'x-amz-tagging': 'upload_confirmed=false'});
    expect(progress, 0.4);
  });

  test('commitPhotoSet sends the revision and ordered entries with PUT', () async {
    final saved = await repository.commitPhotoSet('rev-1', const [
      PhotoSetEntry.saved(41),
      PhotoSetEntry.staged('photos/dev_alice/new.jpg'),
      PhotoSetEntry.saved(43),
    ]);

    expect(api.calls.single.$1, 'PUT');
    expect(api.calls.single.$2, '/users/me/photos');
    expect(api.calls.single.$3, {
      'revision': 'rev-1',
      'photos': [
        {'photoId': 41},
        {'objectKey': 'photos/dev_alice/new.jpg'},
        {'photoId': 43},
      ],
    });
    expect(saved.verificationReset, isTrue);
  });

  test('a 409 becomes a PhotoSetConflictException', () async {
    api.putError = const ConflictException('Your photos have changed since you opened them.', statusCode: 409);

    await expectLater(repository.commitPhotoSet('stale', const [PhotoSetEntry.saved(41)]),
        throwsA(isA<PhotoSetConflictException>()));
  });

  test('a 400 keeps the server\'s message', () async {
    api.putError = const ValidationException('You need between 3 and 6 photos');

    await expectLater(
      repository.commitPhotoSet('rev-1', const [PhotoSetEntry.saved(41)]),
      throwsA(isA<PhotoRepositoryException>().having((e) => e.message, 'message', 'You need between 3 and 6 photos')),
    );
  });
}
