import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/match_preferences/data/match_preferences_repository.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_patch.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preference_options_provider.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preferences_provider.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/interested_in_screen.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';

/// Asks Interested in as a full-height sheet that can't be dismissed without answering (RFC-007
/// §6.5). For a user with no match preferences yet: `GET /match/` answered 409
/// `MATCH_PREFERENCES_REQUIRED`.
///
/// Completes once the choice is saved.
Future<void> showInterestedInSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    builder: (_) => const InterestedInSheet(),
  );
}

/// The sheet's content: [InterestedInScreen] with `suggestedGenders` from options pre-ticked, which
/// saves through [MatchPreferencesNotifier.save] and then closes.
class InterestedInSheet extends ConsumerWidget {
  const InterestedInSheet({super.key});

  Future<void> _save(BuildContext context, WidgetRef ref, List<Gender> genders) async {
    try {
      await ref.read(matchPreferencesProvider.notifier).save(GenderPatch(genders));
    } on MatchPreferencesSavedException {
      // Saved: only the response couldn't be read, so the batch will load now.
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(matchPreferenceOptionsProvider);
    // Back can't close it either: only a saved answer does.
    return PopScope(
      canPop: false,
      child: options.when(
        data: (options) => _screen(context, ref, options.suggestedGenders),
        // Without options there's no suggestion, but the question can still be answered.
        error: (_, _) => _screen(context, ref, const []),
        loading: () => const Scaffold(
          backgroundColor: Colors.white,
          body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ),
    );
  }

  Widget _screen(BuildContext context, WidgetRef ref, List<Gender> suggestion) {
    return InterestedInScreen(
      initialSelection: suggestion,
      showBack: false,
      onContinue: (genders) => _save(context, ref, genders),
    );
  }
}
