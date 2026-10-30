import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preference_options.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/domain/models/section_patch.dart';
import 'package:eros_app/features/date_preferences/domain/profile_suggestions.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preferences_provider.dart';
import 'package:eros_app/features/date_preferences/presentation/screens/detail_sections_copy.dart';
import 'package:eros_app/features/date_preferences/presentation/widgets/preference_choice_widgets.dart';
import 'package:eros_app/features/profile/domain/models/my_profile.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_section_scaffold.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/multi_choice_editor.dart';

/// The "Dinner" editor (RFC-005 §4.2), one tab per list: cuisines the user loves (soft),
/// cuisines they won't eat (a hard block, D-13) and dietary needs (hard). A cuisine can't be in
/// both cuisine lists, and each is capped by `options.limits`. Save sends only a [FoodPatch].
///
/// While the user has never saved date preferences (`isSet` false), dietary needs that follow
/// from the profile's diet are ticked and marked "Suggested from your profile". They are saved
/// only by Save, and the screen opens on their tab so the user sees them.
class EditFoodScreen extends ConsumerStatefulWidget {
  final DatePreferences preferences;
  final DatePreferenceOptions options;

  const EditFoodScreen({super.key, required this.preferences, required this.options});

  @override
  ConsumerState<EditFoodScreen> createState() => _EditFoodScreenState();
}

class _EditFoodScreenState extends ConsumerState<EditFoodScreen>
    with SingleTickerProviderStateMixin {
  static const _dietaryTab = 2;

  late final TabController _tabController = TabController(length: 3, vsync: this);
  late final FoodPreferences _saved = widget.preferences.food;

  /// What the screen opened with: the saved section plus any suggestions.
  late FoodPreferences _initial = _saved;
  late FoodPreferences _draft = _saved;
  List<String> _suggested = const [];

  @override
  void initState() {
    super.initState();
    if (widget.preferences.isSet) return;
    final profile = ref.read(myProfileProvider).valueOrNull;
    if (profile != null) {
      _suggest(profile);
    } else {
      // The profile may still be loading: suggest once it arrives, unless the user has started.
      ref.listenManual(myProfileProvider, (_, next) {
        final profile = next.valueOrNull;
        if (profile != null && _suggested.isEmpty && _draft == _saved) {
          setState(() => _suggest(profile));
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _suggest(MyProfile profile) {
    final needs = suggestedDietaryNeeds(profile, widget.options.dietaryOptions)
        .where((need) => !_saved.dietaryNeeds.contains(need))
        .toList();
    if (needs.isEmpty) return;
    _suggested = needs;
    _draft = _initial = _saved.copyWith(dietaryNeeds: [..._saved.dietaryNeeds, ...needs]);
    _tabController.index = _dietaryTab;
  }

  bool get _isValid {
    final limits = widget.options.limits;
    return _draft.cuisinesLoved.length <= limits.maxCuisinesLoved &&
        _draft.cuisinesExcluded.length <= limits.maxCuisinesExcluded &&
        !_draft.cuisinesLoved.any(_draft.cuisinesExcluded.contains);
  }

  bool get _hasChanges => _draft != _saved;

  /// Leaving asks first only about the user's own changes. Unsaved suggestions just go away.
  bool get _isDirty => _hasChanges && _draft != _initial;

  @override
  Widget build(BuildContext context) {
    final options = widget.options;
    return EditSectionScaffold(
      title: DetailSectionsCopy.dinner,
      isDirty: _isDirty,
      canSave: _hasChanges && _isValid,
      onSave: () => ref.read(datePreferencesProvider.notifier).saveSection(FoodPatch(_draft)),
      appBarBottom: multiChoiceTabBar(
        controller: _tabController,
        labels: const [
          DetailSectionsCopy.cuisinesLoved,
          DetailSectionsCopy.cuisinesExcluded,
          DetailSectionsCopy.dietaryNeeds,
        ],
        isScrollable: true,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CuisineList(
            cuisines: options.cuisines,
            selected: _draft.cuisinesLoved,
            max: options.limits.maxCuisinesLoved,
            taken: _draft.cuisinesExcluded,
            takenNote: DetailSectionsCopy.inExcluded,
            onChanged: (loved) => setState(() => _draft = _draft.copyWith(cuisinesLoved: loved)),
          ),
          _CuisineList(
            cuisines: options.cuisines,
            selected: _draft.cuisinesExcluded,
            max: options.limits.maxCuisinesExcluded,
            taken: _draft.cuisinesLoved,
            takenNote: DetailSectionsCopy.inLoved,
            hint: DetailSectionsCopy.excludedHint,
            onChanged: (excluded) =>
                setState(() => _draft = _draft.copyWith(cuisinesExcluded: excluded)),
          ),
          Column(
            children: [
              MultiChoiceEditor<String>(
                options: options.dietaryOptions.values,
                selected: _draft.dietaryNeeds,
                labelOf: options.dietaryOptions.labelOf,
                onChanged: (needs) =>
                    setState(() => _draft = _draft.copyWith(dietaryNeeds: needs)),
                listTileBuilder: (context, need, isSelected, onTap) => PreferenceChoiceTile(
                  label: options.dietaryOptions.labelOf(need),
                  isSelected: isSelected,
                  onTap: onTap,
                  note: isSelected && _suggested.contains(need)
                      ? DetailSectionsCopy.suggested
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One cuisine tab: up to [max] of [cuisines], with a search field and counter. Cuisines in
/// [taken] (the other list) are greyed out with [takenNote].
class _CuisineList extends StatelessWidget {
  final List<OptionValue> cuisines;
  final List<String> selected;
  final int max;
  final List<String> taken;
  final String takenNote;
  final String? hint;
  final ValueChanged<List<String>> onChanged;

  const _CuisineList({
    required this.cuisines,
    required this.selected,
    required this.max,
    required this.taken,
    required this.takenNote,
    this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return Column(
      children: [
        MultiChoiceEditor<String>(
          options: cuisines.values,
          selected: selected,
          labelOf: cuisines.labelOf,
          max: max,
          onChanged: onChanged,
          header: hint == null
              ? null
              : Padding(padding: const EdgeInsets.only(bottom: 16), child: PreferenceHint(hint)),
          searchHint: DetailSectionsCopy.searchCuisines,
          showCounter: true,
          listTileBuilder: (context, cuisine, isSelected, onTap) {
            final isTaken = taken.contains(cuisine);
            return PreferenceChoiceTile(
              label: cuisines.labelOf(cuisine),
              isSelected: isSelected,
              onTap: isTaken ? null : onTap,
              note: isTaken ? takenNote : null,
            );
          },
        ),
      ],
    );
  }
}
