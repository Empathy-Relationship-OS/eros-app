import 'package:eros_app/core/constants/languages.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/domain/enums/personality.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';

/// The signed-in user's own profile, as values (RFC-004 §6.1).
///
/// Mirrors the backend `UserDTO` from `GET /users/me` field for field. Unlike
/// `PublicProfileDTO`, it holds enum values and each field's show/hide flag, so the profile
/// editor can show and change them. The backend sends enums as display names, which the
/// `fromBackend` parsers read.
class MyProfile {
  final String userId;
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

  final String? occupation;
  final String bio;

  /// Interest display names, as `UpdateUserRequest.interests` takes them.
  final List<String> interests;
  final List<Trait> traits;

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
  final DisplayableField<String?> brainDescription;
  final DisplayableField<List<BodyAttribute>?> bodyAttributes;
  final DisplayableField<String?> bodyDescription;

  /// 50–100. Null when the backend predates PE-B1.
  final int? profileCompleteness;

  /// `UNVALIDATED`, `PENDING` or `VALIDATED`. Null when the backend predates PE-B1.
  final String? photoValidationStatus;

  const MyProfile({
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
    this.occupation,
    required this.bio,
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
    this.profileCompleteness,
    this.photoValidationStatus,
  });

  /// Whether the user's photo verification is complete.
  bool get isVerified => photoValidationStatus == 'VALIDATED';

  factory MyProfile.fromJson(Map<String, dynamic> json) {
    return MyProfile(
      userId: json['userId'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      heightCm: json['heightCm'] as int,
      dateOfBirth: DateTime.parse(json['dateOfBirth'] as String),
      city: json['city'] as String,
      educationLevel: EducationLevel.fromBackend(json['educationLevel'] as String),
      gender: Gender.fromBackend(json['gender'] as String),
      preferredLanguage: _language(json['preferredLanguage']),
      coordinatesLatitude: (json['coordinatesLatitude'] as num).toDouble(),
      coordinatesLongitude: (json['coordinatesLongitude'] as num).toDouble(),
      occupation: json['occupation'] as String?,
      bio: json['bio'] as String? ?? '',
      interests: _strings(json['interests']),
      traits: _strings(json['traits']).map(Trait.fromBackend).toList(),
      spokenLanguages: _field(json, 'spokenLanguages', (v) => _list(v, _language)),
      religion: _field(json, 'religion', (v) => _nullable(v, Religion.fromBackend)),
      politicalView: _field(json, 'politicalView', (v) => _nullable(v, PoliticalView.fromBackend)),
      alcoholConsumption:
          _field(json, 'alcoholConsumption', (v) => _nullable(v, AlcoholConsumption.fromBackend)),
      smokingStatus: _field(json, 'smokingStatus', (v) => _nullable(v, SmokingStatus.fromBackend)),
      diet: _field(json, 'diet', (v) => _nullable(v, Diet.fromBackend)),
      dateIntentions: _field(json, 'dateIntentions', (v) => DateIntentions.fromBackend(v as String)),
      relationshipType:
          _field(json, 'relationshipType', (v) => RelationshipType.fromBackend(v as String)),
      kidsPreference: _field(json, 'kidsPreference', (v) => KidsPreference.fromBackend(v as String)),
      sexualOrientation:
          _field(json, 'sexualOrientation', (v) => SexualOrientation.fromBackend(v as String)),
      pronouns: _field(json, 'pronouns', (v) => _nullable(v, Pronouns.fromBackend)),
      starSign: _field(json, 'starSign', (v) => _nullable(v, StarSign.fromBackend)),
      ethnicity: _field(json, 'ethnicity', (v) => _list(v, (e) => Ethnicity.fromBackend(e as String))),
      brainAttributes: _field(
        json,
        'brainAttributes',
        (v) => v == null ? null : _list(v, (e) => BrainAttribute.fromBackend(e as String)),
      ),
      brainDescription: _field(json, 'brainDescription', (v) => v as String?),
      bodyAttributes: _field(
        json,
        'bodyAttributes',
        (v) => v == null ? null : _list(v, (e) => BodyAttribute.fromBackend(e as String)),
      ),
      bodyDescription: _field(json, 'bodyDescription', (v) => v as String?),
      profileCompleteness: json['profileCompleteness'] as int?,
      photoValidationStatus: json['photoValidationStatus'] as String?,
    );
  }

  MyProfile copyWith({
    int? heightCm,
    String? city,
    EducationLevel? educationLevel,
    Language? preferredLanguage,
    double? coordinatesLatitude,
    double? coordinatesLongitude,
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
    int? profileCompleteness,
    String? photoValidationStatus,
  }) {
    // Name, email, date of birth and gender are locked after creation (RFC-004 D-6), so they
    // aren't parameters here.
    return MyProfile(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      email: email,
      heightCm: heightCm ?? this.heightCm,
      dateOfBirth: dateOfBirth,
      city: city ?? this.city,
      educationLevel: educationLevel ?? this.educationLevel,
      gender: gender,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      coordinatesLatitude: coordinatesLatitude ?? this.coordinatesLatitude,
      coordinatesLongitude: coordinatesLongitude ?? this.coordinatesLongitude,
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
      profileCompleteness: profileCompleteness ?? this.profileCompleteness,
      photoValidationStatus: photoValidationStatus ?? this.photoValidationStatus,
    );
  }

  static DisplayableField<T> _field<T>(
    Map<String, dynamic> json,
    String key,
    T Function(dynamic) parse,
  ) =>
      DisplayableField<T>.fromJson(json[key] as Map<String, dynamic>, parse);

  static T? _nullable<T>(dynamic value, T Function(String) parse) =>
      value == null ? null : parse(value as String);

  static List<T> _list<T>(dynamic value, T Function(dynamic) parse) =>
      (value as List<dynamic>).map(parse).toList();

  static List<String> _strings(dynamic value) =>
      (value as List<dynamic>).map((e) => e as String).toList();

  static Language _language(dynamic value) =>
      Languages.getByCode(LanguageCode.fromBackend(value as String).code);
}
