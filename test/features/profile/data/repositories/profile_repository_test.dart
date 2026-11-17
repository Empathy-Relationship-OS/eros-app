import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/domain/models/update_user_request.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

Map<String, dynamic> _fixture() =>
    jsonDecode(File('test/fixtures/users/get_users_me.json').readAsStringSync()) as Map<String, dynamic>;

/// Answers every GET and PATCH with [body].
class _FakeApiClient implements ApiClient {
  _FakeApiClient(this.body);

  final Map<String, dynamic> body;

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options}) async =>
      body as T;

  @override
  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      body as T;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProfileRepository _repository(Map<String, dynamic> body) => ProfileRepository(
      apiClient: _FakeApiClient(body),
      authService: AuthService(auth: _FakeFirebaseAuth()),
      logger: Logger(level: Level.off),
    );

/// Records each PUT and answers it with [answer], or throws [error].
class _PhoneApiClient implements ApiClient {
  _PhoneApiClient({this.answer = const {}, this.error});

  final Map<String, dynamic> answer;
  final Object? error;
  final puts = <({String path, dynamic data})>[];

  @override
  Future<T> put<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    puts.add((path: path, data: data));
    if (error != null) throw error!;
    return answer as T;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProfileRepository _phoneRepository(_PhoneApiClient client) => ProfileRepository(
      apiClient: client,
      authService: AuthService(auth: _FakeFirebaseAuth()),
      logger: Logger(level: Level.off),
    );

void main() {
  // A response the app can't read: a required field is missing.
  final unreadable = {..._fixture()}..remove('gender');

  group('getCurrentUser', () {
    test('returns the parsed profile', () async {
      final profile = await _repository(_fixture()).getCurrentUser();

      expect(profile.userId, 'fixture-user');
    });

    test('turns an unreadable response into a ProfileRepositoryException', () async {
      await expectLater(
        _repository(unreadable).getCurrentUser(),
        throwsA(isA<ProfileRepositoryException>()
            .having((e) => e.message, 'message', contains('couldn\'t load your profile'))),
      );
    });
  });

  group('updateUser', () {
    test('says the change was saved when only the response is unreadable', () async {
      await expectLater(
        _repository(unreadable).updateUser(UpdateUserRequest(bio: 'New bio')),
        throwsA(isA<ProfileRepositoryException>()
            .having((e) => e.message, 'message', contains('Your changes were saved'))),
      );
    });
  });

  group('updatePhoneNumber (RFC-010)', () {
    test('PUTs the number and returns the one the server stored', () async {
      final client = _PhoneApiClient(answer: {'phoneNumber': '+447400123456'});

      final stored = await _phoneRepository(client).updatePhoneNumber('+447400123456');

      expect(stored, '+447400123456');
      expect(client.puts.single.path, '/users/me/phone');
      expect(client.puts.single.data, {'phoneNumber': '+447400123456'});
    });

    test('sends null to remove it', () async {
      final client = _PhoneApiClient(answer: {'phoneNumber': null});

      expect(await _phoneRepository(client).updatePhoneNumber(null), isNull);
      expect(client.puts.single.data, {'phoneNumber': null});
    });

    test('turns a 400 into the sign-up wording', () async {
      final client = _PhoneApiClient(error: const ValidationException('phoneNumber is not a valid phone number'));

      await expectLater(
        _phoneRepository(client).updatePhoneNumber('+4474'),
        throwsA(isA<ProfileValidationException>().having(
          (e) => e.getUserMessage(),
          'message',
          ProfileRepository.phoneNumberRejectedMessage,
        )),
      );
    });
  });
}
