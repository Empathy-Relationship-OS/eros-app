import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/network/api_client.dart';
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
}
