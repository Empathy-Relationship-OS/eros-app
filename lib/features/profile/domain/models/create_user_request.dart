import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/domain/enums/personality.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/core/constants/languages.dart';

/// Request model for creating a new user profile
/// Matches backend CreateUserRequest structure
class CreateUserRequest {
  // Required fields
  final String userId; // From Firebase JWT
  final String firstName;
  final String lastName;
  final String email;
  final int heightCm;
  final DateTime dateOfBirth;
  final String city;
  final EducationLevel educationLevel;
  final Gender gender;
  final Language preferredLanguage;
  final double coordinatesLatitude;
  final double coordinatesLongitude;

  // Required lists
  final List<String> interests; // 5-10 items
  final List<Trait> traits; // 3-10 items

  // Optional fields
  final String? occupation;
  final String bio; // max 300 chars

  // Displayable fields - client controls both value and visibility
  final DisplayableField<List<Language>> spokenLanguages;
  final DisplayableField<Religion?> religion;
  final DisplayableField<PoliticalView?> politicalView;
  final DisplayableField<AlcoholConsumption?> alcoholConsumption;
  final DisplayableField<SmokingStatus?> smokingStatus;
  final DisplayableField<Diet?> diet;
  final DisplayableField<DateIntentions> dateIntentions;
  final DisplayableField<RelationshipType> relationshipType;
  final DisplayableField<KidsPreference> kidsPreference;
  final DisplayableField<SexualOrientation> sexualOrientation;
  final DisplayableField<Pronouns?> pronouns;
  final DisplayableField<StarSign?> starSign;
  final DisplayableField<List<Ethnicity>> ethnicity;
  final DisplayableField<List<BrainAttribute>?> brainAttributes;
  final DisplayableField<String?> brainDescription; // max 200 chars
  final DisplayableField<List<BodyAttribute>?> bodyAttributes;
  final DisplayableField<String?> bodyDescription; // max 200 chars

  CreateUserRequest({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.heightCm,
    required this.dateOfBirth,
    required this.city,
    required this.educationLevel,
    required this.gender,
    required this.preferredLanguage,
    required this.coordinatesLatitude,
    required this.coordinatesLongitude,
    required this.interests,
    required this.traits,
    required this.spokenLanguages,
    required this.religion,
    required this.politicalView,
    required this.alcoholConsumption,
    required this.smokingStatus,
    required this.diet,
    required this.dateIntentions,
    required this.relationshipType,
    required this.kidsPreference,
    required this.sexualOrientation,
    required this.pronouns,
    required this.starSign,
    required this.ethnicity,
    required this.brainAttributes,
    required this.brainDescription,
    required this.bodyAttributes,
    required this.bodyDescription,
    this.occupation,
    this.bio = '',
  }) {
    _validate();
  }

  /// Validate the request
  void _validate() {
    if (coordinatesLatitude < -90.0 || coordinatesLatitude > 90.0) {
      throw ArgumentError('Latitude must be between -90 and 90');
    }
    if (coordinatesLongitude < -180.0 || coordinatesLongitude > 180.0) {
      throw ArgumentError('Longitude must be between -180 and 180');
    }
    if (interests.length < 5 || interests.length > 10) {
      throw ArgumentError('Interests must be between 5 and 10 items');
    }
    if (traits.length < 3 || traits.length > 10) {
      throw ArgumentError('Traits must be between 3 and 10 items');
    }
    if (bio.length > 300) {
      throw ArgumentError('Bio must not exceed 300 characters');
    }
    if (heightCm <= 0) {
      throw ArgumentError('Height must be positive');
    }
    if (firstName.trim().isEmpty) {
      throw ArgumentError('First name is required');
    }
    if (lastName.trim().isEmpty) {
      throw ArgumentError('Last name is required');
    }
    if (email.trim().isEmpty) {
      throw ArgumentError('Email is required');
    }
    if (city.trim().isEmpty) {
      throw ArgumentError('City is required');
    }
    if (brainDescription.field != null && brainDescription.field!.length > 200) {
      throw ArgumentError('Brain description must not exceed 200 characters');
    }
    if (bodyDescription.field != null && bodyDescription.field!.length > 200) {
      throw ArgumentError('Body description must not exceed 200 characters');
    }
  }

