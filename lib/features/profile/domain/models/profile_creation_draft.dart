import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/domain/enums/personality.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/domain/models/create_user_request.dart';
import 'package:eros_app/core/constants/languages.dart';

/// Draft model for profile creation with all optional fields
/// Allows progressive filling during the multi-step flow
class ProfileCreationDraft {
  // Basic info
  String? firstName;
  String? lastName;
  String? email;
  String? phoneNumber; // For future backend integration
  int? heightCm;
  DateTime? dateOfBirth;
  String? city;
  double? coordinatesLatitude;
  double? coordinatesLongitude;
  EducationLevel? educationLevel;
  Gender? gender;
  Language? preferredLanguage;

  // Optional profile fields
  String? occupation;
  String? bio;

  // Interests and traits
  List<String>? interests;
  List<Trait>? traits;

  // Preferences (as nullable displayable fields)
  DisplayableField<List<Language>>? spokenLanguages;
  DisplayableField<Religion?>? religion;
  DisplayableField<PoliticalView?>? politicalView;
  DisplayableField<AlcoholConsumption?>? alcoholConsumption;
  DisplayableField<SmokingStatus?>? smokingStatus;
  DisplayableField<Diet?>? diet;
  DisplayableField<DateIntentions>? dateIntentions;
  DisplayableField<RelationshipType>? relationshipType;
  DisplayableField<KidsPreference>? kidsPreference;
  DisplayableField<SexualOrientation>? sexualOrientation;
  DisplayableField<Pronouns?>? pronouns;
  DisplayableField<StarSign?>? starSign;
  DisplayableField<List<Ethnicity>>? ethnicity;
  DisplayableField<List<BrainAttribute>?>? brainAttributes;
  DisplayableField<String?>? brainDescription;
  DisplayableField<List<BodyAttribute>?>? bodyAttributes;
  DisplayableField<String?>? bodyDescription;

  ProfileCreationDraft({
    this.firstName,
    this.lastName,
    this.email,
    this.phoneNumber,
    this.heightCm,
    this.dateOfBirth,
    this.city,
    this.coordinatesLatitude,
    this.coordinatesLongitude,
    this.educationLevel,
    this.gender,
    this.preferredLanguage,
    this.occupation,
    this.bio,
    this.interests,
    this.traits,
    this.spokenLanguages,
    this.religion,
    this.politicalView,
    this.alcoholConsumption,
    this.smokingStatus,
    this.diet,
    this.dateIntentions,
    this.relationshipType,
    this.kidsPreference,
    this.sexualOrientation,
    this.pronouns,
    this.starSign,
    this.ethnicity,
    this.brainAttributes,
    this.brainDescription,
    this.bodyAttributes,
    this.bodyDescription,
  });

  /// Check if all required fields are filled
  bool get isComplete {
    return firstName != null &&
        lastName != null &&
        email != null &&
        heightCm != null &&
        dateOfBirth != null &&
        city != null &&
        coordinatesLatitude != null &&
        coordinatesLongitude != null &&
        educationLevel != null &&
        gender != null &&
        preferredLanguage != null &&
        interests != null &&
        interests!.length >= 5 &&
        interests!.length <= 10 &&
        traits != null &&
        traits!.length >= 3 &&
        traits!.length <= 10 &&
        spokenLanguages != null &&
        religion != null &&
        politicalView != null &&
        alcoholConsumption != null &&
        smokingStatus != null &&
        diet != null &&
        dateIntentions != null &&
        relationshipType != null &&
        kidsPreference != null &&
        sexualOrientation != null &&
        pronouns != null &&
        starSign != null &&
        ethnicity != null &&
        brainAttributes != null &&
        brainDescription != null &&
        bodyAttributes != null &&
        bodyDescription != null;
  }

