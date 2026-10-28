import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_repository.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preference_options.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preference_options_provider.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preferences_provider.dart';
import 'package:eros_app/features/date_preferences/presentation/screens/edit_date_types_screen.dart';

/// The "Where" editor arrives with DP-F3. Until then its row opens a placeholder.
const bool whereEditorEnabled = false;

/// The "Date types" editor (DP-F5).
const bool dateTypesEditorEnabled = true;

/// The "Dinner" editor arrives with DP-F6. Until then its row opens a placeholder.
const bool foodEditorEnabled = false;

/// The "Drinks" editor arrives with DP-F6. Until then its row opens a placeholder.
const bool drinksEditorEnabled = false;

/// "The venue" editor arrives with DP-F6. Until then its row opens a placeholder.
const bool venueEditorEnabled = false;

/// Every string this screen shows that isn't from the options.
abstract final class _Copy {
  static const title = 'Date preferences';
  static const intro = 'These shape the places we suggest. You and your date still rank them. '
      'Only you can see this page.';
  static const notSetBanner = 'Tell us what you like and we\'ll pick better places';

  static const where = 'Where';
  static const dateTypes = 'Date types';
  static const dinner = 'Dinner';
  static const drinks = 'Drinks';
  static const venue = 'The venue';
  static String editHint(String section) => 'Edit $section';

  static const cityCentre = 'City centre';
  static String near(String district) => 'near $district';
  static const anywhere = 'Anywhere';
  static String upTo(String distance) => 'up to $distance';
  static String miles(String miles) => miles == '1' ? '1 mile' : '$miles miles';
  static String km(String km) => '$km km';

  static String level(PreferenceLevel level) => switch (level) {
        PreferenceLevel.love => 'Love it',
        PreferenceLevel.ok => 'Happy to',
        PreferenceLevel.no => 'Not for me',
      };

  static String loves(String cuisines) => 'Loves $cuisines';
  static String wontEat(String cuisines) => 'won\'t eat $cuisines';
  static const anyCuisine = 'Any cuisine';

  static const anyBar = 'Any kind of bar';
  static const alcoholFree = 'Good alcohol-free options';

  static String atmosphere(String value) => 'Atmosphere: $value';
  static String setting(String value) => 'Setting: $value';
  static String stepFree({required bool needed}) =>
      'Step-free access: ${needed ? 'needed' : 'not needed'}';

  static const loadError = 'We couldn\'t load your date preferences. Please try again.';
  static const retry = 'Try again';
  static const back = 'Back';
  static const placeholder = 'You\'ll be able to change this soon.';
}

/// Date preferences (RFC-005 §6.2): every section in plain words, from
/// `GET /users/me/date-preferences` ([datePreferencesProvider]) and the option lists for the
/// user's first dating city ([datePreferenceOptionsProvider]). Tapping a section opens its
/// editor. Every option label, unit and currency symbol comes from the options (D-8, D-15).
class DatePreferencesScreen extends ConsumerWidget {
  const DatePreferencesScreen({super.key});

  /// Fetches the preferences and the options again, for retry and pull-to-refresh.
  static Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      ref.read(datePreferencesProvider.notifier).load(),
      // A failure shows through the provider's error state, so it isn't rethrown here.
      ref.refresh(datePreferenceOptionsProvider(null).future).then((_) {}, onError: (_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(datePreferencesProvider);
    final options = ref.watch(datePreferenceOptionsProvider(null));

    // A failed load or refresh shows the error, even though the providers still hold the old
    // values, so the hub never shows summaries the server didn't just confirm.
    final Widget body;
    if (preferences.hasError && !preferences.isLoading) {
      body = _LoadError(error: preferences.error!, onRetry: () => _refresh(ref));
    } else if (options.hasError && !options.isLoading) {
      body = _LoadError(error: options.error!, onRetry: () => _refresh(ref));
    } else if ((preferences.valueOrNull, options.valueOrNull) case (final p?, final o?)) {
      body = RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: _Hub(preferences: p, options: o),
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

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
      body: body,
    );
  }
}

class _Hub extends StatelessWidget {
  final DatePreferences preferences;
  final DatePreferenceOptions options;

