import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

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
  final _cityController = TextEditingController();
  bool _isValid = false;
  bool _useGps = true;
  String? _selectedCity;
  double? _selectedLat;
  double? _selectedLon;

  // Mock cities for demo - in production, this would come from a geocoding API
  final List<Map<String, dynamic>> _citySuggestions = [
    {'name': 'London', 'lat': 51.5074, 'lon': -0.1278},
    {'name': 'Manchester', 'lat': 53.4808, 'lon': -2.2426},
    {'name': 'Birmingham', 'lat': 52.4862, 'lon': -1.8904},
    {'name': 'Edinburgh', 'lat': 55.9533, 'lon': -3.1883},
    {'name': 'Glasgow', 'lat': 55.8642, 'lon': -4.2518},
  ];

  List<Map<String, dynamic>> _filteredCities = [];

  @override
  void initState() {
    super.initState();
    _loadExistingData();
    _cityController.addListener(_onSearchChanged);
  }

  void _loadExistingData() {
    final draft = ref.read(profileCreationProvider);
    if (draft.city != null) {
      _selectedCity = draft.city;
      _selectedLat = draft.coordinatesLatitude;
      _selectedLon = draft.coordinatesLongitude;
      _cityController.text = draft.city!;
      _isValid = true;
    }
  }

  void _onSearchChanged() {
    final query = _cityController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredCities = [];
        _isValid = false;
      });
      return;
    }

    setState(() {
      _filteredCities = _citySuggestions
          .where((city) => city['name'].toLowerCase().contains(query))
          .toList();
    });
  }

  void _selectCity(Map<String, dynamic> city) {
    setState(() {
      _selectedCity = city['name'];
      _selectedLat = city['lat'];
      _selectedLon = city['lon'];
      _cityController.text = city['name'];
      _filteredCities = [];
      _isValid = true;
    });
  }

  Future<void> _requestGpsLocation() async {
    // TODO: Implement actual GPS location request
    // For now, show a message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS location feature coming soon. Please enter city manually.'),
          duration: Duration(seconds: 2),
        ),
      );
      setState(() {
        _useGps = false;
      });
    }
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
  void dispose() {
    _cityController.dispose();
    super.dispose();
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
              _buildProgressBar(2, 11),
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
              if (_useGps) ...[
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 64,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _requestGpsLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text('Use my location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _useGps = false;
                          });
                        },
                        child: const Text('Enter location manually'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Manual city input
                TextField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: 'City',
                    hintText: 'Start typing...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // City suggestions
                if (_filteredCities.isNotEmpty) ...[
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredCities.length,
                      itemBuilder: (context, index) {
                        final city = _filteredCities[index];
                        return ListTile(
                          leading: const Icon(Icons.location_city),
                          title: Text(city['name']),
                          onTap: () => _selectCity(city),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _useGps = true;
                      _cityController.clear();
                      _filteredCities = [];
                    });
                  },
                  icon: const Icon(Icons.my_location),
                  label: const Text('Use GPS instead'),
                ),
              ],

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

  Widget _buildProgressBar(int currentStep, int totalSteps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step $currentStep of $totalSteps',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${((currentStep / totalSteps) * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: currentStep / totalSteps,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
