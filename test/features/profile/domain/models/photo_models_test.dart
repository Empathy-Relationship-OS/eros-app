import 'package:eros_app/features/profile/domain/models/photo_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PresignedUploadResponse.fromJson', () {
    test('reads requiredHeaders when the backend sends them', () {
      final response = PresignedUploadResponse.fromJson({
        'uploadUrl': 'https://bucket.s3.amazonaws.com/photos/u/1.jpg?sig',
        'objectKey': 'photos/u/1.jpg',
        'expiresInMinutes': 15,
        'requiredHeaders': {'x-amz-tagging': 'upload_confirmed=false'},
      });

      expect(response.requiredHeaders, {'x-amz-tagging': 'upload_confirmed=false'});
    });

    test('defaults to no required headers for an older backend', () {
      final response = PresignedUploadResponse.fromJson({
        'uploadUrl': 'https://bucket.s3.amazonaws.com/photos/u/1.jpg?sig',
        'objectKey': 'photos/u/1.jpg',
        'expiresInMinutes': 15,
      });

      expect(response.requiredHeaders, isEmpty);
    });
  });

  group('PhotoUploadDraft.fromJson', () {
    test('loads a draft saved with a caption by an older build', () {
      final draft = PhotoUploadDraft.fromJson({
        'localPath': '/photos/a.jpg',
        'displayOrder': 2,
        'isPrimary': false,
        'caption': 'Weekend vibes',
      });

      expect(draft.localPath, '/photos/a.jpg');
      expect(draft.displayOrder, 2);
      expect(draft.toJson().containsKey('caption'), isFalse);
    });
  });

  group('PresignedUploadRequest', () {
    PresignedUploadRequest build({required String contentType, required int size}) =>
        PresignedUploadRequest(
          fileName: 'photo',
          contentType: contentType,
          fileSizeBytes: size,
          displayOrder: 1,
        );

    test('accepts WebP', () {
      expect(() => build(contentType: 'image/webp', size: 200 * 1024), returnsNormally);
    });

    test('rejects a photo under 100 KB', () {
      expect(() => build(contentType: 'image/jpeg', size: 50 * 1024), throwsArgumentError);
    });

    test('rejects a GIF', () {
      expect(() => build(contentType: 'image/gif', size: 200 * 1024), throwsArgumentError);
    });
  });
}
