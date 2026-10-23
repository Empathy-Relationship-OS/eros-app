import 'package:flutter/material.dart';
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.primary : Colors.grey[400],
              ),
              const SizedBox(width: 16),
              // Flexible: a long label wraps instead of overflowing. It changes nothing when the
              // label fits.
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.primary : Colors.black,
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
