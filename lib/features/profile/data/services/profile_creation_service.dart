import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eros_app/features/profile/domain/models/profile_creation_draft.dart';

/// Service for managing profile creation state with SharedPreferences persistence
/// Allows users to resume profile creation even after closing the app
class ProfileCreationService {
  static const String _draftKey = 'profile_creation_draft';

  final SharedPreferences _prefs;

  ProfileCreationService(this._prefs);

  /// Save the current draft to persistent storage
  Future<void> saveDraft(ProfileCreationDraft draft) async {
    try {
      final json = draft.toJson();
      final jsonString = jsonEncode(json);
      await _prefs.setString(_draftKey, jsonString);
    } catch (e) {
      throw ProfileCreationException(
        'Failed to save profile draft: $e',
      );
    }
  }

  /// Load the draft from persistent storage
  /// Returns null if no draft exists
  ProfileCreationDraft? loadDraft() {
    try {
      final jsonString = _prefs.getString(_draftKey);
      if (jsonString == null) {
        return null;
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ProfileCreationDraft.fromJson(json);
    } catch (e) {
      // If there's an error loading, clear the corrupted draft
      clearDraft();
      return null;
    }
  }

  /// Check if a draft exists
  bool hasDraft() {
    return _prefs.containsKey(_draftKey);
  }

  /// Clear the draft from storage
  Future<void> clearDraft() async {
    await _prefs.remove(_draftKey);
  }

  /// Update specific fields in the draft
  Future<void> updateDraft({
    String? firstName,
    String? lastName,
    String? email,
    int? heightCm,
    DateTime? dateOfBirth,
    String? city,
    double? coordinatesLatitude,
    double? coordinatesLongitude,
    // Add other fields as needed...
  }) async {
    final currentDraft = loadDraft() ?? ProfileCreationDraft();

    final updatedDraft = currentDraft.copyWith(
      firstName: firstName,
      lastName: lastName,
      email: email,
      heightCm: heightCm,
      dateOfBirth: dateOfBirth,
      city: city,
      coordinatesLatitude: coordinatesLatitude,
      coordinatesLongitude: coordinatesLongitude,
    );

    await saveDraft(updatedDraft);
  }
}

/// Exception thrown when profile creation operations fail
class ProfileCreationException implements Exception {
  final String message;

  ProfileCreationException(this.message);

  @override
  String toString() => 'ProfileCreationException: $message';
}
