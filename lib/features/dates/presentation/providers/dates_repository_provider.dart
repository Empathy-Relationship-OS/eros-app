import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/dates/data/repositories/dates_repository.dart';
import 'package:eros_app/core/network/api_client_provider.dart';

/// Centralized repository provider for the dates feature
///
/// This provider ensures all dates-related data access goes through
/// a single DatesRepository instance with shared ApiClient configuration.
final datesRepositoryProvider = Provider<DatesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DatesRepository(apiClient);
});
