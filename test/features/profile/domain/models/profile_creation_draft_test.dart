import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/domain/models/profile_creation_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileCreationDraft gender', () {
    test('reads a draft saved before the Non-Binary fix', () {
      final draft = ProfileCreationDraft.fromJson({'gender': 'Non-binary'});

      expect(draft.gender, Gender.nonBinary);
    });

    test('saves the current wire value and reads it back', () {
      final json = ProfileCreationDraft(gender: Gender.nonBinary).toJson();

      expect(json['gender'], 'Non-Binary');
      expect(ProfileCreationDraft.fromJson(json).gender, Gender.nonBinary);
    });
  });

  group('ProfileCreationDraft dating cities', () {
    test('keeps the chosen city ids, in order, through storage', () {
      final json = ProfileCreationDraft(datingCityIds: [2, 1]).toJson();

      expect(json['datingCityIds'], [2, 1]);
      expect(ProfileCreationDraft.fromJson(json).datingCityIds, [2, 1]);
    });

    test('a draft saved before dating cities were kept has none', () {
      expect(ProfileCreationDraft.fromJson({}).datingCityIds, isNull);
    });
  });

  test('Gender.fromBackend stays exact for server values', () {
    expect(() => Gender.fromBackend('Non-binary'), throwsArgumentError);
  });
}
