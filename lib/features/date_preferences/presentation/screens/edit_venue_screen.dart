import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preference_options.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/domain/models/section_patch.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preferences_provider.dart';
import 'package:eros_app/features/date_preferences/presentation/screens/detail_sections_copy.dart';
import 'package:eros_app/features/date_preferences/presentation/widgets/preference_choice_widgets.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_section_scaffold.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/single_choice_editor.dart';

/// "The venue" editor (RFC-005 §4.2): price bands as chips with the city's symbols (at least
/// one), atmosphere and setting as single choices (all soft), and "I need step-free access"
/// (hard). Save sends only a [VenuePatch].
class EditVenueScreen extends ConsumerStatefulWidget {
  final DatePreferences preferences;
  final DatePreferenceOptions options;

  const EditVenueScreen({super.key, required this.preferences, required this.options});

  @override
  ConsumerState<EditVenueScreen> createState() => _EditVenueScreenState();
}

class _EditVenueScreenState extends ConsumerState<EditVenueScreen> {
  late final VenuePreferences _saved = widget.preferences.venue;
  late VenuePreferences _draft = _saved;

  bool get _isDirty => _draft != _saved;

  /// Keeps the bands in the options' order, cheapest first, and never lets the last one go.
  void _togglePrice(String band) {
    final picked = _draft.priceRanges;
    if (picked.contains(band)) {
      if (picked.length == 1) return;
      setState(() => _draft = _draft.copyWith(priceRanges: [...picked]..remove(band)));
      return;
    }
    final order = [for (final option in widget.options.priceRanges) option.value];
    final next = [...picked, band]
      ..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    setState(() => _draft = _draft.copyWith(priceRanges: next));
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.options;
    return EditSectionScaffold(
      title: DetailSectionsCopy.venue,
      isDirty: _isDirty,
      canSave: _isDirty && _draft.priceRanges.isNotEmpty,
      onSave: () => ref.read(datePreferencesProvider.notifier).saveSection(VenuePatch(_draft)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          const _Heading(DetailSectionsCopy.price),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: PreferenceHint(DetailSectionsCopy.priceHint),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final band in options.priceRanges)
                  _PriceChip(
                    band: band,
                    isSelected: _draft.priceRanges.contains(band.value),
                    onTap: () => _togglePrice(band.value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const _Heading(DetailSectionsCopy.atmosphere),
          _SingleChoice(
            choices: options.atmospheres,
            selected: _draft.atmosphere,
            onSelected: (value) => setState(() => _draft = _draft.copyWith(atmosphere: value)),
          ),
          const SizedBox(height: 20),
          const _Heading(DetailSectionsCopy.setting),
          _SingleChoice(
            choices: options.settings,
            selected: _draft.setting,
            onSelected: (value) => setState(() => _draft = _draft.copyWith(setting: value)),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: PreferenceSwitchTile(
              label: DetailSectionsCopy.stepFree,
              value: _draft.needsStepFree,
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(needsStepFree: value)),
            ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: EditQuestion(text),
    );
  }
}

/// A price band as a chip showing its symbol ("££"). Screen readers hear its name instead.
class _PriceChip extends StatelessWidget {
  final PriceRangeOption band;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriceChip({required this.band, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(band.symbol, semanticsLabel: band.displayName),
      tooltip: band.displayName,
      selected: isSelected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

/// One of the options' single-choice lists (atmosphere or setting) as radio cards.
class _SingleChoice extends StatelessWidget {
  final List<OptionValue> choices;
  final String selected;
  final ValueChanged<String> onSelected;

  const _SingleChoice({required this.choices, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: SingleChoiceEditor<String>(
        values: choices.values,
        selected: selected,
        labelOf: choices.labelOf,
        onSelected: onSelected,
      ),
    );
  }
}
