import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_repository.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preference_options.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/domain/models/dating_city.dart';
import 'package:eros_app/features/date_preferences/domain/models/section_patch.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preference_options_provider.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preferences_provider.dart';
import 'package:eros_app/features/date_preferences/presentation/screens/start_point_map_screen.dart';
import 'package:eros_app/features/date_preferences/presentation/widgets/dating_city_picker.dart';
import 'package:eros_app/features/date_preferences/presentation/widgets/nearest_district.dart';
import 'package:eros_app/features/date_preferences/presentation/widgets/travel_distance_slider.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_section_scaffold.dart';

/// Every string this screen shows that isn't from the server.
abstract final class _Copy {
  static const title = 'Where';
  static const cities = 'Dating cities';
  static const citiesHint = 'Choose at least one city';
  static const startingFrom = 'Starting from';
  static const cityCentre = 'City centre';
  static const yourStartingPoint = 'Your starting point';
  static const distance = 'Travel distance';
  static const optionsError = 'We couldn\'t load the travel distances. Please try again.';
  static const mapError = 'We couldn\'t open the map. Please try again.';
  static const retry = 'Try again';
}

/// The "Where" editor (RFC-005 §6.2): dating cities, a starting point per city, and how far the
/// user will travel. Saves `WherePatch` alone (D-2); the hub then shows the server's response.
///
/// A city's "Starting from" row opens the [StartPointMapScreen]. What the user chooses there is
/// kept here and saved with the rest.
///
/// The travel stops are the first chosen city's (D-27), so they change when the first city does.
/// A saved distance that isn't one of them shows, and saves, as the nearest stop.
class EditWhereScreen extends ConsumerStatefulWidget {
  /// The section as the server last returned it.
  final WherePreferences initial;

  const EditWhereScreen({super.key, required this.initial});

  @override
  ConsumerState<EditWhereScreen> createState() => _EditWhereScreenState();
}

class _EditWhereScreenState extends ConsumerState<EditWhereScreen> {
  /// In order: the first sets the travel stops.
  late List<DatingCityPreference> _cities = widget.initial.cities;

  /// Null is Anywhere. May not be one of the shown stops until the user moves the slider.
  late int? _maxTravelMeters = widget.initial.maxTravelMeters;

  /// The city whose stops are shown. Kept while no city is chosen, so the slider doesn't jump.
  late int? _stopsCityId = widget.initial.cities.firstOrNull?.cityId;

  /// True while the map's city is loading, so a second tap doesn't open it twice.
  bool _openingMap = false;

  /// The options to read the stops from.
  int? get _optionsCityId => _optionsKey(_stopsCityId);

  /// The options key for [cityId]. The saved first city is the one the hub already loaded as
  /// "my first city", so it reuses that.
  int? _optionsKey(int? cityId) =>
      cityId == widget.initial.cities.firstOrNull?.cityId ? null : cityId;

  void _toggleCity(DatingCity city) {
    setState(() {
      if (_cities.any((c) => c.cityId == city.cityId)) {
        _cities = [
          for (final c in _cities)
            if (c.cityId != city.cityId) c,
        ];
      } else {
        // A city removed and chosen again keeps its saved starting point.
        final saved = widget.initial.cities.where((c) => c.cityId == city.cityId).firstOrNull;
        _cities = [
          ..._cities,
          saved ?? DatingCityPreference(cityId: city.cityId, cityName: city.cityName),
        ];
      }
      if (_cities.isNotEmpty) _stopsCityId = _cities.first.cityId;
    });
  }

  /// Opens the map for [city] and puts the user's choice in its `start`. Going back changes
  /// nothing.
  Future<void> _editStart(DatingCityPreference city) async {
    if (_openingMap) return;
    _openingMap = true;
    try {
      final OptionsCity? optionsCity;
      try {
        final options =
            await ref.read(datePreferenceOptionsProvider(_optionsKey(city.cityId)).future);
        optionsCity = options.city;
      } catch (_) {
        if (mounted) _showMessage(_Copy.mapError);
        return;
      }
      if (!mounted) return;
      if (optionsCity == null) {
        _showMessage(_Copy.mapError);
        return;
      }

      final choice = await StartPointMapScreen.open(
        context,
        city: optionsCity,
        cityName: city.cityName,
        start: city.start?.point,
      );
      if (!mounted || choice == null) return;

      final updated = switch (choice) {
        StartPointCityCentre() => city.copyWith(clearStart: true),
        // The same pin again keeps the server's district for it.
        StartPointPinned(:final point) when point == city.start?.point => city,
        StartPointPinned(:final point) => city.copyWith(
            start: StartPoint(
              latitude: point.latitude,
              longitude: point.longitude,
              district: _districtOf(point, optionsCity),
            ),
          ),
      };
      setState(() {
        _cities = [
          for (final c in _cities) c.cityId == city.cityId ? updated : c,
        ];
      });
    } finally {
      _openingMap = false;
    }
  }

