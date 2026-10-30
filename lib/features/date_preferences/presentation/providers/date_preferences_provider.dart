import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_repository.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/domain/models/section_patch.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preference_options_provider.dart';

/// The signed-in user's date preferences (RFC-005 §6.1).
///
/// Loads `GET /users/me/date-preferences`. [DatePreferencesNotifier.saveSection] sends one
/// section with `PATCH /users/me/date-preferences`.
class DatePreferencesNotifier extends AsyncNotifier<DatePreferences> {
  @override
  Future<DatePreferences> build() {
    return ref.watch(datePreferencesRepositoryProvider).get();
  }

  /// Bumped by every [load] and [saveSection], so only the latest result lands in [state].
  int _generation = 0;

  /// Reloads from the server, keeping the previous value while loading.
  ///
  /// A load that finishes after a newer load or a save is ignored, so a late failure can't replace
  /// a later success.
  Future<void> load() async {
    final generation = ++_generation;
    state = const AsyncLoading<DatePreferences>().copyWithPrevious(state);
    final result = await AsyncValue.guard(() => ref.read(datePreferencesRepositoryProvider).get());
    if (generation == _generation) state = result;
  }

  /// Saves one section.
  ///
  /// On success the state becomes the server's response, not a local merge, and nothing is
  /// refetched (RFC-005 D-2). On failure the previous state is kept and the error is rethrown for
  /// the section screen to show.
  ///
  /// Saving "Where" can change the first dating city, so the options for "my first city" are
  /// fetched again on next read. That also happens when the server saved but its response
  /// couldn't be read ([DatePreferencesSavedException], still rethrown).
  Future<DatePreferences> saveSection(SectionPatch patch) async {
    try {
      final saved = await ref.read(datePreferencesRepositoryProvider).patch(patch);
      _generation++;
      state = AsyncData(saved);
      _afterSave(patch);
      return saved;
    } on DatePreferencesSavedException {
      _afterSave(patch);
      rethrow;
    }
  }

  void _afterSave(SectionPatch patch) {
    if (patch is WherePatch) {
      ref.invalidate(datePreferenceOptionsProvider(null));
    }
  }
}

/// Provider for the signed-in user's date preferences.
final datePreferencesProvider = AsyncNotifierProvider<DatePreferencesNotifier, DatePreferences>(
  DatePreferencesNotifier.new,
);
