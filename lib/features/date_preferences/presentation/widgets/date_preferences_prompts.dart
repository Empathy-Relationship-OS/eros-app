import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preferences_prompt_providers.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preferences_provider.dart';
import 'package:eros_app/features/date_preferences/presentation/screens/date_preferences_screen.dart';

/// Every string the date preference prompts (RFC-005 §6.3) show.
abstract final class DatePreferencesPromptCopy {
  static const sheetTitle = 'Set your date preferences?';
  static const sheetBody = 'It takes about a minute.';
  static const sheetSetNow = 'Set them now';
  static const sheetLater = 'Later';

  static const cardTitle = 'Tell us what dates you like';
  static const cardDismiss = 'Dismiss';

  static const rankingLink = 'Not your kind of place? Update your preferences for next time';
}

/// Opens the Date preferences hub.
Future<void> openDatePreferences(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const DatePreferencesScreen()),
  );
}

/// Shows "Set your date preferences?" over [child] the first time it appears for a signed-in user
/// whose preferences aren't set (RFC-005 §6.3, D-17). The home screen wraps itself in this, so
/// the first landing after onboarding asks once.
///
/// "Shown" is stored per uid as soon as the sheet opens, so it never shows twice for that user on
/// this device, however it is closed. Once stored, preferences aren't fetched for it again. If
/// the preferences are already set it is stored too, without showing. If loading them fails,
/// nothing is stored and the next home screen tries again.
class DatePreferencesFirstRunSheet extends ConsumerStatefulWidget {
  final Widget child;

  const DatePreferencesFirstRunSheet({super.key, required this.child});

  @override
  ConsumerState<DatePreferencesFirstRunSheet> createState() =>
      _DatePreferencesFirstRunSheetState();
}

class _DatePreferencesFirstRunSheetState extends ConsumerState<DatePreferencesFirstRunSheet> {
  ProviderSubscription<AsyncValue<DatePreferences>>? _subscription;
  bool _decided = false;

  @override
  void initState() {
    super.initState();
    final uid = ref.read(datePreferencesPromptUidProvider);
    if (uid == null || ref.read(datePreferencesPromptStoreProvider).hasShownSheet(uid)) return;
    _subscription = ref.listenManual<AsyncValue<DatePreferences>>(
      datePreferencesProvider,
      (_, next) => _onPreferences(uid, next),
      fireImmediately: true,
    );
    if (_decided) _subscription?.close();
  }

  void _onPreferences(String uid, AsyncValue<DatePreferences> next) {
    final preferences = next.valueOrNull;
    // With fireImmediately the first call comes before [_subscription] is assigned, so this flag,
    // not closing it, is what stops a second sheet.
    if (preferences == null || _decided) return;
    _decided = true;
    _subscription?.close();
    _subscription = null;
    ref.read(datePreferencesPromptStoreProvider).markSheetShown(uid);
    if (preferences.isSet) return;
    // The first value can arrive during initState, before there is anything to show it over.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSheet());
  }

  Future<void> _showSheet() async {
    if (!mounted) return;
    final setNow = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _FirstRunSheet(),
    );
    if (setNow == true && mounted) await openDatePreferences(context);
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _FirstRunSheet extends StatelessWidget {
  const _FirstRunSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.auto_awesome_outlined, size: 36, color: AppColors.accentOrange),
            const SizedBox(height: 16),
            const Text(
              DatePreferencesPromptCopy.sheetTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              DatePreferencesPromptCopy.sheetBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                DatePreferencesPromptCopy.sheetSetNow,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text(DatePreferencesPromptCopy.sheetLater, style: TextStyle(fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Tell us what dates you like", at the top of the Dates tab while the user's preferences aren't
/// set (RFC-005 §6.3). Tapping it opens the hub; the close button hides it for good for this
/// user on this device. Saving any section in the hub hides it too.
class DatePreferencesPromptCard extends ConsumerWidget {
  const DatePreferencesPromptCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showDatePreferencesCardProvider)) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Material(
        color: AppColors.secondaryOrange.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => openDatePreferences(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_outlined, color: AppColors.accentOrange),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    DatePreferencesPromptCopy.cardTitle,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  tooltip: DatePreferencesPromptCopy.cardDismiss,
                  onPressed: () => ref.read(datePreferencesCardDismissedProvider.notifier).dismiss(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Not your kind of place? Update your preferences for next time", under the venue options on
/// the ranking screen (RFC-005 §6.3). Opens the hub.
class DatePreferencesUpdateLink extends StatelessWidget {
  const DatePreferencesUpdateLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextButton(
        onPressed: () => openDatePreferences(context),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          minimumSize: const Size.fromHeight(44),
        ),
        child: const Text(
          DatePreferencesPromptCopy.rankingLink,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, decoration: TextDecoration.underline),
        ),
      ),
    );
  }
}
