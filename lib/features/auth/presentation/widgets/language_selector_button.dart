import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/languages.dart';
import 'language_selection_popup.dart';

/// Provider for selected language
final selectedLanguageProvider = StateProvider<AppLanguage>((ref) {
  // Default to English - TODO: Load from SharedPreferences
  return AppLanguages.all.first;
});

/// Language Selector Button - Shows current language and opens popup
/// Reference: screenshots/login/create-user/8BA764E5-5619-47B6-BB51-C270658D3C33_1_105_c.jpeg
class LanguageSelectorButton extends ConsumerWidget {
  const LanguageSelectorButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedLanguage = ref.watch(selectedLanguageProvider);

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const LanguageSelectionPopup(),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Globe icon
            const Icon(
              Icons.language,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            // Language code
            Text(
              selectedLanguage.code.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
