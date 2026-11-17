import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eros_app/features/profile/data/services/profile_creation_service.dart';
import 'package:eros_app/features/profile/domain/models/profile_creation_draft.dart';

/// Provider for SharedPreferences instance
/// This will be overridden in main.dart with the initialized instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized in main()');
});

/// Provider for ProfileCreationService
final profileCreationServiceProvider = Provider<ProfileCreationService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ProfileCreationService(prefs);
});

/// StateNotifier for managing profile creation state
class ProfileCreationNotifier extends StateNotifier<ProfileCreationDraft> {
  final ProfileCreationService _service;

  ProfileCreationNotifier(this._service) : super(ProfileCreationDraft()) {
    _loadDraft();
  }

  /// Load existing draft from storage
  void _loadDraft() {
    final draft = _service.loadDraft();
    if (draft != null) {
      state = draft;
    }
  }

  /// Update the draft and persist to storage
  Future<void> updateDraft(ProfileCreationDraft draft) async {
    state = draft;
    await _service.saveDraft(draft);
  }

  /// Update specific fields
  Future<void> updateFields({
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    int? heightCm,
    DateTime? dateOfBirth,
    String? city,
    double? coordinatesLatitude,
    double? coordinatesLongitude,
  }) async {
    state = state.copyWith(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phoneNumber: phoneNumber,
      heightCm: heightCm,
      dateOfBirth: dateOfBirth,
      city: city,
      coordinatesLatitude: coordinatesLatitude,
      coordinatesLongitude: coordinatesLongitude,
    );
    await _service.saveDraft(state);
  }

  /// Remove the phone number: the user skipped the step (RFC-010 D-3).
  Future<void> clearPhoneNumber() async {
    state = state.copyWith(clearPhoneNumber: true);
    await _service.saveDraft(state);
  }

  /// Clear the draft
  Future<void> clearDraft() async {
    state = ProfileCreationDraft();
    await _service.clearDraft();
  }

  /// Check if draft is complete
  bool get isComplete => state.isComplete;
}

/// True when the backend refused the sign-up's phone number (a 400 naming `phoneNumber`). The
/// phone step shows why and clears it once the user changes the number or skips.
final phoneNumberRejectedProvider = StateProvider<bool>((ref) => false);

/// Provider for ProfileCreationNotifier
final profileCreationProvider =
    StateNotifierProvider<ProfileCreationNotifier, ProfileCreationDraft>(
  (ref) {
    final service = ref.watch(profileCreationServiceProvider);
    return ProfileCreationNotifier(service);
  },
);
