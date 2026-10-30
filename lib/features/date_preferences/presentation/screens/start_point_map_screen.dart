import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:eros_app/core/config/map_config.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/date_preferences/data/device_location_service.dart';
import 'package:eros_app/features/date_preferences/domain/models/city_district.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preference_options.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preference_options_provider.dart';
import 'package:eros_app/features/date_preferences/presentation/widgets/nearest_district.dart';

/// Every string this screen shows.
abstract final class _Copy {
  static const title = 'Starting point';
  static const hint = 'Move the map so the pin is where you\'ll usually start from. Only you can '
      'see it.';
  static String near(String district) => 'Near $district';
  static String outside(String city) => 'Outside $city';
  static String inCity(String city) => 'In $city';
  static const pin = 'Starting point pin';
  static const jumpTo = 'Jump to';
  static String jumpToHint(String district) => 'Jump to $district';
  static const useMyLocation = 'Use my location';
  static const locationRefused =
      'Location access is off. You can still move the map to your starting point.';
  static const locationUnavailable =
      'We couldn\'t find your location. You can still move the map to your starting point.';
  static const setStartingPoint = 'Set starting point';
  static const useCityCentre = 'Use city centre';
  static const back = 'Back';
  // Local builds only: the map shows this when no tiles are configured.
  static const noTiles = 'No map tiles in this build. Set MAP_TILE_URL to see the map.';
}

/// What the user chose on the [StartPointMapScreen].
sealed class StartPointChoice {
  const StartPointChoice();
}

/// "Set starting point": the pin, rounded to 3 decimal places as the server stores it
/// (RFC-005 D-23). The caller puts it in that city's `start` (`WherePatch`).
final class StartPointPinned extends StartPointChoice {
  final GeoPoint point;

  const StartPointPinned(this.point);

  // The pin is close to the user's home, so it never reaches a log.
  @override
  String toString() => 'StartPointPinned(<redacted>)';
}

/// "Use city centre": the caller sends `start: null`.
final class StartPointCityCentre extends StartPointChoice {
  const StartPointCityCentre();
}

/// Tiles for the map, or null for the local grey placeholder ([MapConfig.tiles]).
final mapTilesProvider = Provider<MapTiles?>((ref) => MapConfig.tiles);

/// The map for a city's starting point (RFC-005 §4.4, §6.2 "Map screen").
///
/// The pin stays in the middle and the map moves under it. A label above the pin shows the
/// nearest district, worked out on the device ([nearestDistrict]), or that the pin is outside the
/// city, which disables "Set starting point". "Use my location" only moves the map: the phone's
/// position never leaves the device (primer rule 15). Pops with a [StartPointChoice], or null
/// when the user goes back.
class StartPointMapScreen extends ConsumerStatefulWidget {
  /// The city's centre and reach, from the options.
  final OptionsCity city;

  final String cityName;

  /// The saved pin, if any. The map opens on it, or on the city centre.
  final GeoPoint? start;

  const StartPointMapScreen({super.key, required this.city, required this.cityName, this.start});

  /// Opens the map and returns what the user chose.
  static Future<StartPointChoice?> open(
    BuildContext context, {
    required OptionsCity city,
    required String cityName,
    GeoPoint? start,
  }) {
    return Navigator.of(context).push<StartPointChoice>(MaterialPageRoute(
      builder: (_) => StartPointMapScreen(city: city, cityName: cityName, start: start),
    ));
  }

  @override
  ConsumerState<StartPointMapScreen> createState() => _StartPointMapScreenState();
}

class _StartPointMapScreenState extends ConsumerState<StartPointMapScreen> {
  static const _zoom = 14.0;

