import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/config/support_config.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/legal/data/support_email.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_copy.dart';

/// Copy for [AccountDeletedScreen].
class AccountDeletedCopy {
  AccountDeletedCopy._();

  static const String title = 'This account was deleted';
  static const String body = 'You deleted this account. To use Muse again, contact support.';
  static const String contactSupport = 'Contact support';
  static const String signOut = 'Sign out';
}

/// Where a user whose account was deleted ends up when they sign in again (RFC-011 §5.6, D-12):
/// `GET /users/exists` said `deleted`, or `POST /users` answered 409 `ACCOUNT_DELETED`. There is
/// no self-service restore; support restores an account by hand.
class AccountDeletedScreen extends ConsumerStatefulWidget {
  const AccountDeletedScreen({super.key});

  /// Replaces the whole stack with this screen, so Back can't return to sign-up.
  static void show(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AccountDeletedScreen()),
      (route) => false,
    );
  }

  @override
  ConsumerState<AccountDeletedScreen> createState() => _AccountDeletedScreenState();
}

class _AccountDeletedScreenState extends ConsumerState<AccountDeletedScreen> {
  bool _signingOut = false;

  /// An email to support with the account id (the uid) and nothing else personal, so support
  /// can find the account.
  Future<void> _contactSupport() async {
    final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
    final email = supportEmailUri(SupportRequest.deletedAccount, uid);
    final opened = await ref.read(legalLinksProvider).openEmail(email);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PrivacySettingsCopy.noEmailApp(SupportConfig.supportEmail))),
      );
    }
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await ref.read(authStateProvider.notifier).signOut();
    } catch (e) {
      // The welcome screen still follows; the type only, as elsewhere.
      debugPrint('Sign-out from the deleted screen failed (${e.runtimeType})');
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AccountDeletedCopy.title,
                  style: textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  AccountDeletedCopy.body,
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  SupportConfig.supportEmail,
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                AppButton(
                  key: const ValueKey('account-deleted-contact'),
                  label: AccountDeletedCopy.contactSupport,
                  icon: Icons.mail_outline,
                  onPressed: _contactSupport,
                ),
                const SizedBox(height: 12),
                AppButton(
                  key: const ValueKey('account-deleted-sign-out'),
                  label: AccountDeletedCopy.signOut,
                  kind: AppButtonKind.outline,
                  loading: _signingOut,
                  onPressed: _signOut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
