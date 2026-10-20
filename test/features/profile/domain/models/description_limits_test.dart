import 'package:eros_app/core/constants/languages.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/domain/enums/personality.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/create_user_request.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/domain/models/profile_field_limits.dart';
import 'package:eros_app/features/profile/domain/models/update_user_request.dart';
import 'package:flutter_test/flutter_test.dart';

CreateUserRequest _createRequest({String? brainDescription, String? bodyDescription}) {
  final english = Languages.all.first;
  return CreateUserRequest(
    userId: 'u1',
    firstName: 'Alice',
    lastName: 'Smith',
    email: 'alice@example.com',
    heightCm: 170,
    dateOfBirth: DateTime(1995, 1, 1),
    city: 'London',
    educationLevel: EducationLevel.university,
    gender: Gender.female,
    preferredLanguage: english,
    coordinatesLatitude: 51.5,
    coordinatesLongitude: -0.12,
    interests: const ['HIKING', 'NATURE', 'MOVIES', 'PHOTOGRAPHY', 'YOGA'],
    traits: Trait.values.take(3).toList(),
    occupation: null,
    bio: '',
    spokenLanguages: DisplayableField(field: [english], visible: true),
    religion: DisplayableField(field: null, visible: false),
    politicalView: DisplayableField(field: null, visible: false),
    alcoholConsumption: DisplayableField(field: null, visible: false),
    smokingStatus: DisplayableField(field: null, visible: false),
    diet: DisplayableField(field: null, visible: false),
    dateIntentions: DisplayableField(field: DateIntentions.seriousDating, visible: true),
    relationshipType: DisplayableField(field: RelationshipType.monogamous, visible: true),
    kidsPreference: DisplayableField(field: KidsPreference.openToKids, visible: true),
    sexualOrientation: DisplayableField(field: SexualOrientation.straight, visible: true),
    pronouns: DisplayableField(field: null, visible: false),
    starSign: DisplayableField(field: null, visible: false),
    ethnicity: DisplayableField(field: [Ethnicity.eastAsian], visible: false),
    brainAttributes: DisplayableField(field: null, visible: false),
    brainDescription: DisplayableField(field: brainDescription, visible: false),
    bodyAttributes: DisplayableField(field: null, visible: false),
    bodyDescription: DisplayableField(field: bodyDescription, visible: false),
  );
}

void main() {
  final atLimit = 'a' * ProfileFieldLimits.maxDescriptionLength;
  final overLimit = 'a' * (ProfileFieldLimits.maxDescriptionLength + 1);

  test('the limit matches the backend database (RFC-004 D-11)', () {
    expect(ProfileFieldLimits.maxDescriptionLength, 100);
  });

  group('CreateUserRequest', () {
    test('accepts 100-character descriptions', () {
      expect(() => _createRequest(brainDescription: atLimit, bodyDescription: atLimit), returnsNormally);
    });

    test('rejects a 101-character brain description', () {
      expect(() => _createRequest(brainDescription: overLimit), throwsArgumentError);
    });

    test('rejects a 101-character body description', () {
      expect(() => _createRequest(bodyDescription: overLimit), throwsArgumentError);
    });
  });

  group('UpdateUserRequest', () {
    test('accepts 100-character descriptions', () {
      expect(
        () => UpdateUserRequest(
          brainDescription: DisplayableField(field: atLimit, visible: true),
          bodyDescription: DisplayableField(field: atLimit, visible: true),
        ),
        returnsNormally,
      );
    });

    test('rejects 101-character descriptions', () {
      expect(
        () => UpdateUserRequest(brainDescription: DisplayableField(field: overLimit, visible: true)),
        throwsArgumentError,
      );
      expect(
        () => UpdateUserRequest(bodyDescription: DisplayableField(field: overLimit, visible: true)),
        throwsArgumentError,
      );
    });
  });
}
