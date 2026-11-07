import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_patch.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_values.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_filter.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preference_options.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preferences.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preferences_provider.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/edit_age_screen.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/edit_distance_screen.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/edit_height_screen.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/edit_value_filter_screen.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/interested_in_screen.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';

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

/// The editor for each filter: the one place the hub's rows are wired to their screens
/// (RFC-007 §6.3).
///
/// Each editor starts from [preferences] as the server last returned them, saves only its own
/// filter with [MatchPreferencesNotifier.save], and closes; the hub then shows the server's
/// response. Value filters use the Edit profile screen's labels (primer rule 16).
Widget matchFilterEditor(
  MatchFilter filter, {
  required MatchPreferences preferences,
  required MatchPreferenceOptions options,
}) {
  final title = filter.label;
  return switch (filter) {
    MatchFilter.gender => InterestedInEditor(initial: preferences.gender),
    MatchFilter.age => EditAgeScreen(initial: preferences.age, bounds: options.age),
    MatchFilter.distance =>
      EditDistanceScreen(initial: preferences.distance, options: options.distance),
    MatchFilter.height => EditHeightScreen(initial: preferences.height, bounds: options.height),
    MatchFilter.ethnicity => EditValueFilterScreen(
        title: title,
        initial: preferences.ethnicity,
        choices: FilterValues.ethnicity,
        labelOf: (value) => value.displayName,
        patchOf: EthnicityPatch.new,
      ),
    MatchFilter.religion => EditValueFilterScreen(
        title: title,
        initial: preferences.religion,
        choices: FilterValues.religion,
        labelOf: (value) => value.displayName,
        patchOf: ReligionPatch.new,
      ),
    MatchFilter.relationshipType => EditValueFilterScreen(
        title: title,
        initial: preferences.relationshipType,
        choices: FilterValues.relationshipType,
        labelOf: (value) => value.displayName,
        patchOf: RelationshipTypePatch.new,
      ),
    MatchFilter.dateIntentions => EditValueFilterScreen(
        title: title,
        initial: preferences.dateIntentions,
        choices: FilterValues.dateIntentions,
        labelOf: (value) => value.displayName,
        patchOf: DateIntentionsPatch.new,
      ),
    MatchFilter.kidsPreference => EditValueFilterScreen(
        title: title,
        initial: preferences.kidsPreference,
        choices: FilterValues.kidsPreference,
        labelOf: (value) => value.displayName,
        patchOf: KidsPreferencePatch.new,
      ),
    MatchFilter.smokingStatus => EditValueFilterScreen(
        title: title,
        initial: preferences.smokingStatus,
        choices: FilterValues.smokingStatus,
        labelOf: (value) => value.displayName,
        patchOf: SmokingStatusPatch.new,
      ),
    MatchFilter.alcoholConsumption => EditValueFilterScreen(
        title: title,
        initial: preferences.alcoholConsumption,
        choices: FilterValues.alcoholConsumption,
        labelOf: (value) => value.displayName,
        patchOf: AlcoholConsumptionPatch.new,
      ),
  };
}

/// Interested in from the hub: MP-F2's [InterestedInScreen] with the saved genders ticked, which
/// saves [GenderPatch] and closes. Always a dealbreaker (D-4), so there's no switch.
class InterestedInEditor extends ConsumerWidget {
  /// The filter as the server last returned it. Null values (everyone) tick every gender.
  final ValueFilter<Gender> initial;

  const InterestedInEditor({super.key, required this.initial});

  Future<void> _save(BuildContext context, WidgetRef ref, List<Gender> genders) async {
    await ref.read(matchPreferencesProvider.notifier).save(GenderPatch(genders));
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InterestedInScreen(
      initialSelection: initial.values ?? FilterValues.gender.choices,
      onContinue: (genders) => _save(context, ref, genders),
    );
  }
}
