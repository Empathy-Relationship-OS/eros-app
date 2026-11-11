import 'dart:typed_data';

import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/verification/data/verification_repository.dart';
import 'package:eros_app/features/verification/domain/models/verification_failures.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_verification_http.dart';

void main() {
  late StubHttp http;
  late VerificationRepository repository;

  setUp(() {
    http = StubHttp();
    repository = VerificationRepository(apiClientOver(http));
  });

  Future<VerificationAttemptStart> start() {
    http.responses['POST $attemptsPath'] = reply(200, verificationFixture('attempt_start'));
    return repository.startAttempt(consentVersion: '1', automatedCheck: true);
  }

  group('status', () {
    Future<VerificationStatus> read(Map<String, dynamic> json) {
      http.responses['GET $statusPath'] = reply(200, json);
      return repository.getStatus();
    }

    test('each state parses', () async {
      const states = {
        'NOT_VERIFIED': VerificationState.notVerified,
        'IN_REVIEW': VerificationState.inReview,
        'RETRY': VerificationState.retry,
        'VERIFIED': VerificationState.verified,
        'LOCKED': VerificationState.locked,
      };
      for (final entry in states.entries) {
        expect((await read(statusJson(entry.key))).state, entry.value, reason: entry.key);
      }
    });

    test('reads every field of a retry', () async {
      final status = await read(verificationFixture('status_retry') as Map<String, dynamic>);

      expect(status.state, VerificationState.retry);
      expect(status.reason, RetryReason.poseMissing);
      expect(status.attemptsLeftToday, 2);
      expect(status.canStart, isTrue);
      expect(status.consentVersion, '1');
      expect(status.isVerified, isFalse);
    });

    test('each reason parses', () async {
      const reasons = {
        'POSE_MISSING': RetryReason.poseMissing,
        'UNCLEAR': RetryReason.unclear,
        'NOT_SAME_PERSON': RetryReason.notSamePerson,
        'PROFILE_PHOTOS_UNSUITABLE': RetryReason.profilePhotosUnsuitable,
        'OTHER': RetryReason.other,
      };
      for (final entry in reasons.entries) {
        final status = await read(statusJson('RETRY', reason: entry.key));
        expect(status.reason, entry.value, reason: entry.key);
      }
    });

    test('there is no reason outside a retry', () async {
      expect((await read(statusJson('IN_REVIEW'))).reason, isNull);
      expect((await read(statusJson('VERIFIED'))).isVerified, isTrue);
    });

    test('an unknown state and reason do not throw', () async {
      final status = await read(statusJson('PAUSED_BY_STAFF', reason: 'SOMETHING_NEW'));

      expect(status.state, VerificationState.unknown);
      expect(status.reason, RetryReason.other);
    });

    test('a retry with no reason reads as other, and missing fields take safe defaults',
        () async {
      final status = await read({'state': 'RETRY'});

      expect(status.reason, RetryReason.other);
      expect(status.attemptsLeftToday, 0);
      expect(status.canStart, isFalse);
      expect(status.consentVersion, '');
    });

    test('503 becomes VerificationUnavailableFailure', () async {
      http.responses['GET $statusPath'] = reply(503, apiError('SERVICE_UNAVAILABLE'));

      await expectLater(repository.getStatus(), throwsA(isA<VerificationUnavailableFailure>()));
    });
  });

  group('start', () {
    test('sends the consent version and the choice, and reads the attempt', () async {
      http.responses['POST $attemptsPath'] = reply(200, verificationFixture('attempt_start'));

      final attempt = await repository.startAttempt(consentVersion: '1', automatedCheck: false);

      expect(http.sent('POST', attemptsPath).single.data, {
        'consentVersion': '1',
        'automatedCheck': false,
      });
      expect(attempt.attemptId, attemptId);
      expect(attempt.pose.key, 'HAND_RAISED');
      expect(attempt.pose.instruction, 'Raise your hand beside your face');
      expect(attempt.url, contains('X-Amz-Signature=abc'));
      expect(attempt.headers, {
        'Content-Type': 'image/jpeg',
        'x-amz-server-side-encryption': 'aws:kms',
      });
      expect(attempt.expiresAt, DateTime.utc(2026, 11, 10, 19, 15));
    });

    test('never prints the upload link', () async {
      final attempt = await start();

      expect(attempt.toString(), isNot(contains('amazonaws')));
      expect(attempt.upload.toString(), isNot(contains('amazonaws')));
    });

    Future<void> expectRefusal(StubResponse response, Matcher failure) async {
      http.responses['POST $attemptsPath'] = response;
      await expectLater(
        repository.startAttempt(consentVersion: '1', automatedCheck: true),
        throwsA(failure),
      );
    }

    test('409 PHOTOS_REQUIRED becomes PhotosRequiredFailure', () {
      return expectRefusal(reply(409, apiError('PHOTOS_REQUIRED')), isA<PhotosRequiredFailure>());
    });

    test('409 ALREADY_VERIFIED becomes AlreadyVerifiedFailure', () {
      return expectRefusal(
        reply(409, apiError('ALREADY_VERIFIED')),
        isA<AlreadyVerifiedFailure>(),
      );
    });

    test('any other 409 stays a ConflictException', () {
      return expectRefusal(reply(409, apiError('ATTEMPT_IN_REVIEW')), isA<ConflictException>());
    });

    test('429 becomes VerificationLimitFailure, with Retry-After when sent', () {
      return expectRefusal(
        reply(429, apiError('TOO_MANY_ATTEMPTS'), headers: {'retry-after': '3600'}),
        isA<VerificationLimitFailure>()
            .having((f) => f.retryAfter, 'retryAfter', const Duration(hours: 1))
            .having((f) => f.cause, 'cause', isA<RateLimitException>()),
      );
    });

    test('503 becomes VerificationUnavailableFailure', () {
      return expectRefusal(
        reply(503, apiError('SERVICE_UNAVAILABLE')),
        isA<VerificationUnavailableFailure>(),
      );
    });
  });

  group('upload', () {
    final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x80, 0xFE, 0x01]);

    test('PUTs the bytes to the link with the given headers and no Authorization', () async {
      final attempt = await start();
      http.responses['PUT /selfies/user1/3f2504e0.jpg'] = reply(200, null);

      await repository.uploadSelfie(attempt, bytes);

      final put = http.requests.last;
      expect(put.method, 'PUT');
      expect(put.uri.toString(), attempt.url);
      expect(http.sentBodies.last, bytes);

      final headers = {for (final h in put.headers.entries) h.key.toLowerCase(): '${h.value}'};
      expect(headers['content-type'], 'image/jpeg');
      expect(headers['x-amz-server-side-encryption'], 'aws:kms');
      expect(headers, isNot(contains('authorization')));
      // Nothing beyond what was signed, plus the length of the body.
      expect(headers.keys.toSet(), {
        'content-type',
        'content-length',
        'x-amz-server-side-encryption',
      });
      // The API call before it did carry the token, so the check above means something.
      expect(http.sent('POST', attemptsPath).single.headers['Authorization'], 'Bearer token');
    });

    test('a refused upload is a NetworkException', () async {
      final attempt = await start();
      http.responses['PUT /selfies/user1/3f2504e0.jpg'] = reply(403, null);

      await expectLater(
        repository.uploadSelfie(attempt, bytes),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('submit', () {
    test('reads the new state', () async {
      http.responses['POST $submitPath'] = reply(200, {'state': 'IN_REVIEW'});
      expect(await repository.submit(attemptId), VerificationState.inReview);
      expect(http.sent('POST', submitPath), hasLength(1));

      http.responses['POST $submitPath'] = reply(200, {'state': 'VERIFIED'});
      expect(await repository.submit(attemptId), VerificationState.verified);
    });

    test('422 SELFIE_UNUSABLE carries the problem and the fresh upload link', () async {
      http.responses['POST $submitPath'] = reply(422, verificationFixture('selfie_unusable'));

      final failure = await repository.submit(attemptId).then<Object?>((_) => null, onError: (e) => e);

      expect(failure, isA<SelfieUnusableFailure>());
      failure as SelfieUnusableFailure;
      expect(failure.problem, SelfieProblem.tooDark);
      expect(failure.upload!.url, contains('X-Amz-Signature=fresh'));
      expect(failure.upload!.headers, {'Content-Type': 'image/jpeg'});
      expect(failure.expiresAt, DateTime.utc(2026, 11, 10, 19, 30));

      // The retake goes to the fresh link on the same attempt.
      final retake = (await start()).withUpload(failure.upload!, expiresAt: failure.expiresAt);
      expect(retake.attemptId, attemptId);
      expect(retake.url, failure.upload!.url);
      expect(retake.expiresAt, failure.expiresAt);
    });

    test('a fresh link without an expiry does not inherit the old link\'s expiry', () async {
      final first = await start();
      expect(first.expiresAt, isNotNull);

      final retake = first.withUpload(
        const SelfieUpload(url: 'https://s3.example/fresh', headers: {}),
      );

      expect(retake.expiresAt, isNull);
    });

    test('each problem parses, an unknown one as other, and a missing link as null', () async {
      const problems = {
        'NO_FACE': SelfieProblem.noFace,
        'SEVERAL_FACES': SelfieProblem.severalFaces,
        'FACE_TOO_SMALL': SelfieProblem.faceTooSmall,
        'TOO_DARK': SelfieProblem.tooDark,
        'TOO_BLURRY': SelfieProblem.tooBlurry,
        'EYES_NOT_VISIBLE': SelfieProblem.eyesNotVisible,
        'SUNGLASSES': SelfieProblem.sunglasses,
        'WEARING_A_MASK': SelfieProblem.other,
      };
      for (final entry in problems.entries) {
        http.responses['POST $submitPath'] =
            reply(422, {...apiError('SELFIE_UNUSABLE'), 'problem': entry.key});

        await expectLater(
          repository.submit(attemptId),
          throwsA(isA<SelfieUnusableFailure>()
              .having((f) => f.problem, 'problem', entry.value)
              .having((f) => f.upload, 'upload', isNull)),
          reason: entry.key,
        );
      }
    });

    test('429 and 503 map to their failures', () async {
      http.responses['POST $submitPath'] = reply(429, apiError('TOO_MANY_ATTEMPTS'));
      await expectLater(repository.submit(attemptId), throwsA(isA<VerificationLimitFailure>()));

      http.responses['POST $submitPath'] = reply(503, apiError('SERVICE_UNAVAILABLE'));
      await expectLater(
        repository.submit(attemptId),
        throwsA(isA<VerificationUnavailableFailure>()),
      );
    });

    test('an uncoded error stays the usual ApiException', () async {
      http.responses['POST $submitPath'] = reply(404, apiError('NOT_FOUND'));

      await expectLater(repository.submit(attemptId), throwsA(isA<NotFoundException>()));
    });
  });
}
