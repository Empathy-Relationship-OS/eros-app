import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_repository.dart';
import 'package:eros_app/features/date_preferences/domain/models/city_district.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preference_options.dart';

/// Every option list the date preference screens render, by city (RFC-005 §5).
///
/// `null` asks for the user's first dating city. Not auto-disposed, so each city's options are
/// fetched once per session.
final datePreferenceOptionsProvider =
    FutureProvider.family<DatePreferenceOptions, int?>((ref, cityId) {
  return ref.watch(datePreferencesRepositoryProvider).options(cityId: cityId);
});

/// A city's districts, sorted by name, for "Jump to" and the live "Near ..." label.
final cityDistrictsProvider = FutureProvider.family<List<CityDistrict>, int>((ref, cityId) {
  return ref.watch(datePreferencesRepositoryProvider).districts(cityId);
});
