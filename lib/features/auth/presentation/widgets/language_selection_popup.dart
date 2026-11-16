import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/languages.dart';
import 'language_selector_button.dart';

/// Language Selection Popup - Bottom sheet with list of available languages
/// Reference: screenshots/login/create-user/84623CD3-B81C-46DF-84FD-5F2C81BC72D9_1_105_c.jpeg
class LanguageSelectionPopup extends ConsumerWidget {
  const LanguageSelectionPopup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedLanguage = ref.watch(selectedLanguageProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Select Language',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),

            const SizedBox(height: 16),

            // Language list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: AppLanguages.all.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final language = AppLanguages.all[index];
                  final isSelected = language.code == selectedLanguage.code;

                  return ListTile(
                    leading: Text(
                      language.flag,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    title: Text(
                      language.nativeName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      language.name,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.primaryDeep,
                          )
                        : null,
                    onTap: () {
                      // Update selected language
                      ref.read(selectedLanguageProvider.notifier).state =
                          language;
                      // TODO: Save to SharedPreferences
                      // Close popup
                      Navigator.pop(context);
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
