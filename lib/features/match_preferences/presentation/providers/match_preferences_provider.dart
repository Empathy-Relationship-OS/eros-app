import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/match_preferences/data/match_preferences_repository.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_patch.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preferences.dart';

/// The signed-in user's match preferences (RFC-007 §6.1).
///
/// Loads `GET /users/me/match-preferences`. [MatchPreferencesNotifier.save] sends one filter with
/// `PATCH /users/me/match-preferences`.
class MatchPreferencesNotifier extends AsyncNotifier<MatchPreferences> {
  /// Bumped by every [build], [load] and [save], so only the latest result lands in [state].
  int _generation = 0;

  /// The save in flight, if any. Each save waits for the one before it.
  Future<void> _saves = Future.value();

  @override
  Future<MatchPreferences> build() async {
    final repository = ref.watch(matchPreferencesRepositoryProvider);
    final generation = ++_generation;
    // A save that landed while this load was in flight is newer: keep it, even over a failure.
    bool superseded() => generation != _generation && state.hasValue;
    final MatchPreferences preferences;
    try {
      preferences = await repository.get();
    } catch (_) {
      if (superseded()) return state.requireValue;
      rethrow;
    }
    return superseded() ? state.requireValue : preferences;
  }

  /// Reloads from the server, keeping the previous value while loading.
  ///
  /// A load that finishes after a newer load or a save is ignored, so a late failure can't replace
  /// a later success.
  Future<void> load() async {
    final generation = ++_generation;
    state = const AsyncLoading<MatchPreferences>().copyWithPrevious(state);
    final result = await AsyncValue.guard(() => ref.read(matchPreferencesRepositoryProvider).get());
    if (generation == _generation) state = result;
  }

  /// Saves one filter.
  ///
  /// On success the state becomes the server's response, not a local merge, and nothing is
  /// refetched (primer rule 17). On failure the previous state is kept and the error is rethrown
  /// for the screen to show: a [MatchPreferencesValidationException] carries the server's message.
  ///
  /// Saves run one at a time, so each response includes every save before it, even when the
  /// responses would otherwise arrive out of order. A failed save doesn't stop the next one.
  Future<MatchPreferences> save(FilterPatch patch) {
    final result = _saves.then((_) => _save(patch));
    _saves = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<MatchPreferences> _save(FilterPatch patch) async {
    final saved = await ref.read(matchPreferencesRepositoryProvider).patch(patch);
    _generation++;
    state = AsyncData(saved);
    return saved;
  }
}

/// Provider for the signed-in user's match preferences.
final matchPreferencesProvider = AsyncNotifierProvider<MatchPreferencesNotifier, MatchPreferences>(
  MatchPreferencesNotifier.new,
);