  /// Convert to JSON for backend
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'heightCm': heightCm,
      'dateOfBirth': dateOfBirth.toIso8601String().split('T')[0], // yyyy-MM-dd
      'city': city,
      'educationLevel': educationLevel.toBackend(),
      'gender': gender.toBackend(),
      'preferredLanguage': preferredLanguage.code,
      'coordinatesLatitude': coordinatesLatitude,
      'coordinatesLongitude': coordinatesLongitude,
      'interests': interests,
      'traits': traits.map((t) => t.toBackend()).toList(),
      if (occupation != null) 'occupation': occupation,
      'bio': bio,
      'spokenLanguages': spokenLanguages.toJson(
        (langs) => langs.map((l) => l.code).toList(),
      ),
      'religion': religion.toJson((r) => r?.toBackend()),
      'politicalView': politicalView.toJson((p) => p?.toBackend()),
      'alcoholConsumption': alcoholConsumption.toJson((a) => a?.toBackend()),
      'smokingStatus': smokingStatus.toJson((s) => s?.toBackend()),
      'diet': diet.toJson((d) => d?.toBackend()),
      'dateIntentions': dateIntentions.toJson((d) => d.toBackend()),
      'relationshipType': relationshipType.toJson((r) => r.toBackend()),
      'kidsPreference': kidsPreference.toJson((k) => k.toBackend()),
      'sexualOrientation': sexualOrientation.toJson((s) => s.toBackend()),
      'pronouns': pronouns.toJson((p) => p?.toBackend()),
      'starSign': starSign.toJson((s) => s?.toBackend()),
      'ethnicity': ethnicity.toJson(
        (list) => list.map((e) => e.toBackend()).toList(),
      ),
      'brainAttributes': brainAttributes.toJson(
        (list) => list?.map((b) => b.toBackend()).toList(),
      ),
      'brainDescription': brainDescription.toJson((d) => d),
      'bodyAttributes': bodyAttributes.toJson(
        (list) => list?.map((b) => b.toBackend()).toList(),
      ),
      'bodyDescription': bodyDescription.toJson((d) => d),
    };
  }

  /// Create a copy with updated fields
  CreateUserRequest copyWith({
    String? userId,
    String? firstName,
    String? lastName,
    String? email,
    int? heightCm,
    DateTime? dateOfBirth,
    String? city,
    EducationLevel? educationLevel,
    Gender? gender,
    Language? preferredLanguage,
    double? coordinatesLatitude,
    double? coordinatesLongitude,
    List<String>? interests,
    List<Trait>? traits,
    String? occupation,
    String? bio,
    DisplayableField<List<Language>>? spokenLanguages,
    DisplayableField<Religion?>? religion,
    DisplayableField<PoliticalView?>? politicalView,
    DisplayableField<AlcoholConsumption?>? alcoholConsumption,
    DisplayableField<SmokingStatus?>? smokingStatus,
    DisplayableField<Diet?>? diet,
    DisplayableField<DateIntentions>? dateIntentions,
    DisplayableField<RelationshipType>? relationshipType,
    DisplayableField<KidsPreference>? kidsPreference,
    DisplayableField<SexualOrientation>? sexualOrientation,
    DisplayableField<Pronouns?>? pronouns,
    DisplayableField<StarSign?>? starSign,
    DisplayableField<List<Ethnicity>>? ethnicity,
    DisplayableField<List<BrainAttribute>?>? brainAttributes,
    DisplayableField<String?>? brainDescription,
    DisplayableField<List<BodyAttribute>?>? bodyAttributes,
    DisplayableField<String?>? bodyDescription,
  }) {
    return CreateUserRequest(
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      heightCm: heightCm ?? this.heightCm,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      city: city ?? this.city,
      educationLevel: educationLevel ?? this.educationLevel,
      gender: gender ?? this.gender,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      coordinatesLatitude: coordinatesLatitude ?? this.coordinatesLatitude,
      coordinatesLongitude: coordinatesLongitude ?? this.coordinatesLongitude,
      interests: interests ?? this.interests,
      traits: traits ?? this.traits,
      occupation: occupation ?? this.occupation,
      bio: bio ?? this.bio,
      spokenLanguages: spokenLanguages ?? this.spokenLanguages,
      religion: religion ?? this.religion,
      politicalView: politicalView ?? this.politicalView,
      alcoholConsumption: alcoholConsumption ?? this.alcoholConsumption,
      smokingStatus: smokingStatus ?? this.smokingStatus,
      diet: diet ?? this.diet,
      dateIntentions: dateIntentions ?? this.dateIntentions,
      relationshipType: relationshipType ?? this.relationshipType,
      kidsPreference: kidsPreference ?? this.kidsPreference,
      sexualOrientation: sexualOrientation ?? this.sexualOrientation,
      pronouns: pronouns ?? this.pronouns,
      starSign: starSign ?? this.starSign,
      ethnicity: ethnicity ?? this.ethnicity,
      brainAttributes: brainAttributes ?? this.brainAttributes,
      brainDescription: brainDescription ?? this.brainDescription,
      bodyAttributes: bodyAttributes ?? this.bodyAttributes,
      bodyDescription: bodyDescription ?? this.bodyDescription,
    );
  }
}