  final _mapController = MapController();
  late final ValueNotifier<GeoPoint> _centre;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _centre = ValueNotifier(widget.start ?? widget.city.centre);
  }

  @override
  void dispose() {
    _mapController.dispose();
    _centre.dispose();
    super.dispose();
  }

  void _moveTo(GeoPoint point) {
    _mapController.move(LatLng(point.latitude, point.longitude), _mapController.camera.zoom);
    _centre.value = point;
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final location = await ref.read(deviceLocationServiceProvider).currentLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    switch (location) {
      case LocationFix(:final point):
        _moveTo(point);
      case LocationRefused():
        _showMessage(_Copy.locationRefused);
      case LocationUnavailable():
        _showMessage(_Copy.locationUnavailable);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final tiles = ref.watch(mapTilesProvider);
    // While the districts load, or if they fail, the pin can still be set: the server works out
    // the district when it saves.
    final districts = ref.watch(cityDistrictsProvider(widget.city.cityId)).valueOrNull ?? const [];
    final initial = widget.start ?? widget.city.centre;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          tooltip: _Copy.back,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(_Copy.title, style: TextStyle(color: Colors.black)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(initial.latitude, initial.longitude),
                    initialZoom: _zoom,
                    minZoom: 9,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onPositionChanged: (camera, _) => _centre.value = GeoPoint(
                      latitude: camera.center.latitude,
                      longitude: camera.center.longitude,
                    ),
                  ),
                  children: [
                    if (tiles == null)
                      const _PlaceholderTiles()
                    else ...[
                      TileLayer(
                        urlTemplate: tiles.urlTemplate,
                        additionalOptions: {'key': tiles.key},
                        userAgentPackageName: 'com.eros.eros_app',
                      ),
                      SimpleAttributionWidget(
                        source: Text(tiles.attribution, style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ],
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: ValueListenableBuilder<GeoPoint>(
                      valueListenable: _centre,
                      builder: (context, centre, _) => _CentrePin(
                        label: _label(_lookup(centre, districts)),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _UseMyLocationButton(
                    locating: _locating,
                    onPressed: _locating ? null : _useMyLocation,
                  ),
                ),
              ],
            ),
          ),
          _BottomPanel(
            districts: districts,
            onJumpTo: (d) => _moveTo(GeoPoint(latitude: d.latitude, longitude: d.longitude)),
            saveButton: ValueListenableBuilder<GeoPoint>(
              valueListenable: _centre,
              builder: (context, centre, _) {
                final outside = _lookup(centre, districts) is OutsideCity;
                return ElevatedButton(
                  onPressed: outside
                      ? null
                      : () => Navigator.of(context).pop(StartPointPinned(roundPoint(centre))),
                  child: const Text(_Copy.setStartingPoint),
                );
              },
            ),
            onUseCityCentre: () => Navigator.of(context).pop(const StartPointCityCentre()),
          ),
        ],
      ),
    );
  }

  DistrictLookup _lookup(GeoPoint centre, List<CityDistrict> districts) => nearestDistrict(
        pin: centre,
        cityCentre: widget.city.centre,
        reachMeters: widget.city.reachMeters,
        districts: districts,
      );

  String _label(DistrictLookup lookup) => switch (lookup) {
        NearDistrict(:final district) => _Copy.near(district.name),
        NoDistricts() => _Copy.inCity(widget.cityName),
        OutsideCity() => _Copy.outside(widget.cityName),
      };
}

/// A plain grey map for local builds without tiles.
class _PlaceholderTiles extends StatelessWidget {
  const _PlaceholderTiles();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.grey.shade300,
      child: const Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Text(_Copy.noTiles, style: TextStyle(fontSize: 11, color: Colors.black54)),
        ),
      ),
    );
  }
}

/// The fixed pin in the middle of the map, its tip on the centre, with the district label above.
class _CentrePin extends StatelessWidget {
  static const _pinSize = 48.0;
  static const _labelHeight = 32.0;
  static const _gap = 4.0;

  final String label;

  const _CentrePin({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        // Lifts the pin and label so the pin's tip, not their middle, marks the map's centre.
        offset: const Offset(0, -(_labelHeight + _gap + _pinSize) / 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: Container(
                height: _labelHeight,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Text(
                  label,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: _gap),
            const Icon(
              Icons.location_on,
              size: _pinSize,
              color: AppColors.primaryOrangeDark,
              semanticLabel: _Copy.pin,
            ),
          ],
        ),
      ),
    );
  }
}

class _UseMyLocationButton extends StatelessWidget {
  final bool locating;
  final VoidCallback? onPressed;

  const _UseMyLocationButton({required this.locating, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size(44, 44),
      ),
      icon: locating
          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.my_location),
      label: const Text(_Copy.useMyLocation),
    );
  }
}

/// The hint, the "Jump to" district chips and the two ways to finish.
class _BottomPanel extends StatelessWidget {
  final List<CityDistrict> districts;
  final ValueChanged<CityDistrict> onJumpTo;
  final Widget saveButton;
  final VoidCallback onUseCityCentre;

  const _BottomPanel({
    required this.districts,
    required this.onJumpTo,
    required this.saveButton,
    required this.onUseCityCentre,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(_Copy.hint, style: TextStyle(color: AppColors.textSecondary)),
              if (districts.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(_Copy.jumpTo, style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: districts.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final district = districts[i];
                      return Semantics(
                        hint: _Copy.jumpToHint(district.name),
                        child: ActionChip(
                          label: Text(district.name),
                          onPressed: () => onJumpTo(district),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(height: 48, child: saveButton),
              TextButton(onPressed: onUseCityCentre, child: const Text(_Copy.useCityCentre)),
            ],
          ),
        ),
      ),
    );
  }
}
