import 'dart:convert';
import 'dart:io';

import 'package:eros_app/core/constants/languages.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_repository.dart';
import 'package:eros_app/features/date_preferences/domain/models/section_patch.dart';
import 'package:eros_app/features/legal/domain/consent_required.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';
import 'package:eros_app/features/legal/domain/models/signup_consent.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/domain/enums/personality.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/create_user_request.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/domain/models/my_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../verification/fake_verification_http.dart';

CreateUserRequest _request({List<SignupConsent> consents = const []}) => CreateUserRequest(
      userId: 'user1',
      firstName: 'Alex',
      lastName: 'Smith',
      email: 'alex@example.com',
      heightCm: 175,
      dateOfBirth: DateTime(1995, 5, 1),
      city: 'London',
      educationLevel: EducationLevel.university,
      gender: Gender.female,
      preferredLanguage: Languages.all.first,
      coordinatesLatitude: 51.5,
      coordinatesLongitude: -0.1,
      interests: const ['HIKING', 'COFFEE', 'JAZZ', 'GOLF', 'READING'],
      traits: const [Trait.adventurous, Trait.ambitious, Trait.creative],
      spokenLanguages: DisplayableField(field: [Languages.all.first]),
      religion: DisplayableField(field: null, visible: false),
      alcoholConsumption: DisplayableField(field: null, visible: false),
      smokingStatus: DisplayableField(field: null, visible: false),
      diet: DisplayableField(field: null, visible: false),
      dateIntentions: DisplayableField(field: DateIntentions.notSure, visible: false),
      relationshipType: DisplayableField(field: RelationshipType.monogamous, visible: false),
      kidsPreference: DisplayableField(field: KidsPreference.preferNotToSay, visible: false),
      sexualOrientation:
          DisplayableField(field: SexualOrientation.preferNotToSay, visible: false),
      pronouns: DisplayableField(field: null, visible: false),
      starSign: DisplayableField(field: null, visible: false),
      ethnicity: DisplayableField(field: [], visible: false),
      brainAttributes: DisplayableField(field: null, visible: false),
      brainDescription: DisplayableField(field: null, visible: false),
      bodyAttributes: DisplayableField(field: null, visible: false),
      bodyDescription: DisplayableField(field: null, visible: false),
      consents: consents,
    );

void main() {
  group('POST /users', () {
    test('carries each consent with the version shown', () {
      final json = _request(consents: const [
        SignupConsent(kind: DocumentKind.terms, version: 'uk-3'),
        SignupConsent(kind: DocumentKind.sensitiveData, version: 'uk-4'),
      ]).toJson();

      expect(json['consents'], [
        {'kind': 'TERMS', 'version': 'uk-3'},
        {'kind': 'SENSITIVE_DATA', 'version': 'uk-4'},
      ]);
    });

    test('leaves consents out when there are none', () {
      expect(_request().toJson().containsKey('consents'), isFalse);
    });

    test('a 400 CONSENT_REQUIRED names what is missing', () async {
      final http = StubHttp()
        ..responses['POST /users'] = reply(400, {
          'error': 'CONSENT_REQUIRED',
          'message': 'Accept SENSITIVE_DATA to continue',
          'missing': ['SENSITIVE_DATA', 'SOMETHING_NEW'],
        });
      final repository = ProfileRepository(
        apiClient: apiClientOver(http),
        authService: FakeAuthService(),
        logger: Logger(level: Level.off),
      );

      await expectLater(
        repository.createUser(_request()),
        throwsA(isA<ConsentRequiredException>()
            .having((e) => e.missing, 'missing', [DocumentKind.sensitiveData])
            .having((e) => e.statusCode, 'statusCode', 400)),
      );
    });

    test('another 400 stays a validation error', () async {
      final http = StubHttp()
        ..responses['POST /users'] = reply(400, {'error': 'bad_request', 'message': 'No'});
      final repository = ProfileRepository(
        apiClient: apiClientOver(http),
        authService: FakeAuthService(),
        logger: Logger(level: Level.off),
      );

      await expectLater(
        repository.createUser(_request()),
        throwsA(isA<ProfileValidationException>()),
      );
    });
  });

  test('a 403 CONSENT_REQUIRED from saving a pin names LOCATION_PIN', () async {
    final http = StubHttp()
      ..responses['PATCH /users/me/date-preferences'] = reply(403, {
        'error': 'CONSENT_REQUIRED',
        'message': 'Allow us to store your starting point to place a pin',
        'missing': ['LOCATION_PIN'],
      });
    final repository = DatePreferencesRepository(apiClient: apiClientOver(http));

    await expectLater(
      repository.patch(const WherePatch(cities: [], maxTravelMeters: 5000)),
      throwsA(isA<ConsentRequiredException>()
          .having((e) => e.missing, 'missing', [DocumentKind.locationPin])
          .having((e) => e.statusCode, 'statusCode', 403)),
    );
  });

  test('GET /users/me reads outstandingConsents, empty when the backend predates it', () {
    final json = jsonDecode(File('test/fixtures/users/get_users_me.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(MyProfile.fromJson(json).outstandingConsents, isEmpty);

    json['outstandingConsents'] = ['TERMS', 'SENSITIVE_DATA'];
    expect(MyProfile.fromJson(json).outstandingConsents, ['TERMS', 'SENSITIVE_DATA']);
  });
}
