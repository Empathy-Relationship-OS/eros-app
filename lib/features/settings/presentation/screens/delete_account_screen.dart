import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/theme/app_theme.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_repository_provider.dart';
import 'package:eros_app/features/home/presentation/screens/home_screen.dart';
import 'package:eros_app/features/legal/data/support_email.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_copy.dart';
import 'package:eros_app/features/legal/presentation/widgets/reconsent_gate.dart';

/// Copy for Delete account (RFC-011 §5.6, SI-F4). The confirmation's title and body are
/// RFC-009's, from CF-F3 ([PrivacySettingsCopy]), which D-11 says replaces SI-F4's placeholder.
class DeleteAccountCopy {
  DeleteAccountCopy._();

  static const String screenTitle = 'Delete account';
  static const String confirmTitle = PrivacySettingsCopy.deleteAccountConfirmTitle;
  static const String confirmBody = PrivacySettingsCopy.deleteAccountConfirmBody;
  static const String deleteButton = PrivacySettingsCopy.deleteAccountConfirm;
  static const String cancel = 'Cancel';

  static const String activeDate =
      'You have a date in progress. Cancel it first, then you can delete your account.';
  static const String goToDates = 'Go to my dates';
  static const String datesCheckFailed = "Couldn't check your dates. Try again.";
  static const String tryAgain = 'Try again';

  static const String deleted = 'Your account has been deleted.';
  static const String appleStepTitle = 'Your account has been deleted';
  static const String appleStepBody =
      'To finish, remove Muse from Sign in with Apple in your Apple ID settings.';
  static const String appleStepLink = 'Show me how';
  static const String ok = 'OK';

  /// Apple's "stop using Sign in with Apple" page (RFC-011 §5.6, TN3194).
  static final Uri appleHelpUrl = Uri.parse('https://support.apple.com/en-us/102571');
}

/// Whether the signed-in user has a date that isn't finished (RFC-011 D-14). While they do,
/// Delete account isn't offered: deleting doesn't cancel dates, so a partner would be left
/// waiting and deposits held.
final deleteAccountHasActiveDateProvider = FutureProvider.autoDispose<bool>((ref) async {
  final dates =
      await ref.read(datesRepositoryProvider).fetchDates(filter: DateListFilter.active);
  return dates.isNotEmpty;
});

/// Delete account (RFC-011 §5.6, SI-F4): checks for active dates, confirms, then runs
/// `AuthStateNotifier.deleteAccount` and ends on the welcome screen. The one way to delete an
/// account in the app: Settings and "Privacy, safety and legal" both open it (D-11).
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DeleteAccountScreen()),
    );
  }

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final activeDate = ref.watch(deleteAccountHasActiveDateProvider);
    return PopScope(
      canPop: !_deleting,
      child: Scaffold(
        appBar: AppBar(title: const Text(DeleteAccountCopy.screenTitle)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: activeDate.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _Message(
                key: const ValueKey('delete-account-dates-failed'),
                text: DeleteAccountCopy.datesCheckFailed,
                action: AppButton(
                  label: DeleteAccountCopy.tryAgain,
                  onPressed: () => ref.invalidate(deleteAccountHasActiveDateProvider),
                ),
              ),
              data: (hasActiveDate) => hasActiveDate
                  ? _Message(
                      key: const ValueKey('delete-account-active-date'),
                      text: DeleteAccountCopy.activeDate,
                      action: AppButton(
                        label: DeleteAccountCopy.goToDates,
                        onPressed: _openDates,
                      ),
                    )
                  : _confirmation(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _confirmation(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(DeleteAccountCopy.confirmTitle, style: textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(DeleteAccountCopy.confirmBody, style: textTheme.bodyLarge),
        const Spacer(),
        AppButton(
          key: const ValueKey('delete-account-confirm'),
          label: DeleteAccountCopy.deleteButton,
          kind: AppButtonKind.destructive,
          loading: _deleting,
          onPressed: _delete,
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey('delete-account-cancel'),
          style: AppTheme.quietLink,
          onPressed: _deleting ? null : () => Navigator.of(context).pop(),
          child: const Text(DeleteAccountCopy.cancel),
        ),
      ],
    );
  }

  /// The dates list, where a date is cancelled through its normal flow and refund rules.
  void _openDates() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const ReconsentGate(child: HomeScreen(initialIndex: 1)),
      ),
      (route) => false,
    );
  }

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() => _deleting = true);

    // Read before the await: this screen is gone by the time they're used.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final links = ref.read(legalLinksProvider);

    final result = await ref.read(authStateProvider.notifier).deleteAccount();
    if (!result.isSuccess) {
      if (mounted) setState(() => _deleting = false);
      messenger.showSnackBar(SnackBar(content: Text(result.errorMessage!)));
      return;
    }

    navigator.pushNamedAndRemoveUntil('/welcome', (route) => false);
    if (!result.signedOut) {
      messenger.showSnackBar(const SnackBar(content: Text(PrivacySettingsCopy.signOutFailed)));
    }
    if (result.appleRevoked) {
      messenger.showSnackBar(const SnackBar(content: Text(DeleteAccountCopy.deleted)));
    } else {
      await _showAppleStep(navigator, links);
    }
  }

  /// Apple's tokens weren't revoked (D-9): the user removes Muse from their Apple ID themselves.
  static Future<void> _showAppleStep(NavigatorState navigator, LegalLinks links) {
    return showDialog<void>(
      context: navigator.context,
      builder: (context) => AlertDialog(
        key: const ValueKey('delete-account-apple-step'),
        title: const Text(DeleteAccountCopy.appleStepTitle),
        content: const Text(DeleteAccountCopy.appleStepBody),
        actions: [
          TextButton(
            onPressed: () => links.openDocument(DeleteAccountCopy.appleHelpUrl),
            child: const Text(DeleteAccountCopy.appleStepLink),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(DeleteAccountCopy.ok),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final Widget action;

  const _Message({super.key, required this.text, required this.action});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        action,
      ],
    );
  }
}
