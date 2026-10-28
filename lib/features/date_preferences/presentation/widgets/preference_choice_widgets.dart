import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preference_options.dart';

/// Reads an option list from `GET /date-preferences/options` by value, so editors can work with
/// the plain value strings the preferences hold.
extension OptionValueLabels on List<OptionValue> {
  List<String> get values => [for (final option in this) option.value];

  /// The option's `displayName`. A value the options no longer list (one the server has since
  /// dropped) shows as itself, so the user can still see and remove it.
  String labelOf(String value) {
    for (final option in this) {
      if (option.value == value) return option.displayName;
    }
    return value;
  }
}

/// One row of a date preference multi-select, for `MultiChoiceEditor.listTileBuilder`: a
/// checkbox, the option's label, and an optional [note] under it ("Suggested from your
/// profile"). Greyed out when [onTap] is null: the maximum is reached, or the option is taken by
/// another list.
class PreferenceChoiceTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final String? note;

  const PreferenceChoiceTile({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: onTap == null ? null : (_) => onTap(),
        title: Text(label),
        subtitle: note == null ? null : Text(note!),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.primary,
      ),
    );
  }
}

/// A yes/no date preference, such as "I need step-free access", with an optional [note] under
/// it.
class PreferenceSwitchTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? note;

  const PreferenceSwitchTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label),
      subtitle: note == null ? null : Text(note!),
      activeTrackColor: AppColors.primary,
    );
  }
}

/// A short grey line under a heading, explaining what a choice does.
class PreferenceHint extends StatelessWidget {
  final String text;

  const PreferenceHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 15, color: Colors.grey[700]));
  }
}