  /// Convert to CreateUserRequest (throws if incomplete)
  CreateUserRequest toCreateUserRequest(String userId) {
    if (!isComplete) {
      throw StateError('Profile draft is not complete');
    }

    return CreateUserRequest(
      userId: userId,
      firstName: firstName!,
      lastName: lastName!,
      email: email!,
      heightCm: heightCm!,
      dateOfBirth: dateOfBirth!,
      city: city!,
      educationLevel: educationLevel!,
      gender: gender!,
      preferredLanguage: preferredLanguage!,
      coordinatesLatitude: coordinatesLatitude!,
      coordinatesLongitude: coordinatesLongitude!,
      interests: interests!,
      traits: traits!,
      occupation: occupation,
      bio: bio ?? '',
      spokenLanguages: spokenLanguages!,
      religion: religion!,
      politicalView: politicalView!,
      alcoholConsumption: alcoholConsumption!,
      smokingStatus: smokingStatus!,
      diet: diet!,
      dateIntentions: dateIntentions!,
      relationshipType: relationshipType!,
      kidsPreference: kidsPreference!,
      sexualOrientation: sexualOrientation!,
      pronouns: pronouns!,
      starSign: starSign!,
      ethnicity: ethnicity!,
      brainAttributes: brainAttributes!,
      brainDescription: brainDescription!,
      bodyAttributes: bodyAttributes!,
      bodyDescription: bodyDescription!,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (email != null) 'email': email,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (heightCm != null) 'heightCm': heightCm,
      if (dateOfBirth != null)
        'dateOfBirth': dateOfBirth!.toIso8601String(),
      if (city != null) 'city': city,
      if (coordinatesLatitude != null)
        'coordinatesLatitude': coordinatesLatitude,
      if (coordinatesLongitude != null)
        'coordinatesLongitude': coordinatesLongitude,
      if (educationLevel != null)
        'educationLevel': educationLevel!.toBackend(),
      if (gender != null) 'gender': gender!.toBackend(),
      if (preferredLanguage != null)
        'preferredLanguage': preferredLanguage!.code,
      if (occupation != null) 'occupation': occupation,
      if (bio != null) 'bio': bio,
      if (interests != null) 'interests': interests,
      if (traits != null) 'traits': traits!.map((t) => t.toBackend()).toList(),
      // Displayable fields stored as JSON
      if (spokenLanguages != null)
        'spokenLanguages': spokenLanguages!.toJson(
          (langs) => langs.map((l) => l.code).toList(),
        ),
      if (religion != null)
        'religion': religion!.toJson((r) => r?.toBackend()),
      if (politicalView != null)
        'politicalView': politicalView!.toJson((p) => p?.toBackend()),
      if (alcoholConsumption != null)
        'alcoholConsumption':
            alcoholConsumption!.toJson((a) => a?.toBackend()),
      if (smokingStatus != null)
        'smokingStatus': smokingStatus!.toJson((s) => s?.toBackend()),
      if (diet != null) 'diet': diet!.toJson((d) => d?.toBackend()),
      if (dateIntentions != null)
        'dateIntentions': dateIntentions!.toJson((d) => d.toBackend()),
      if (relationshipType != null)
        'relationshipType': relationshipType!.toJson((r) => r.toBackend()),
      if (kidsPreference != null)
        'kidsPreference': kidsPreference!.toJson((k) => k.toBackend()),
      if (sexualOrientation != null)
        'sexualOrientation': sexualOrientation!.toJson((s) => s.toBackend()),
      if (pronouns != null)
        'pronouns': pronouns!.toJson((p) => p?.toBackend()),
      if (starSign != null)
        'starSign': starSign!.toJson((s) => s?.toBackend()),
      if (ethnicity != null)
        'ethnicity': ethnicity!.toJson(
          (list) => list.map((e) => e.toBackend()).toList(),
        ),
      if (brainAttributes != null)
        'brainAttributes': brainAttributes!.toJson(
          (list) => list?.map((b) => b.toBackend()).toList(),
        ),
      if (brainDescription != null)
        'brainDescription': brainDescription!.toJson((d) => d),
      if (bodyAttributes != null)
        'bodyAttributes': bodyAttributes!.toJson(
          (list) => list?.map((b) => b.toBackend()).toList(),
        ),
      if (bodyDescription != null)
        'bodyDescription': bodyDescription!.toJson((d) => d),
    };
  }

