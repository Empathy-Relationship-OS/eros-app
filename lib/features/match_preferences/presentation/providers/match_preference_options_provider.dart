import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/match_preferences/data/match_preferences_repository.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preference_options.dart';

/// The bounds, distance stops, age default and gender suggestion the match preference screens
/// need (RFC-007 §5).
///
/// Auto-disposed, so it's fetched again on the next visit: the distance stops follow the dating
/// cities and the suggestion follows the profile, which both change on other screens.
final matchPreferenceOptionsProvider = FutureProvider.autoDispose<MatchPreferenceOptions>((ref) {
  return ref.watch(matchPreferencesRepositoryProvider).options();
});
