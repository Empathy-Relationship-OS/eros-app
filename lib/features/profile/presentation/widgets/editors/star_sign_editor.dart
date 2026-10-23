import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/domain/enums/personality.dart';

/// Optional star sign: a 3-column grid, plus "Show on my profile" once one is chosen
/// (RFC-004 §6.2).
///
/// Controlled: the wrapping screen owns [selected] and [visible]. Tapping the selected sign
/// clears it ([onSelected] with null). It scrolls by itself, so it suits a tab view or an
/// `Expanded`.
class StarSignEditor extends StatelessWidget {
  final StarSign? selected;
  final bool visible;
  final ValueChanged<StarSign?> onSelected;
  final ValueChanged<bool> onVisibleChanged;

  const StarSignEditor({
    super.key,
    required this.selected,
    required this.visible,
    required this.onSelected,
    required this.onVisibleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Text(
          'What\'s your star sign?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Optional - skip if you prefer',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2,
          ),
          itemCount: StarSign.values.length,
          itemBuilder: (context, index) {
            final sign = StarSign.values[index];
            final isSelected = selected == sign;

            return InkWell(
              onTap: () => onSelected(isSelected ? null : sign),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    sign.displayName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
        ),
        if (selected != null) ...[
          const SizedBox(height: 24),
          CheckboxListTile(
            value: visible,
            onChanged: (value) => onVisibleChanged(value ?? true),
            title: const Text('Show on my profile'),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }
}
