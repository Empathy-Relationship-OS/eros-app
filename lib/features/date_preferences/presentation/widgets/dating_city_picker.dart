import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_repository.dart';
import 'package:eros_app/features/date_preferences/domain/models/dating_city.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preference_options_provider.dart';

/// Every string this widget shows that isn't from the server.
abstract final class _Copy {
  static const loadError = 'We couldn\'t load the cities. Please try again.';
  static const retry = 'Try again';
  static const empty = 'There are no cities to choose from yet.';
}

/// The cities users can date in, from `GET /city/all` ([datingCitiesProvider]), as multi-select
/// chips. Shared by onboarding and the "Where" editor (RFC-005 §6.1, eros-app #16).
///
/// Controlled: the screen owns [selectedCityIds] and its order (the first city sets the travel
/// stops), and updates it from [onToggle]. "At least one city" is the screen's to enforce, by
/// disabling its Continue or Save. Doesn't scroll, so place it in a scrolling parent.
class DatingCityPicker extends ConsumerWidget {
  final List<int> selectedCityIds;
  final ValueChanged<DatingCity> onToggle;

  const DatingCityPicker({super.key, required this.selectedCityIds, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cities = ref.watch(datingCitiesProvider);

    if (cities.hasError && !cities.isLoading) {
      final error = cities.error;
      return _Message(
        text: error is DatePreferencesRepositoryException ? error.message : _Copy.loadError,
        onRetry: () => ref.invalidate(datingCitiesProvider),
      );
    }
    final list = cities.valueOrNull;
    if (list == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (list.isEmpty) return const _Message(text: _Copy.empty);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final city in list)
          _CityChip(
            city: city,
            selected: selectedCityIds.contains(city.cityId),
            onTap: () => onToggle(city),
          ),
      ],
    );
  }
}

class _CityChip extends StatelessWidget {
  final DatingCity city;
  final bool selected;
  final VoidCallback onTap;

  const _CityChip({required this.city, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(city.cityName),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.grey[100],
      side: BorderSide(color: selected ? AppColors.primary : Colors.grey[300]!, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize: 16,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;

  const _Message({required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700])),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text(_Copy.retry)),
          ],
        ],
      ),
    );
  }
}
