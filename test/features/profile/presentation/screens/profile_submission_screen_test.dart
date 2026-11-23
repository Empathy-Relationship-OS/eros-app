import 'dart:convert';

import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/constants/languages.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/auth/data/repositories/marketing_preference_repository.dart';
import 'package:eros_app/features/legal/domain/consent_required.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';
import 'package:eros_app/features/legal/presentation/legal_routes.dart';
import 'package:eros_app/features/legal/presentation/providers/signup_consents_provider.dart';
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
  _FakeProfileRepository(this.log, {this.error});

  final List<String> log;

  /// Thrown by [createUser] instead of succeeding.
  final Object? error;

  /// The last request [createUser] received.
  CreateUserRequest? sent;

  @override
  Future<void> createUser(CreateUserRequest request) async {
    log.add('POST /users');
    sent = request;
    if (error != null) throw error!;
  }

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

ProfileCreationDraft _draft({List<Gender>? interestedIn, String? phoneNumber}) => ProfileCreationDraft(
      phoneNumber: phoneNumber,
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

Future<void> _pump(
  WidgetTester tester,
  ProfileCreationDraft draft,
  _LoggingApi api, {
  _FakeProfileRepository? repository,
  Map<String, String?>? consents,
}) async {
  SharedPreferences.setMockInitialValues({
    'profile_creation_draft': jsonEncode(draft.toJson()),
    if (consents != null) SignupConsentsNotifier.storageKey: jsonEncode(consents),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authServiceProvider.overrideWithValue(_FakeAuthService()),
      profileRepositoryProvider.overrideWithValue(repository ?? _FakeProfileRepository(api.log)),
      marketingPreferenceRepositoryProvider.overrideWithValue(_FakeMarketingRepository()),
      matchPreferencesRepositoryProvider.overrideWithValue(
        MatchPreferencesRepository(apiClient: api, logger: Logger(level: Level.off)),
      ),
    ],
    child: MaterialApp(
      home: const ProfileSubmissionScreen(),
      routes: {
        '/profile-creation/qa': (_) => const Text('Q&A'),
        '/profile-creation/phone': (_) => const Text('Phone step'),
        LegalRoutes.terms: (_) => const Text('Terms step'),
        LegalRoutes.sensitiveData: (_) => const Text('Sensitive data step'),
      },
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

  group('ProfileSubmissionScreen and the phone number (RFC-010)', () {
    testWidgets('sends the draft\'s number with the profile', (tester) async {
      final api = _LoggingApi(<String>[]);
      final repository = _FakeProfileRepository(api.log);

      await _pump(tester, _draft(phoneNumber: '+447400123456'), api, repository: repository);

      expect(repository.sent!.phoneNumber, '+447400123456');
      expect(repository.sent!.toJson()['phoneNumber'], '+447400123456');
      expect(find.text('Q&A'), findsOneWidget);
    });

    testWidgets('sends no phoneNumber key when the user skipped it', (tester) async {
      final api = _LoggingApi(<String>[]);
      final repository = _FakeProfileRepository(api.log);

      await _pump(tester, _draft(), api, repository: repository);

      expect(repository.sent!.toJson().containsKey('phoneNumber'), isFalse);
    });

    testWidgets('a 400 naming phoneNumber goes back to the phone step, flagged', (tester) async {
      final api = _LoggingApi(<String>[]);
      final repository = _FakeProfileRepository(
        api.log,
        error: ProfileValidationException('phoneNumber is not a valid phone number'),
      );

      await _pump(tester, _draft(phoneNumber: '+447400123456'), api, repository: repository);

      expect(find.text('Phone step'), findsOneWidget);
      expect(find.text('Oops! Something went wrong'), findsNothing);
      final container = ProviderScope.containerOf(tester.element(find.text('Phone step')));
      expect(container.read(phoneNumberRejectedProvider), isTrue);
    });

    testWidgets('another 400 shows the error as before', (tester) async {
      final api = _LoggingApi(<String>[]);
      final repository = _FakeProfileRepository(
        api.log,
        error: ProfileValidationException('Interests must be between 5 and 10 items'),
      );

      await _pump(tester, _draft(), api, repository: repository);

      expect(find.text('Oops! Something went wrong'), findsOneWidget);
      expect(find.text('Phone step'), findsNothing);
    });
  });

  group('ProfileSubmissionScreen and consents (RFC-009 CF-F1)', () {
    testWidgets('sends every consent kept at sign-up with its version, then forgets them',
        (tester) async {
      final api = _LoggingApi(<String>[]);
      final repository = _FakeProfileRepository(api.log);

      await _pump(tester, _draft(), api, repository: repository, consents: {
        'TERMS': 'uk-3',
        'PRIVACY_NOTICE': 'uk-2',
        'SAFETY_NOTICE': 'uk-1',
        'SENSITIVE_DATA': 'uk-4',
        'MARKETING': null,
      });

      expect(repository.sent!.toJson()['consents'], [
        {'kind': 'TERMS', 'version': 'uk-3'},
        {'kind': 'PRIVACY_NOTICE', 'version': 'uk-2'},
        {'kind': 'SAFETY_NOTICE', 'version': 'uk-1'},
        {'kind': 'SENSITIVE_DATA', 'version': 'uk-4'},
      ]);
      expect(find.text('Q&A'), findsOneWidget);
      final container = ProviderScope.containerOf(tester.element(find.text('Q&A')));
      expect(container.read(signupConsentsProvider).agreed, isEmpty);
    });

    testWidgets('a 400 for sensitive data goes back to that step, forgetting it',
        (tester) async {
      final api = _LoggingApi(<String>[]);
      final repository = _FakeProfileRepository(
        api.log,
        error: const ConsentRequiredException([DocumentKind.sensitiveData], statusCode: 400),
      );

      await _pump(tester, _draft(), api, repository: repository, consents: {
        'TERMS': 'uk-3',
        'SENSITIVE_DATA': 'uk-old',
      });

      expect(find.text('Sensitive data step'), findsOneWidget);
      final container = ProviderScope.containerOf(tester.element(find.text('Sensitive data step')));
      expect(container.read(consentsToReviewProvider), {DocumentKind.sensitiveData});
      expect(container.read(signupConsentsProvider).agreed, {DocumentKind.terms: 'uk-3'});
    });

    testWidgets('a 400 for the terms and sensitive data goes to the terms step first',
        (tester) async {
      final api = _LoggingApi(<String>[]);
      final repository = _FakeProfileRepository(
        api.log,
        error: const ConsentRequiredException(
          [DocumentKind.sensitiveData, DocumentKind.datingBillOfRights],
          statusCode: 400,
        ),
      );

      await _pump(tester, _draft(), api, repository: repository);

      expect(find.text('Terms step'), findsOneWidget);
      expect(find.text('Oops! Something went wrong'), findsNothing);
    });
  });
}
