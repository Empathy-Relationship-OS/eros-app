import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/theme/app_colors.dart';

/// A list of radio cards, one per value, with [selected] highlighted (RFC-004 §6.2).
///
/// Controlled: it holds no state. Tapping a card calls [onSelected], and the wrapping screen
/// passes the new value back in as [selected]. It knows nothing about drafts, providers or
/// routes, so onboarding and the profile editor can both wrap it.
///
/// It sizes to its cards and doesn't wrap itself in an `Expanded`, so a screen can follow it
/// with a `Spacer`.
class SingleChoiceEditor<T> extends StatelessWidget {
  final List<T> values;
  final T? selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  const SingleChoiceEditor({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final value in values)
          ChoiceOptionCard(
            label: labelOf(value),
            isSelected: selected == value,
            onTap: () => onSelected(value),
          ),
      ],
    );
  }
}

/// How every "pick one" card in the editors looks: white with a border, and a tint with a deep
/// coral border when it's the chosen one. The label stays ink either way.
BoxDecoration choiceCardDecoration({required bool isSelected}) {
  return BoxDecoration(
    color: isSelected ? AppColors.primaryTint : AppColors.cardBackground,
    borderRadius: BorderRadius.circular(AppRadius.input),
    border: Border.all(
      color: isSelected ? AppColors.primaryDeep : AppColors.border,
      width: 1.5,
    ),
  );
}

/// How a grid tile you can pick several of looks: a coral fill with ink text when picked, white
/// with a border otherwise, and greyed out when [isDisabled].
BoxDecoration choiceTileDecoration({required bool isSelected, bool isDisabled = false}) {
  return BoxDecoration(
    color: isSelected
        ? AppColors.primary
        : (isDisabled ? AppColors.disabled : AppColors.cardBackground),
    borderRadius: BorderRadius.circular(AppRadius.input),
    border: Border.all(
      color: isSelected ? AppColors.primary : (isDisabled ? AppColors.disabled : AppColors.border),
      width: 1.5,
    ),
  );
}

/// The label of a [choiceTileDecoration] tile.
TextStyle? choiceTileTextStyle(
  BuildContext context, {
  required bool isSelected,
  bool isDisabled = false,
}) {
  return Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: isSelected
            ? AppColors.textOnPrimary
            : (isDisabled ? AppColors.disabledText : AppColors.textPrimary),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        height: 1.25,
      );
}

/// One radio card of a [SingleChoiceEditor] or `DisplayableChoiceEditor`.
class ChoiceOptionCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const ChoiceOptionCard({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: choiceCardDecoration(isSelected: isSelected),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.primaryDeep : AppColors.textTertiary,
              ),
              const SizedBox(width: 16),
              // Flexible: a long label wraps instead of overflowing. It changes nothing when the
              // label fits.
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        height: 1.3,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