  /// The district the row shows for a new pin until it's saved, worked out as the map did. Null
  /// if the districts didn't load or the city has none; the server works it out when it saves.
  DistrictRef? _districtOf(GeoPoint point, OptionsCity city) {
    final districts = ref.read(cityDistrictsProvider(city.cityId)).valueOrNull ?? const [];
    final lookup = nearestDistrict(
      pin: point,
      cityCentre: city.centre,
      reachMeters: city.reachMeters,
      districts: districts,
    );
    return switch (lookup) {
      NearDistrict(:final district) =>
        DistrictRef(districtId: district.districtId, name: district.name),
      NoDistricts() || OutsideCity() => null,
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Sends the cities with each one's current starting point, and the distance as shown.
  Future<void> _save(List<TravelStop> stops) async {
    final patch = WherePatch(
      cities: [
        for (final city in _cities) WhereCityPatch(cityId: city.cityId, start: city.start?.point),
      ],
      maxTravelMeters: TravelDistanceSlider.snap(stops, _maxTravelMeters),
    );
    await ref.read(datePreferencesProvider.notifier).saveSection(patch);
  }

  @override
  Widget build(BuildContext context) {
    final optionsCityId = _optionsCityId;
    final options = ref.watch(datePreferenceOptionsProvider(optionsCityId));
    final stops = options.isLoading ? null : options.valueOrNull?.travelStops;

    final citiesChanged = !listEquals(_cities, widget.initial.cities);
    final distanceChanged = stops != null &&
        TravelDistanceSlider.snap(stops, _maxTravelMeters) != widget.initial.maxTravelMeters;

    return EditSectionScaffold(
      title: _Copy.title,
      canSave: _cities.isNotEmpty && stops != null && (citiesChanged || distanceChanged),
      isDirty: citiesChanged || _maxTravelMeters != widget.initial.maxTravelMeters,
      onSave: () => _save(stops ?? const []),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          const _Heading(_Copy.cities),
          const SizedBox(height: 4),
          Text(_Copy.citiesHint, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          DatingCityPicker(
            selectedCityIds: [for (final city in _cities) city.cityId],
            onToggle: _toggleCity,
          ),
          for (final city in _cities) ...[
            const SizedBox(height: 12),
            _StartingFromRow(
              key: Key('starting-from-${city.cityId}'),
              city: city,
              onTap: () => _editStart(city),
            ),
          ],
          const SizedBox(height: 32),
          const _Heading(_Copy.distance),
          const SizedBox(height: 12),
          if (stops != null)
            TravelDistanceSlider(
              stops: stops,
              meters: _maxTravelMeters,
              onChanged: (meters) => setState(() => _maxTravelMeters = meters),
            )
          else if (options.hasError)
            _OptionsError(
              error: options.error!,
              onRetry: () => ref.invalidate(datePreferenceOptionsProvider(optionsCityId)),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;

  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

/// A chosen city and where the user starts from in it: the district of their pin, "Your starting
/// point" for a pin with no district (a city without districts), or the city centre when they
/// haven't placed one.
class _StartingFromRow extends StatelessWidget {
  final DatingCityPreference city;

  /// Opens the map.
  final VoidCallback onTap;

  const _StartingFromRow({super.key, required this.city, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final start = city.start;
    final startLabel = start == null
        ? _Copy.cityCentre
        : start.district?.name ?? _Copy.yourStartingPoint;
    return MergeSemantics(
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.place_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(city.cityName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(_Copy.startingFrom, style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                Text(startLabel),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionsError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _OptionsError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = error is DatePreferencesRepositoryException
        ? (error as DatePreferencesRepositoryException).message
        : _Copy.optionsError;
    return Column(
      children: [
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700])),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: onRetry, child: const Text(_Copy.retry)),
      ],
    );
  }
}
