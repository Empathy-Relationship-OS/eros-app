import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/date_preferences/domain/models/dating_city.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preference_options_provider.dart';
import 'package:eros_app/features/legal/data/legal_repository.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';

/// The id of the city called [cityName], matched case-insensitively, as the backend matches a
/// user's city to their legal region (`UserRegionAdapter`). Null if there is none, and the
/// backend then uses the `ALL` region too.
int? cityIdForName(String? cityName, List<DatingCity> cities) {
  final wanted = cityName?.trim().toLowerCase();
  if (wanted == null || wanted.isEmpty) return null;
  for (final city in cities) {
    if (city.cityName.trim().toLowerCase() == wanted) return city.cityId;
  }
  return null;
}

/// The current documents for the region of the home city called [cityName] (null: the `ALL`
/// region). So a consent always carries the version of the user's own region (primer rule 17).
final legalDocumentsForCityProvider =
    FutureProvider.autoDispose.family<List<LegalDocument>, String?>((ref, cityName) async {
  final repository = ref.watch(legalRepositoryProvider);
  if (cityName == null || cityName.trim().isEmpty) return repository.documents();
  final cities = await ref.watch(datingCitiesProvider.future);
  return repository.documents(cityId: cityIdForName(cityName, cities));
});

/// The document of [kind] in [documents], or null if the region has none in effect.
LegalDocument? documentOf(List<LegalDocument> documents, DocumentKind kind) {
  for (final document in documents) {
    if (document.kind == kind) return document;
  }
  return null;
}
