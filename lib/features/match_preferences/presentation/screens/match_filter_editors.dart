import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_filter.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preference_options.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preferences.dart';

/// Opens [filter]'s editor from the Match preferences hub.
Future<void> openMatchFilterEditor(
  BuildContext context, {
  required MatchFilter filter,
  required MatchPreferences preferences,
  required MatchPreferenceOptions options,
}) {
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => matchFilterEditor(filter, preferences: preferences, options: options),
  ));
}

/// The editor for each filter: the one place the hub's rows are wired to their screens.
///
/// Every case opens a placeholder until its editor lands. MP-F4 replaces each one with its
/// `EditSectionScaffold` editor (RFC-007 §6.3).
Widget matchFilterEditor(
  MatchFilter filter, {
  required MatchPreferences preferences,
  required MatchPreferenceOptions options,
}) {
  return switch (filter) {
    // Interested in reuses MP-F2's InterestedInScreen, which isn't merged yet. MP-F2 or MP-F4
    // wires it here.
    MatchFilter.gender => MatchFilterPlaceholderScreen(filter: filter),
    MatchFilter.age => MatchFilterPlaceholderScreen(filter: filter),
    MatchFilter.distance => MatchFilterPlaceholderScreen(filter: filter),
    MatchFilter.height => MatchFilterPlaceholderScreen(filter: filter),
    MatchFilter.ethnicity => MatchFilterPlaceholderScreen(filter: filter),
    MatchFilter.religion => MatchFilterPlaceholderScreen(filter: filter),
    MatchFilter.relationshipType => MatchFilterPlaceholderScreen(filter: filter),
    MatchFilter.dateIntentions => MatchFilterPlaceholderScreen(filter: filter),
    MatchFilter.kidsPreference => MatchFilterPlaceholderScreen(filter: filter),
    MatchFilter.smokingStatus => MatchFilterPlaceholderScreen(filter: filter),
    MatchFilter.alcoholConsumption => MatchFilterPlaceholderScreen(filter: filter),
  };
}

/// Stands in for a filter's editor until it lands.
class MatchFilterPlaceholderScreen extends StatelessWidget {
  final MatchFilter filter;

  const MatchFilterPlaceholderScreen({super.key, required this.filter});

  static const placeholder = 'You\'ll be able to change this soon.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(filter.label, style: const TextStyle(color: Colors.black)),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(placeholder, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
