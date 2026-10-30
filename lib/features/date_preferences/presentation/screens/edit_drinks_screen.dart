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

/// The "Drinks" editor (RFC-005 §4.2): kinds of bar (none picked means any) and "Good
/// alcohol-free options matter to me". Both are soft. Save sends only a [DrinksPatch].
///
/// While the user has never saved date preferences (`isSet` false) and the profile's alcohol
/// answer is "Never", alcohol-free is switched on and marked "Suggested from your profile". It
/// is saved only by Save.
class EditDrinksScreen extends ConsumerStatefulWidget {
  final DatePreferences preferences;
  final DatePreferenceOptions options;

  const EditDrinksScreen({super.key, required this.preferences, required this.options});

  @override
  ConsumerState<EditDrinksScreen> createState() => _EditDrinksScreenState();
}

class _EditDrinksScreenState extends ConsumerState<EditDrinksScreen> {
  late final DrinksPreferences _saved = widget.preferences.drinks;

  /// What the screen opened with: the saved section plus any suggestion.
  late DrinksPreferences _initial = _saved;
  late DrinksPreferences _draft = _saved;
  bool _suggestedAlcoholFree = false;

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
        if (profile != null && !_suggestedAlcoholFree && _draft == _saved) {
          setState(() => _suggest(profile));
        }
      });
    }
  }

  void _suggest(MyProfile profile) {
    if (_saved.wantsAlcoholFree || !suggestsAlcoholFree(profile)) return;
    _suggestedAlcoholFree = true;
    _draft = _initial = _saved.copyWith(wantsAlcoholFree: true);
  }

  bool get _hasChanges => _draft != _saved;

  /// Leaving asks first only about the user's own changes. An unsaved suggestion just goes away.
  bool get _isDirty => _hasChanges && _draft != _initial;

  @override
  Widget build(BuildContext context) {
    final styles = widget.options.drinkStyles;
    return EditSectionScaffold(
      title: DetailSectionsCopy.drinks,
      isDirty: _isDirty,
      canSave: _hasChanges,
      onSave: () => ref.read(datePreferencesProvider.notifier).saveSection(DrinksPatch(_draft)),
      body: Column(
        children: [
          MultiChoiceEditor<String>(
            options: styles.values,
            selected: _draft.drinkStyles,
            labelOf: styles.labelOf,
            onChanged: (picked) => setState(() => _draft = _draft.copyWith(drinkStyles: picked)),
            header: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EditQuestion(DetailSectionsCopy.barStyles),
                SizedBox(height: 8),
                PreferenceHint(DetailSectionsCopy.barStylesHint),
              ],
            ),
            listTileBuilder: (context, style, isSelected, onTap) => PreferenceChoiceTile(
              label: styles.labelOf(style),
              isSelected: isSelected,
              onTap: onTap,
            ),
          ),
          const Divider(height: 1),
          PreferenceSwitchTile(
            label: DetailSectionsCopy.alcoholFree,
            value: _draft.wantsAlcoholFree,
            onChanged: (value) =>
                setState(() => _draft = _draft.copyWith(wantsAlcoholFree: value)),
            note: _suggestedAlcoholFree && _draft.wantsAlcoholFree
                ? DetailSectionsCopy.suggested
                : null,
          ),
        ],
      ),
    );
  }
}
