import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_repository.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/domain/models/section_patch.dart';

/// The signed-in user's date preferences (RFC-005 §6.1).
///
/// Loads `GET /users/me/date-preferences`. [DatePreferencesNotifier.saveSection] sends one
/// section with `PATCH /users/me/date-preferences`.
class DatePreferencesNotifier extends AsyncNotifier<DatePreferences> {
  @override
  Future<DatePreferences> build() {
    return ref.watch(datePreferencesRepositoryProvider).get();
  }

  /// Reloads from the server, keeping the previous value while loading.
  Future<void> load() async {
    state = const AsyncLoading<DatePreferences>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => ref.read(datePreferencesRepositoryProvider).get());
  }

  /// Saves one section.
  ///
  /// On success the state becomes the server's response, not a local merge, and nothing is
  /// refetched (RFC-005 D-2). On failure the previous state is kept and the error is rethrown for
  /// the section screen to show.
  Future<DatePreferences> saveSection(SectionPatch patch) async {
    final saved = await ref.read(datePreferencesRepositoryProvider).patch(patch);
    state = AsyncData(saved);
    return saved;
  }
}

/// Provider for the signed-in user's date preferences.
final datePreferencesProvider = AsyncNotifierProvider<DatePreferencesNotifier, DatePreferences>(
  DatePreferencesNotifier.new,
);
