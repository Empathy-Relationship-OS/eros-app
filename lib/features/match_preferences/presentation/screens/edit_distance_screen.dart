import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_repository.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preference_options.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preferences_provider.dart';
import 'package:eros_app/features/date_preferences/presentation/screens/edit_where_screen.dart';
import 'package:eros_app/features/date_preferences/presentation/widgets/travel_distance_slider.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_patch.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_filter.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preference_options.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preferences.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preference_options_provider.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preferences_provider.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/match_filter_summary.dart';
import 'package:eros_app/features/match_preferences/presentation/widgets/dealbreaker_switch.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_section_scaffold.dart';

/// Every string this screen shows.
abstract final class _Copy {
  static String fromNear(String district) => 'From near $district';
  static const fromCityCentre = 'From the city centre. Set your starting point';
  static const changeStartingPoint = 'Change your starting point in Date preferences';
  static String miles(String miles) => miles == '1' ? '1 mile' : '$miles miles';
  static String km(String km) => '$km km';

  static const where = 'Where';
  static const loadError = 'We couldn\'t load your date preferences. Please try again.';
  static const retry = 'Try again';
  static const back = 'Back';
}

/// The slider's stops from options' [DistanceOptions.stopsMeters], labelled in its unit: "1 mile",
/// "5 miles", "8 km".
List<TravelStop> distanceStops(DistanceOptions options) {
  return [
    for (final meters in options.stopsMeters)
      TravelStop(
        meters: meters,
        label: isMiles(options.unit)
            ? _Copy.miles(distanceInUnit(meters, options.unit))
            : _Copy.km(distanceInUnit(meters, options.unit)),
      ),
  ];
}

/// The Distance editor (RFC-007 §6.3): [TravelDistanceSlider] with options' stops in the city's
/// unit (`MI` or `KM`) and Anywhere, then where it's measured from, then the Dealbreaker switch.
///
/// Distance is measured from the starting pin in Date preferences, so the "From near Clapham"
/// line (or "From the city centre" with no pin) opens Date preferences' Where editor (D-7). The
/// options are fetched again when it closes, so the line and the stops follow any change.
///
/// Saves only [DistancePatch]; the hub then shows the server's response. A saved distance that
/// isn't one of the stops shows, and saves, as the nearest.
class EditDistanceScreen extends ConsumerStatefulWidget {
  /// The filter as the server last returned it.
  final DistanceFilter initial;

  /// The options the hub loaded, shown until fresher ones arrive.
  final DistanceOptions options;

  const EditDistanceScreen({super.key, required this.initial, required this.options});

  @override
  ConsumerState<EditDistanceScreen> createState() => _EditDistanceScreenState();
}

class _EditDistanceScreenState extends ConsumerState<EditDistanceScreen> {
  /// Null is Anywhere. May not be one of the shown stops until the user moves the slider.
  late int? _maxMeters = widget.initial.maxMeters;
  late bool _dealbreaker = widget.initial.dealbreaker;

  Future<void> _openWhere() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _WhereEditor()));
    // The starting pin or the dating cities may have changed.
    ref.invalidate(matchPreferenceOptionsProvider);
  }

  Future<void> _save(List<TravelStop> stops) async {
    final distance = DistanceFilter(
      maxMeters: TravelDistanceSlider.snap(stops, _maxMeters),
      dealbreaker: _dealbreaker,
    );
    await ref.read(matchPreferencesProvider.notifier).save(DistancePatch(distance));
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(matchPreferenceOptionsProvider).valueOrNull?.distance ??
        widget.options;
    final stops = distanceStops(options);
    final distanceChanged = TravelDistanceSlider.snap(stops, _maxMeters) != widget.initial.maxMeters;
    final isDirty = _maxMeters != widget.initial.maxMeters ||
        _dealbreaker != widget.initial.dealbreaker;

    return EditSectionScaffold(
      title: MatchFilter.distance.label,
      canSave: distanceChanged || _dealbreaker != widget.initial.dealbreaker,
      isDirty: isDirty,
      onSave: () => _save(stops),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: DealbreakerSubtitle(dealbreaker: _dealbreaker),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TravelDistanceSlider(
                    stops: stops,
                    meters: _maxMeters,
                    note: null,
                    onChanged: (meters) => setState(() => _maxMeters = meters),
                  ),
                ),
                const SizedBox(height: 16),
                _FromRow(from: options.from, onTap: _openWhere),
              ],
            ),
          ),
          DealbreakerFooter(
            value: _dealbreaker,
            onChanged: (value) => setState(() => _dealbreaker = value),
          ),
        ],
      ),
    );
  }
}

/// Where distance is measured from: "From near Clapham", or "From the city centre. Set your
/// starting point" with no pin. Opens Date preferences' Where editor.
class _FromRow extends StatelessWidget {
  final String? from;
  final VoidCallback onTap;

  const _FromRow({required this.from, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final district = from;
    return Semantics(
      button: true,
      hint: _Copy.changeStartingPoint,
      child: InkWell(
        key: const Key('distance-from'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.place_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  district == null ? _Copy.fromCityCentre : _Copy.fromNear(district),
                  style: const TextStyle(fontSize: 15, color: Colors.black),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Date preferences' Where editor, once the date preferences have loaded.
class _WhereEditor extends ConsumerWidget {
  const _WhereEditor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(datePreferencesProvider);
    if (preferences.valueOrNull case final p? when !preferences.hasError) {
      return EditWhereScreen(initial: p.where);
    }
    final error = preferences.hasError && !preferences.isLoading ? preferences.error : null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          tooltip: _Copy.back,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(_Copy.where, style: TextStyle(color: Colors.black)),
      ),
      body: Center(
        child: error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error is DatePreferencesRepositoryException
                          ? error.message
                          : _Copy.loadError,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.read(datePreferencesProvider.notifier).load(),
                      child: const Text(_Copy.retry),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
