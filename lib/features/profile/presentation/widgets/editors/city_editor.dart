import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';

/// A home city and its coordinates, as `users.city` and `coordinatesLatitude`/`Longitude` store
/// them. Home city is free text on the backend (RFC-004 D-14); it is not one of the `cities`
/// the app operates in.
class HomeCity {
  final String name;
  final double? latitude;
  final double? longitude;

  const HomeCity(this.name, this.latitude, this.longitude);

  @override
  bool operator ==(Object other) =>
      other is HomeCity &&
      other.name == name &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(name, latitude, longitude);

  @override
  String toString() => 'HomeCity($name, $latitude, $longitude)';
}

/// The home-city picker (RFC-004 §6.2): "Use my location" (not built yet, it says so and
/// switches to typing), or type and pick from the suggestions.
///
/// It keeps its own text field and mode. [initialCity] fills the field. Picking a suggestion
/// reports it through [onCitySelected]. While the field is empty, every change to it (including
/// moving the cursor) calls [onQueryCleared], so it may be called more than once. The last picked
/// city is not reported as removed; a wrapper decides what an empty field means.
///
/// The suggestions are the same fixed list onboarding has always used, a stand-in for a
/// geocoding service. They are not checked against the backend's `cities` table (D-14).
class CityEditor extends StatefulWidget {
  final String? initialCity;
  final ValueChanged<HomeCity> onCitySelected;
  final VoidCallback onQueryCleared;

  const CityEditor({
    super.key,
    this.initialCity,
    required this.onCitySelected,
    required this.onQueryCleared,
  });

  /// Mock cities for demo - in production, this would come from a geocoding API.
  static const List<HomeCity> suggestions = [
    HomeCity('London', 51.5074, -0.1278),
    HomeCity('Manchester', 53.4808, -2.2426),
    HomeCity('Birmingham', 52.4862, -1.8904),
    HomeCity('Edinburgh', 55.9533, -3.1883),
    HomeCity('Glasgow', 55.8642, -4.2518),
  ];

  @override
  State<CityEditor> createState() => _CityEditorState();
}

class _CityEditorState extends State<CityEditor> {
  final _cityController = TextEditingController();
  bool _useGps = true;
  List<HomeCity> _filteredCities = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialCity != null) {
      _cityController.text = widget.initialCity!;
    }
    _cityController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _cityController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredCities = [];
      });
      widget.onQueryCleared();
      return;
    }

    setState(() {
      _filteredCities = CityEditor.suggestions
          .where((city) => city.name.toLowerCase().contains(query))
          .toList();
    });
  }

  void _selectCity(HomeCity city) {
    setState(() {
      _cityController.text = city.name;
      _filteredCities = [];
    });
    widget.onCitySelected(city);
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

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    title: Text(city.name),
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
      ],
    );
  }
}
