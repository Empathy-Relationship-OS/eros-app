import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';

/// A three-way control for how much a user wants one kind of date: "Love it", "Happy to" or
/// "Not for me" (RFC-005 §4.2, "Date types").
///
/// Controlled: it holds no state. Tapping a choice calls [onChanged], and the wrapping screen
/// passes the new value back in as [value].
class PreferenceLevelSelector extends StatelessWidget {
  final PreferenceLevel value;
  final ValueChanged<PreferenceLevel> onChanged;

  /// What the choices are for, such as the activity's name, read before them by screen readers.
  final String? semanticLabel;

  const PreferenceLevelSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  /// The text shown for [level].
  static String labelOf(PreferenceLevel level) => switch (level) {
        PreferenceLevel.love => 'Love it',
        PreferenceLevel.ok => 'Happy to',
        PreferenceLevel.no => 'Not for me',
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<PreferenceLevel>(
          segments: [
            for (final level in PreferenceLevel.values)
              ButtonSegment(
                value: level,
                label: Text(labelOf(level), maxLines: 1, softWrap: false),
              ),
          ],
          selected: {value},
          onSelectionChanged: (selected) => onChanged(selected.single),
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: Colors.black,
            selectedForegroundColor: Colors.black,
            selectedBackgroundColor: AppColors.primary.withValues(alpha: 0.2),
            side: BorderSide(color: Colors.grey[300]!),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
