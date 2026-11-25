import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/domain/models/create_user_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../verification/fake_verification_http.dart';

/// A returning deleted user (RFC-011 §5.6, D-12): what the app reads from SI-B2's backend.
void main() {
  group('UserExistsResponse.fromJson', () {
    test('reads deleted', () {
      final response =
          UserExistsResponse.fromJson({'exists': false, 'userId': 'uid-1', 'deleted': true});

      expect(response.exists, isFalse);
      expect(response.deleted, isTrue);
    });

    test('without deleted (a backend before SI-B2) parses as not deleted', () {
      final response = UserExistsResponse.fromJson({'exists': true, 'userId': 'uid-1'});

      expect(response.exists, isTrue);
      expect(response.deleted, isFalse);
    });
  });

  group('the 409 hook', () {
    late StubHttp http;

    setUp(() => http = StubHttp());

    Future<Object?> failureOf(StubResponse response) {
      http.responses['POST /users'] = response;
      return apiClientOver(http)
          .post<Map<String, dynamic>>('/users')
          .then<Object?>((_) => null, onError: (Object e) => e);
    }

    test('a 409 ACCOUNT_DELETED becomes AccountDeletedFailure, still a ConflictException',
        () async {
      final failure =
          await failureOf(reply(409, apiError('ACCOUNT_DELETED', 'This account was deleted')));

      expect(failure, isA<AccountDeletedFailure>());
      expect(failure, isA<ConflictException>());
      expect((failure as AccountDeletedFailure).message, 'This account was deleted');
    });

    test('any other 409 stays a plain ConflictException', () async {
      for (final body in [apiError('conflict'), {'message': 'ACCOUNT_DELETED'}, null]) {
        final failure = await failureOf(reply(409, body));

        expect(failure, isA<ConflictException>(), reason: '$body');
        expect(failure, isNot(isA<AccountDeletedFailure>()), reason: '$body');
      }
    });

    test('ProfileRepository.createUser passes AccountDeletedFailure on', () async {
      http.responses['POST /users'] = reply(409, apiError('ACCOUNT_DELETED'));
      final repository = ProfileRepository(
        apiClient: apiClientOver(http),
        authService: FakeAuthService(),
        logger: Logger(level: Level.off),
      );

      await expectLater(
        repository.createUser(_Request()),
        throwsA(isA<AccountDeletedFailure>()),
      );
    });

    test('ProfileRepository.createUser still turns a plain 409 into its message', () async {
      http.responses['POST /users'] = reply(409, apiError('conflict'));
      final repository = ProfileRepository(
        apiClient: apiClientOver(http),
        authService: FakeAuthService(),
        logger: Logger(level: Level.off),
      );

      await expectLater(
        repository.createUser(_Request()),
        throwsA(isA<ProfileRepositoryException>()),
      );
    });
  });
}

/// The body doesn't matter to the stub.
class _Request implements CreateUserRequest {
  @override
  Map<String, dynamic> toJson() => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
