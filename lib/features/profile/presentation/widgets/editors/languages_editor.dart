import 'package:flutter/material.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/single_choice_editor.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/constants/languages.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/multi_choice_editor.dart';

/// The spoken-languages list: a [MultiChoiceEditor] in list layout, one row per language with
/// its flag and native name (RFC-004 §6.2).
///
/// Controlled, like [MultiChoiceEditor]. It lists [Languages.all], plus any selected language
/// the app doesn't list yet (`Language.unsupported`, eros-app#17), so saving never drops it.
/// It has no maximum; the screen decides how many are required.
///
/// This returns an `Expanded`, so it must be a direct child of a `Column`.
class LanguagesEditor extends StatelessWidget {
  final List<Language> selected;
  final ValueChanged<List<Language>> onChanged;

  const LanguagesEditor({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MultiChoiceEditor<Language>(
      options: Languages.all,
      selected: selected,
      labelOf: (language) => language.name,
      onChanged: onChanged,
      listTileBuilder: (context, language, isSelected, onTap) => LanguageOptionTile(
        language: language,
        isSelected: isSelected,
        onTap: onTap,
      ),
    );
  }
}

/// One row of [LanguagesEditor].
class LanguageOptionTile extends StatelessWidget {
  final Language language;
  final bool isSelected;
  final VoidCallback? onTap;

  const LanguageOptionTile({
    super.key,
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: choiceCardDecoration(isSelected: isSelected),
          child: Row(
            children: [
              Text(
                language.flag,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            height: 1.3,
                          ),
                    ),
                    Text(
                      language.nativeName,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary, height: 1.3),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: AppColors.primaryDeep),
            ],
          ),
        ),
      ),
    );
  }
}
