import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/features/date_preferences/domain/models/dating_city.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preference_options_provider.dart';
import 'package:eros_app/features/date_preferences/presentation/widgets/dating_city_picker.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';

/// Dating cities selector - choose cities where user wants to date, from the cities we operate
/// in ([DatingCityPicker], `GET /city/all`). The choice is kept in the draft as city ids.
/// Matches screenshot: @screenshots/login/create-user/EABDAE3A-4630-44B2-85B2-E97A280C19E2.png
class DatingCitiesScreen extends ConsumerStatefulWidget {
  const DatingCitiesScreen({super.key});

  @override
  ConsumerState<DatingCitiesScreen> createState() => _DatingCitiesScreenState();
}

class _DatingCitiesScreenState extends ConsumerState<DatingCitiesScreen> {
  /// In the order chosen, so the first stays the user's first dating city.
  final List<int> _selectedCityIds = [];

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    final draft = ref.read(profileCreationProvider);
    if (draft.datingCityIds != null) {
      _selectedCityIds.addAll(draft.datingCityIds!);
    }
  }

  void _toggleCity(DatingCity city) {
    setState(() {
      if (!_selectedCityIds.remove(city.cityId)) {
        _selectedCityIds.add(city.cityId);
      }
    });
  }

  /// The selected ids the server still lists, so a city it has dropped since the draft was saved
  /// is never sent.
  List<int> _listedSelection(List<DatingCity> cities) => [
        for (final id in _selectedCityIds)
          if (cities.any((c) => c.cityId == id)) id,
      ];

  Future<void> _continue(List<int> cityIds) async {
    if (cityIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one city'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final currentDraft = ref.read(profileCreationProvider);
    await ref
        .read(profileCreationProvider.notifier)
        .updateDraft(currentDraft.copyWith(datingCityIds: cityIds));

    // Navigate to next screen
    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/gender');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _listedSelection(ref.watch(datingCitiesProvider).valueOrNull ?? const []);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress indicator
              ProfileProgressBar(
                currentStep: ProfileCreationConstants.basicInfoStepDatingCities,
                totalSteps: ProfileCreationConstants.basicInfoTotalSteps,
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Where do you want to date?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select at least one city',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 32),

              // City chips
              Expanded(
                child: SingleChildScrollView(
                  child: DatingCityPicker(
                    selectedCityIds: _selectedCityIds,
                    onToggle: _toggleCity,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Selection count
              if (selected.isNotEmpty) ...[
                Text(
                  '${selected.length} ${selected.length == 1 ? 'city' : 'cities'} selected',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: selected.isNotEmpty ? () => _continue(selected) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
