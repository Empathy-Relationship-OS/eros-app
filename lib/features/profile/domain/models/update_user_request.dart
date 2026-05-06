import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/domain/enums/personality.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/core/constants/languages.dart';

/// Request model for updating an existing user profile
/// All fields are optional — only non-null fields are applied to the existing profile
/// Matches backend UpdateUserRequest structure
class UpdateUserRequest {
  // Optional basic fields
  final String? firstName;
  final String? lastName;
  final String? email;
  final int? heightCm;
  final String? city;
  final EducationLevel? educationLevel;
  final String? occupation;
  final String? bio;
  final Language? preferredLanguage;
  final double? coordinatesLatitude;
  final double? coordinatesLongitude;

  // Optional lists
  final List<String>? interests;
  final List<Trait>? traits;

  // Optional displayable fields
  final DisplayableField<List<Language>>? spokenLanguages;
  final DisplayableField<Religion?>? religion;
  final DisplayableField<PoliticalView?>? politicalView;
  final DisplayableField<AlcoholConsumption?>? alcoholConsumption;
  final DisplayableField<SmokingStatus?>? smokingStatus;
  final DisplayableField<Diet?>? diet;
  final DisplayableField<DateIntentions>? dateIntentions;
  final DisplayableField<RelationshipType>? relationshipType;
  final DisplayableField<KidsPreference>? kidsPreference;
  final DisplayableField<SexualOrientation>? sexualOrientation;
  final DisplayableField<Pronouns?>? pronouns;
  final DisplayableField<StarSign?>? starSign;
  final DisplayableField<List<Ethnicity>>? ethnicity;
  final DisplayableField<List<BrainAttribute>?>? brainAttributes;
  final DisplayableField<String?>? brainDescription;
  final DisplayableField<List<BodyAttribute>?>? bodyAttributes;
  final DisplayableField<String?>? bodyDescription;

  // Profile visibility
  final bool? setVisible;

  UpdateUserRequest({
    this.firstName,
    this.lastName,
    this.email,
    this.heightCm,
    this.city,
    this.educationLevel,
    this.occupation,
    this.bio,
    this.preferredLanguage,
    this.coordinatesLatitude,
    this.coordinatesLongitude,
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
    this.setVisible,
  }) {
    _validate();
  }

  /// Validate provided fields (only validates non-null values)
  void _validate() {
    if (coordinatesLatitude != null &&
        (coordinatesLatitude! < -90.0 || coordinatesLatitude! > 90.0)) {
      throw ArgumentError('Latitude must be between -90 and 90');
    }
    if (coordinatesLongitude != null &&
        (coordinatesLongitude! < -180.0 || coordinatesLongitude! > 180.0)) {
      throw ArgumentError('Longitude must be between -180 and 180');
    }
    if (interests != null &&
        (interests!.length < 5 || interests!.length > 10)) {
      throw ArgumentError('Interests must be between 5 and 10 items');
    }
    if (traits != null && (traits!.length < 3 || traits!.length > 10)) {
      throw ArgumentError('Traits must be between 3 and 10 items');
    }
    if (bio != null && bio!.length > 300) {
      throw ArgumentError('Bio must not exceed 300 characters');
    }
    if (heightCm != null && heightCm! <= 0) {
      throw ArgumentError('Height must be positive');
    }
    if (firstName != null && firstName!.trim().isEmpty) {
      throw ArgumentError('First name cannot be empty');
    }
    if (lastName != null && lastName!.trim().isEmpty) {
      throw ArgumentError('Last name cannot be empty');
    }
    if (email != null && email!.trim().isEmpty) {
      throw ArgumentError('Email cannot be empty');
    }
    if (city != null && city!.trim().isEmpty) {
      throw ArgumentError('City cannot be empty');
    }
    if (brainDescription?.field != null &&
        brainDescription!.field!.length > 100) {
      throw ArgumentError('Brain description must not exceed 100 characters');
    }
    if (bodyDescription?.field != null &&
        bodyDescription!.field!.length > 100) {
      throw ArgumentError('Body description must not exceed 100 characters');
    }
    if (ethnicity?.field != null && ethnicity!.field.isEmpty) {
      throw ArgumentError('Ethnicity must not be empty if provided');
    }
  }

  /// Convert to JSON for backend (only includes non-null fields)
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};

    if (firstName != null) json['firstName'] = firstName;
    if (lastName != null) json['lastName'] = lastName;
    if (email != null) json['email'] = email;
    if (heightCm != null) json['heightCm'] = heightCm;
    if (city != null) json['city'] = city;
    if (educationLevel != null) {
      json['educationLevel'] = educationLevel!.toBackend();
    }
    if (occupation != null) json['occupation'] = occupation;
    if (bio != null) json['bio'] = bio;
    if (preferredLanguage != null) {
      json['preferredLanguage'] = preferredLanguage!.toEnum().toBackend();
    }
    if (coordinatesLatitude != null) {
      json['coordinatesLatitude'] = coordinatesLatitude;
    }
    if (coordinatesLongitude != null) {
      json['coordinatesLongitude'] = coordinatesLongitude;
    }
    if (interests != null) json['interests'] = interests;
    if (traits != null) {
      json['traits'] = traits!.map((t) => t.toBackend()).toList();
    }

    // Displayable fields
    if (spokenLanguages != null) {
      json['spokenLanguages'] = spokenLanguages!.toJson(
        (langs) => langs.map((l) => l.toEnum().toBackend()).toList(),
      );
    }
    if (religion != null) {
      json['religion'] = religion!.toJson((r) => r?.toBackend());
    }
    if (politicalView != null) {
      json['politicalView'] = politicalView!.toJson((p) => p?.toBackend());
    }
    if (alcoholConsumption != null) {
      json['alcoholConsumption'] =
          alcoholConsumption!.toJson((a) => a?.toBackend());
    }
    if (smokingStatus != null) {
      json['smokingStatus'] = smokingStatus!.toJson((s) => s?.toBackend());
    }
    if (diet != null) {
      json['diet'] = diet!.toJson((d) => d?.toBackend());
    }
    if (dateIntentions != null) {
      json['dateIntentions'] = dateIntentions!.toJson((d) => d.toBackend());
    }
    if (relationshipType != null) {
      json['relationshipType'] = relationshipType!.toJson((r) => r.toBackend());
    }
    if (kidsPreference != null) {
      json['kidsPreference'] = kidsPreference!.toJson((k) => k.toBackend());
    }
    if (sexualOrientation != null) {
      json['sexualOrientation'] =
          sexualOrientation!.toJson((s) => s.toBackend());
    }
    if (pronouns != null) {
      json['pronouns'] = pronouns!.toJson((p) => p?.toBackend());
    }
    if (starSign != null) {
      json['starSign'] = starSign!.toJson((s) => s?.toBackend());
    }
    if (ethnicity != null) {
      json['ethnicity'] = ethnicity!.toJson(
        (list) => list.map((e) => e.toBackend()).toList(),
      );
    }
    if (brainAttributes != null) {
      json['brainAttributes'] = brainAttributes!.toJson(
        (list) => list?.map((b) => b.toBackend()).toList(),
      );
    }
    if (brainDescription != null) {
      json['brainDescription'] = brainDescription!.toJson((d) => d);
    }
    if (bodyAttributes != null) {
      json['bodyAttributes'] = bodyAttributes!.toJson(
        (list) => list?.map((b) => b.toBackend()).toList(),
      );
    }
    if (bodyDescription != null) {
      json['bodyDescription'] = bodyDescription!.toJson((d) => d);
    }

    if (setVisible != null) json['setVisible'] = setVisible;

    return json;
  }
}
