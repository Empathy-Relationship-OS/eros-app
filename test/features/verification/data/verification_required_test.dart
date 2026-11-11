import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../safety/fake_safety_api.dart' show dateDetailJson;
import '../fake_verification_http.dart';

void main() {
  group('the 403 hook', () {
    late StubHttp http;

    setUp(() => http = StubHttp());

    Future<Object?> failureOf(StubResponse response) {
      http.responses['POST /dates/7/deposit'] = response;
      return apiClientOver(http)
          .post<Map<String, dynamic>>('/dates/7/deposit')
          .then<Object?>((_) => null, onError: (Object e) => e);
    }

    test('a 403 VERIFICATION_REQUIRED becomes VerificationRequiredFailure', () async {
      final failure = await failureOf(reply(
        403,
        apiError('VERIFICATION_REQUIRED', 'Verify it\'s you to continue with this date'),
      ));

      expect(failure, isA<VerificationRequiredFailure>());
      failure as VerificationRequiredFailure;
      expect(failure.statusCode, 403);
      expect(failure.message, 'Verify it\'s you to continue with this date');
      // Still a 403 to code that doesn't know about verification.
      expect(failure, isA<ForbiddenException>());
    });

    test('any other 403 does not', () async {
      for (final body in [
        apiError('FORBIDDEN'),
        {'message': 'VERIFICATION_REQUIRED'},
        null,
      ]) {
        final failure = await failureOf(reply(403, body));

        expect(failure, isA<ForbiddenException>(), reason: '$body');
        expect(failure, isNot(isA<VerificationRequiredFailure>()), reason: '$body');
      }
    });

    test('the same code on another status does not', () async {
      final failure = await failureOf(reply(409, apiError('VERIFICATION_REQUIRED')));

      expect(failure, isA<ConflictException>());
    });
  });

  group('DateDetail.verificationRequired', () {
    test('a response without it parses as false', () {
      final json = dateDetailJson();
      expect(json.containsKey('verificationRequired'), isFalse);

      expect(DateDetail.fromJson(json).verificationRequired, isFalse);
    });

    test('is read when sent', () {
      expect(
        DateDetail.fromJson({...dateDetailJson(), 'verificationRequired': true})
            .verificationRequired,
        isTrue,
      );
      expect(
        DateDetail.fromJson({...dateDetailJson(), 'verificationRequired': false})
            .verificationRequired,
        isFalse,
      );
    });
  });
}
