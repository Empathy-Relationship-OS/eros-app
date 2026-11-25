import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/auth/apple_sign_in.dart';
import 'package:eros_app/core/notifications/push_host.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/auth/presentation/screens/auth_loading_screen.dart';
import 'package:eros_app/features/auth/presentation/widgets/auth_provider_button.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';
import 'package:eros_app/features/legal/presentation/legal_links.dart';
import 'package:eros_app/features/legal/presentation/providers/legal_documents_provider.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_copy.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_document_tile.dart';
import '../../../../core/theme/app_colors.dart';
import 'email_entry_screen.dart';

/// How the user gets in: one screen for sign-up and sign-in (RFC-011 D-3).
///
/// Order (D-2): Apple, Google, Email on iOS; Google, Email on Android, which never shows Apple.
/// "Continue with Email" stays a full button (D-4).
class AuthMethodSelectionScreen extends ConsumerStatefulWidget {
  const AuthMethodSelectionScreen({super.key});

  @override
  ConsumerState<AuthMethodSelectionScreen> createState() => _AuthMethodSelectionScreenState();
}

/// A provider with its own sheet, then a Firebase sign-in.
enum _Provider { apple, google }

class _AuthMethodSelectionScreenState extends ConsumerState<AuthMethodSelectionScreen> {
  /// Set while that provider's sheet is up and Firebase is signing in. Every option ignores taps.
  _Provider? _signingInWith;

  Future<void> _continueWith(_Provider provider) async {
    if (_signingInWith != null) return;
    setState(() => _signingInWith = provider);

    final auth = ref.read(authStateProvider.notifier);
    final result = switch (provider) {
      _Provider.apple => await auth.signInWithApple(),
      _Provider.google => await auth.signInWithGoogle(),
    };
    if (!mounted) return;

    if (result != null && result.isSuccess) {
      // AuthLoadingScreen picks the app or profile creation, as at launch.
      Navigator.of(context).pushNamedAndRemoveUntil(AuthLoadingScreen.routeName, (_) => false);
      return;
    }

    setState(() => _signingInWith = null);
    // Null: the user closed the provider's sheet. Back to this screen with no message.
    if (result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.errorMessage ?? 'Sign in failed'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _continueWithEmail() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmailEntryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _signingInWith != null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Title: the screen serves sign-in as well as sign-up.
              Text(
                'How would you like to\ncontinue?',
                style: Theme.of(context).textTheme.displayMedium,
              ),

              const SizedBox(height: 16),

              // Subtitle
              Text(
                'Choose your preferred method to get started',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),

              const SizedBox(height: 48),

              // Phone sign-in stays off (RFC-011 §8).

              // Apple first, and only on iOS (D-2).
              if (appleSignInSupported()) ...[
                AppleProviderButton(
                  key: const Key('auth-apple'),
                  loading: _signingInWith == _Provider.apple,
                  onPressed: busy ? null : () => _continueWith(_Provider.apple),
                ),
                const SizedBox(height: 16),
              ],

              AuthProviderButton(
                key: const Key('auth-google'),
                leading: AuthProviderButton.googleMark(),
                label: 'Continue with Google',
                loading: _signingInWith == _Provider.google,
                onPressed: busy ? null : () => _continueWith(_Provider.google),
              ),

              const SizedBox(height: 16),

              AuthProviderButton(
                key: const Key('auth-email'),
                leading: const Icon(Icons.email_outlined, size: 20),
                label: 'Continue with Email',
                onPressed: busy ? null : _continueWithEmail,
              ),

              const Spacer(),

              // The current terms and privacy notice (RFC-009 §5.11)
              const Center(child: _AgreementLinks()),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// "By continuing, you agree to our Terms of use and Privacy notice", each a link to the current
/// document (`ALL` region). Before sign-in `GET /legal/documents` can't be called, so the links
/// go to the website's page for each kind until then.
class _AgreementLinks extends ConsumerWidget {
  const _AgreementLinks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInUidProvider) != null;
    final documents =
        signedIn ? ref.watch(legalDocumentsForCityProvider(null)).valueOrNull : null;
    Uri urlFor(DocumentKind kind) =>
        LegalLinks.urlFor(kind, documents == null ? null : documentOf(documents, kind));

    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary);
    Widget link(DocumentKind kind, String label) => Semantics(
          link: true,
          child: TextButton(
            key: Key('auth-link-${kind.backendValue}'),
            onPressed: () => openLegalLink(context, ref, urlFor(kind)),
            child: Text(label),
          ),
        );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(LegalCopy.authAgreePrefix, style: style),
        link(DocumentKind.terms, LegalCopy.authTerms),
        Text(LegalCopy.authAnd, style: style),
        link(DocumentKind.privacyNotice, LegalCopy.authPrivacy),
      ],
    );
  }
}
