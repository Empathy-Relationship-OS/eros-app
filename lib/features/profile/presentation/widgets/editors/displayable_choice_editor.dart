import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/single_choice_editor.dart';

/// Radio cards for a `DisplayableField` enum, followed by a "Show on my profile" checkbox
/// (RFC-004 §6.2).
///
/// Controlled: it holds no state. The wrapping screen owns [selected] and [visible] and
/// updates them from [onSelected] and [onVisibleChanged].
///
/// When [preferNotToSay] is given and selected, the checkbox is hidden, and the value must be
/// saved hidden: use [effectiveVisible] when building the `DisplayableField`.
///
/// The cards scroll in an `Expanded`, so this must be a direct child of a `Column` (it fills
/// the space left above the screen's buttons).
class DisplayableChoiceEditor<T extends Enum> extends StatelessWidget {
  final List<T> values;
  final T? selected;
  final bool visible;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;
  final ValueChanged<bool> onVisibleChanged;
  final T? preferNotToSay;

  const DisplayableChoiceEditor({
    super.key,
    required this.values,
    required this.selected,
    required this.visible,
    required this.labelOf,
    required this.onSelected,
    required this.onVisibleChanged,
    this.preferNotToSay,
  });

  /// The visibility to save: always false when "prefer not to say" is selected.
  static bool effectiveVisible(Object? selected, bool visible, Object? preferNotToSay) =>
      preferNotToSay != null && selected == preferNotToSay ? false : visible;

  bool get _showCheckbox => preferNotToSay == null || selected != preferNotToSay;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              children: [
                for (final value in values)
                  ChoiceOptionCard(
                    label: labelOf(value),
                    isSelected: selected == value,
                    onTap: () => onSelected(value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_showCheckbox)
            CheckboxListTile(
              value: visible,
              onChanged: (value) => onVisibleChanged(value ?? true),
              title: const Text('Show on my profile'),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
          if (_showCheckbox) const SizedBox(height: 16),
        ],
      ),
    );
  }
}
