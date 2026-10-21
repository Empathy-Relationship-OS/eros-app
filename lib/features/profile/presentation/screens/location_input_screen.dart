import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/city_editor.dart';

/// Location input screen - allows GPS or manual city entry
/// Matches screenshots:
/// - @screenshots/login/create-user/7E4077C0-9A59-4E60-B938-15CC0824CE29.png
/// - @screenshots/login/create-user/11483E57-4A96-4518-A342-95B435339F00.png
class LocationInputScreen extends ConsumerStatefulWidget {
  const LocationInputScreen({super.key});

  @override
  ConsumerState<LocationInputScreen> createState() => _LocationInputScreenState();
}

class _LocationInputScreenState extends ConsumerState<LocationInputScreen> {
  bool _isValid = false;
  String? _selectedCity;
  double? _selectedLat;
  double? _selectedLon;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  void _loadExistingData() {
    final draft = ref.read(profileCreationProvider);
    if (draft.city != null) {
      _selectedCity = draft.city;
      _selectedLat = draft.coordinatesLatitude;
      _selectedLon = draft.coordinatesLongitude;
      _isValid = true;
    }
  }

  void _selectCity(HomeCity city) {
    setState(() {
      _selectedCity = city.name;
      _selectedLat = city.latitude;
      _selectedLon = city.longitude;
      _isValid = true;
    });
  }

  Future<void> _continue() async {
    if (!_isValid || _selectedCity == null) {
      return;
    }

    // Update the draft
    await ref.read(profileCreationProvider.notifier).updateFields(
          city: _selectedCity,
          coordinatesLatitude: _selectedLat,
          coordinatesLongitude: _selectedLon,
        );

    // Navigate to next screen
    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/dating-cities');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                currentStep: ProfileCreationConstants.basicInfoStepLocation,
                totalSteps: ProfileCreationConstants.basicInfoTotalSteps,
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Where are you based?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'We\'ll use this to find dates near you',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 24),

              // Location options
              CityEditor(
                initialCity: _selectedCity,
                onCitySelected: _selectCity,
                // As before: emptying the field disables Continue but keeps the last pick.
                onQueryCleared: () => setState(() => _isValid = false),
              ),

              const Spacer(),

              // Venue count placeholder
              if (_selectedCity != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.store, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        '100+ venues in $_selectedCity',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isValid ? _continue : null,
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