  /// Create from JSON
  factory ProfileCreationDraft.fromJson(Map<String, dynamic> json) {
    return ProfileCreationDraft(
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      heightCm: json['heightCm'] as int?,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
      city: json['city'] as String?,
      coordinatesLatitude: json['coordinatesLatitude'] as double?,
      coordinatesLongitude: json['coordinatesLongitude'] as double?,
      educationLevel: json['educationLevel'] != null
          ? EducationLevel.fromBackend(json['educationLevel'] as String)
          : null,
      gender: json['gender'] != null
          ? Gender.fromBackend(json['gender'] as String)
          : null,
      preferredLanguage: json['preferredLanguage'] != null
          ? Language.fromCode(json['preferredLanguage'] as String)
          : null,
      occupation: json['occupation'] as String?,
      bio: json['bio'] as String?,
      interests: json['interests'] != null
          ? List<String>.from(json['interests'] as List)
          : null,
      traits: json['traits'] != null
          ? (json['traits'] as List)
              .map((t) => Trait.fromBackend(t as String))
              .toList()
          : null,
      // Parse displayable fields
      spokenLanguages: json['spokenLanguages'] != null
          ? DisplayableField.fromJson(
              json['spokenLanguages'] as Map<String, dynamic>,
              (field) => (field as List)
                  .map((c) => Language.fromCode(c as String))
                  .toList(),
            )
          : null,
      religion: json['religion'] != null
          ? DisplayableField.fromJson(
              json['religion'] as Map<String, dynamic>,
              (field) =>
                  field != null ? Religion.fromBackend(field as String) : null,
            )
          : null,
      politicalView: json['politicalView'] != null
          ? DisplayableField.fromJson(
              json['politicalView'] as Map<String, dynamic>,
              (field) => field != null
                  ? PoliticalView.fromBackend(field as String)
                  : null,
            )
          : null,
      alcoholConsumption: json['alcoholConsumption'] != null
          ? DisplayableField.fromJson(
              json['alcoholConsumption'] as Map<String, dynamic>,
              (field) => field != null
                  ? AlcoholConsumption.fromBackend(field as String)
                  : null,
            )
          : null,
      smokingStatus: json['smokingStatus'] != null
          ? DisplayableField.fromJson(
              json['smokingStatus'] as Map<String, dynamic>,
              (field) => field != null
                  ? SmokingStatus.fromBackend(field as String)
                  : null,
            )
          : null,
      diet: json['diet'] != null
          ? DisplayableField.fromJson(
              json['diet'] as Map<String, dynamic>,
              (field) => field != null ? Diet.fromBackend(field as String) : null,
            )
          : null,
      dateIntentions: json['dateIntentions'] != null
          ? DisplayableField.fromJson(
              json['dateIntentions'] as Map<String, dynamic>,
              (field) => DateIntentions.fromBackend(field as String),
            )
          : null,
      relationshipType: json['relationshipType'] != null
          ? DisplayableField.fromJson(
              json['relationshipType'] as Map<String, dynamic>,
              (field) => RelationshipType.fromBackend(field as String),
            )
          : null,
      kidsPreference: json['kidsPreference'] != null
          ? DisplayableField.fromJson(
              json['kidsPreference'] as Map<String, dynamic>,
              (field) => KidsPreference.fromBackend(field as String),
            )
          : null,
      sexualOrientation: json['sexualOrientation'] != null
          ? DisplayableField.fromJson(
              json['sexualOrientation'] as Map<String, dynamic>,
              (field) => SexualOrientation.fromBackend(field as String),
            )
          : null,
      pronouns: json['pronouns'] != null
          ? DisplayableField.fromJson(
              json['pronouns'] as Map<String, dynamic>,
              (field) =>
                  field != null ? Pronouns.fromBackend(field as String) : null,
            )
          : null,
      starSign: json['starSign'] != null
          ? DisplayableField.fromJson(
              json['starSign'] as Map<String, dynamic>,
              (field) =>
                  field != null ? StarSign.fromBackend(field as String) : null,
            )
          : null,
      ethnicity: json['ethnicity'] != null
          ? DisplayableField.fromJson(
              json['ethnicity'] as Map<String, dynamic>,
              (field) => (field as List)
                  .map((e) => Ethnicity.fromBackend(e as String))
                  .toList(),
            )
          : null,
      brainAttributes: json['brainAttributes'] != null
          ? DisplayableField.fromJson(
              json['brainAttributes'] as Map<String, dynamic>,
              (field) => field != null
                  ? (field as List)
                      .map((b) => BrainAttribute.fromBackend(b as String))
                      .toList()
                  : null,
            )
          : null,
      brainDescription: json['brainDescription'] != null
          ? DisplayableField.fromJson(
              json['brainDescription'] as Map<String, dynamic>,
              (field) => field as String?,
            )
          : null,
      bodyAttributes: json['bodyAttributes'] != null
          ? DisplayableField.fromJson(
              json['bodyAttributes'] as Map<String, dynamic>,
              (field) => field != null
                  ? (field as List)
                      .map((b) => BodyAttribute.fromBackend(b as String))
                      .toList()
                  : null,
            )
          : null,
      bodyDescription: json['bodyDescription'] != null
          ? DisplayableField.fromJson(
              json['bodyDescription'] as Map<String, dynamic>,
              (field) => field as String?,
            )
          : null,
    );
  }

  /// Create a copy with updated fields
  ProfileCreationDraft copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    int? heightCm,
    DateTime? dateOfBirth,
    String? city,
    double? coordinatesLatitude,
    double? coordinatesLongitude,
    EducationLevel? educationLevel,
    Gender? gender,
    Language? preferredLanguage,
    String? occupation,
    String? bio,
    List<String>? interests,
    List<Trait>? traits,
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
    return ProfileCreationDraft(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      heightCm: heightCm ?? this.heightCm,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      city: city ?? this.city,
      coordinatesLatitude: coordinatesLatitude ?? this.coordinatesLatitude,
      coordinatesLongitude: coordinatesLongitude ?? this.coordinatesLongitude,
      educationLevel: educationLevel ?? this.educationLevel,
      gender: gender ?? this.gender,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      occupation: occupation ?? this.occupation,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      traits: traits ?? this.traits,
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