  const _Hub({required this.preferences, required this.options});

  /// Opens a section's [editor], or a placeholder while [enabled] is false. DP-F3 to DP-F6 each
  /// pass their editor and turn their flag on.
  void _open(
    BuildContext context, {
    required String title,
    required bool enabled,
    WidgetBuilder? editor,
  }) {
    final builder = enabled && editor != null
        ? editor
        : (BuildContext _) => _SectionPlaceholderScreen(title: title);
    Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }

  /// False when the activity in [category] is "Not for me", or the city doesn't offer it. Found
  /// by category, never by name, so a renamed activity still works.
  bool _offers(String category) {
    for (final activity in options.activities) {
      if (activity.category == category) {
        return preferences.levelFor(activity.activityId) != PreferenceLevel.no;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(_Copy.intro, style: TextStyle(fontSize: 15, color: Colors.grey[700])),
        if (!preferences.isSet) ...[
          const SizedBox(height: 16),
          const _NotSetBanner(),
        ],
        _Section(
          title: _Copy.where,
          lines: _whereLines(preferences.where, options),
          onTap: () => _open(context, title: _Copy.where, enabled: whereEditorEnabled),
        ),
        _Section(
          title: _Copy.dateTypes,
          lines: [
            for (final activity in options.activities)
              _LevelLine(
                name: activity.name,
                level: _Copy.level(preferences.levelFor(activity.activityId)),
              ),
          ],
          onTap: () => _open(
            context,
            title: _Copy.dateTypes,
            enabled: dateTypesEditorEnabled,
            editor: (_) =>
                EditDateTypesScreen(activities: options.activities, preferences: preferences),
          ),
        ),
        if (_offers('FOOD'))
          _Section(
            title: _Copy.dinner,
            lines: _foodLines(preferences.food, options),
            onTap: () => _open(context, title: _Copy.dinner, enabled: foodEditorEnabled),
          ),
        if (_offers('DRINKS'))
          _Section(
            title: _Copy.drinks,
            lines: _drinksLines(preferences.drinks, options),
            onTap: () => _open(context, title: _Copy.drinks, enabled: drinksEditorEnabled),
          ),
        _Section(
          title: _Copy.venue,
          lines: _venueLines(preferences.venue, options),
          onTap: () => _open(context, title: _Copy.venue, enabled: venueEditorEnabled),
        ),
      ],
    );
  }
}

// Summaries. Values are shown by their `displayName` from the options; a value the options
// don't list (one the server has since dropped) is left out rather than shown as a raw enum name.

List<Widget> _whereLines(WherePreferences where, DatePreferenceOptions options) {
  final distance = _distance(where.maxTravelMeters, options);
  final cities = [
    for (final city in where.cities)
      '${city.cityName} · ${_startLabel(city.start)}',
  ];
  if (cities.length == 1) return [Text('${cities.single} · $distance')];
  return [
    for (final city in cities) Text(city),
    Text(_capitalise(distance)),
  ];
}

String _startLabel(StartPoint? start) {
  final district = start?.district;
  if (district != null) return _Copy.near(district.name);
  return _Copy.cityCentre;
}

/// "up to 5 miles", in the city's unit, or "Anywhere". Uses the matching travel stop's label
/// when there is one; otherwise (a stop from another of the user's cities) converts the metres.
String _distance(int? meters, DatePreferenceOptions options) {
  if (meters == null) return _Copy.anywhere;
  for (final stop in options.travelStops) {
    if (stop.meters == meters) return _Copy.upTo(stop.label);
  }
  if (options.city?.distanceUnit == 'MI') {
    return _Copy.upTo(_Copy.miles(_oneDecimal(meters / 1609.344)));
  }
  return _Copy.upTo(_Copy.km(_oneDecimal(meters / 1000)));
}

String _oneDecimal(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble() ? rounded.toInt().toString() : rounded.toString();
}

List<Widget> _foodLines(FoodPreferences food, DatePreferenceOptions options) {
  final loved = _names(food.cuisinesLoved, options.cuisines);
  final excluded = _names(food.cuisinesExcluded, options.cuisines);
  final dietary = _names(food.dietaryNeeds, options.dietaryOptions);
  final cuisines = [
    if (loved.isNotEmpty) _Copy.loves(loved.join(', ')),
    if (excluded.isNotEmpty) _Copy.wontEat(excluded.join(', ')),
  ];
  return [
    Text(cuisines.isEmpty ? _Copy.anyCuisine : _capitalise(cuisines.join(' · '))),
    if (dietary.isNotEmpty) Text(dietary.join(', ')),
  ];
}

List<Widget> _drinksLines(DrinksPreferences drinks, DatePreferenceOptions options) {
  final styles = _names(drinks.drinkStyles, options.drinkStyles);
  return [
    Text(styles.isEmpty ? _Copy.anyBar : styles.join(', ')),
    if (drinks.wantsAlcoholFree) const Text(_Copy.alcoholFree),
  ];
}

List<Widget> _venueLines(VenuePreferences venue, DatePreferenceOptions options) {
  final atmosphere = _name(venue.atmosphere, options.atmospheres);
  final setting = _name(venue.setting, options.settings);
  final parts = [
    ?_priceRange(venue.priceRanges, options.priceRanges),
    if (atmosphere != null) _Copy.atmosphere(atmosphere),
    if (setting != null) _Copy.setting(setting),
  ];
  return [
    Text(parts.join(' · ')),
    Text(_Copy.stepFree(needed: venue.needsStepFree)),
  ];
}

/// The chosen price bands as the city's symbols: "££–£££" for a run of bands, "£, £££" when
/// there's a gap. Ordered as the options list them, cheapest first.
String? _priceRange(List<String> chosen, List<PriceRangeOption> bands) {
  final indexes = [
    for (var i = 0; i < bands.length; i++)
      if (chosen.contains(bands[i].value)) i,
  ];
  if (indexes.isEmpty) return null;
  final isRun = indexes.last - indexes.first == indexes.length - 1;
  if (indexes.length > 1 && isRun) {
    return '${bands[indexes.first].symbol}–${bands[indexes.last].symbol}';
  }
  return indexes.map((i) => bands[i].symbol).join(', ');
}

List<String> _names(List<String> values, List<OptionValue> options) => [
      for (final value in values) ?_name(value, options),
    ];

String? _name(String value, List<OptionValue> options) {
  for (final option in options) {
    if (option.value == value) return option.displayName;
  }
  return null;
}

String _capitalise(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

class _NotSetBanner extends StatelessWidget {
  const _NotSetBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryOrange.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_outlined, color: AppColors.accentOrange),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              _Copy.notSetBanner,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// One section: a heading, then a card with its summary lines and a chevron. The whole card
/// opens the section's editor.
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> lines;
  final VoidCallback onTap;

  const _Section({required this.title, required this.lines, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        // Its own node, so the button reads the summary and not the heading above it.
        Semantics(
          container: true,
          button: true,
          hint: _Copy.editHint(title),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(fontSize: 16, color: Colors.black),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < lines.length; i++) ...[
                              if (i > 0) const SizedBox(height: 6),
                              lines[i],
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A "Date types" line: the activity's name and the user's level for it.
class _LevelLine extends StatelessWidget {
  final String name;
  final String level;

  const _LevelLine({required this.name, required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(name)),
        Text(level, style: TextStyle(color: Colors.grey[700])),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _LoadError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = error is DatePreferencesRepositoryException
        ? (error as DatePreferencesRepositoryException).message
        : _Copy.loadError;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text(_Copy.retry)),
          ],
        ),
      ),
    );
  }
}

/// Stands in for a section's editor until it lands.
class _SectionPlaceholderScreen extends StatelessWidget {
  final String title;

  const _SectionPlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
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
        title: Text(title, style: const TextStyle(color: Colors.black)),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(_Copy.placeholder, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
