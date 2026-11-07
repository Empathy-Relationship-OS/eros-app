import 'dart:convert';

import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/constants/languages.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/auth/data/repositories/marketing_preference_repository.dart';
import 'package:eros_app/features/match_preferences/data/match_preferences_repository.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/domain/enums/personality.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/create_user_request.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/domain/models/profile_creation_draft.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/submission/profile_submission_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../match_preferences/fake_match_preferences_api.dart';

const _preferencesPath = '/users/me/match-preferences';

class _FakeUser implements User {
  @override
  String get uid => 'user1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthService implements AuthService {
  @override
  User? get currentUser => _FakeUser();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records each call in [log], shared with the match preferences API, so the order shows.
class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.log);

  final List<String> log;

  @override
  Future<void> createUser(CreateUserRequest request) async => log.add('POST /users');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMarketingRepository implements MarketingPreferenceRepository {
  @override
  Future<Never> createMarketingPreference({required bool marketingConsent}) async =>
      throw const ConflictException('exists');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Logs each request as it arrives, alongside the profile repository's.
class _LoggingApi extends FakeMatchPreferencesApi {
  _LoggingApi(this.log, {super.responses});

  final List<String> log;

  @override
  Future<T> patch<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, options}) {
    log.add('PATCH $path');
    return super.patch<T>(path, data: data, queryParameters: queryParameters, options: options);
  }
}

ProfileCreationDraft _draft({List<Gender>? interestedIn}) => ProfileCreationDraft(
      firstName: 'Alex',
      lastName: 'Smith',
      email: 'alex@example.com',
      heightCm: 175,
      dateOfBirth: DateTime(1995, 5, 1),
      city: 'London',
      coordinatesLatitude: 51.5,
      coordinatesLongitude: -0.1,
      gender: Gender.female,
      interestedIn: interestedIn,
      educationLevel: EducationLevel.university,
      preferredLanguage: Languages.all.first,
      spokenLanguages: DisplayableField(field: [Languages.all.first]),
      interests: const ['HIKING', 'COFFEE', 'JAZZ', 'GOLF', 'READING'],
      traits: const [Trait.adventurous, Trait.ambitious, Trait.creative],
    );

Map<String, dynamic> _saved() {
  final body = mpFixture('get_users_me_match_preferences_defaults') as Map<String, dynamic>;
  body['isSet'] = true;
  body['gender'] = {'values': ['MALE'], 'dealbreaker': true};
  return body;
}

Future<void> _pump(WidgetTester tester, ProfileCreationDraft draft, _LoggingApi api) async {
  SharedPreferences.setMockInitialValues({'profile_creation_draft': jsonEncode(draft.toJson())});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authServiceProvider.overrideWithValue(_FakeAuthService()),
      profileRepositoryProvider.overrideWithValue(_FakeProfileRepository(api.log)),
      marketingPreferenceRepositoryProvider.overrideWithValue(_FakeMarketingRepository()),
      matchPreferencesRepositoryProvider.overrideWithValue(
        MatchPreferencesRepository(apiClient: api, logger: Logger(level: Level.off)),
      ),
    ],
    child: MaterialApp(
      home: const ProfileSubmissionScreen(),
      routes: {'/profile-creation/qa': (_) => const Text('Q&A')},
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('ProfileSubmissionScreen and Interested in', () {
    testWidgets('sends the onboarding choice once the profile exists, gender only',
        (tester) async {
      final log = <String>[];
      final api = _LoggingApi(log, responses: {
        'GET $_preferencesPath': mpFixture('get_users_me_match_preferences_defaults') as Object,
        'PATCH $_preferencesPath': _saved(),
      });

      await _pump(tester, _draft(interestedIn: [Gender.male]), api);

      expect(log, ['POST /users', 'PATCH $_preferencesPath']);
      final patch = api.requests.singleWhere((r) => r.method == 'PATCH');
      expect(patch.data, {
        'gender': {'values': ['MALE'], 'dealbreaker': true},
      });
      expect(find.text('Q&A'), findsOneWidget);
    });

    testWidgets('a failed save doesn\'t stop sign-up', (tester) async {
      final log = <String>[];
      final api = _LoggingApi(log)..error = const ServerException('down');

      await _pump(tester, _draft(interestedIn: [Gender.male]), api);

      expect(log, ['POST /users', 'PATCH $_preferencesPath']);
      expect(find.text('Q&A'), findsOneWidget);
      expect(find.text('Oops! Something went wrong'), findsNothing);
    });

    testWidgets('sends nothing when the draft has no choice', (tester) async {
      final log = <String>[];
      final api = _LoggingApi(log);

      await _pump(tester, _draft(), api);

      expect(log, ['POST /users']);
      expect(find.text('Q&A'), findsOneWidget);
    });
  });
}
