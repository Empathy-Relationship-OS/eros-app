import 'package:flutter/material.dart';
import 'package:eros_app/core/auth/apple_sign_in.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/features/auth/domain/models/account_link.dart';

/// On the password screen when Google or Apple met an email that already has an account
/// (RFC-011 §5.4). Names only the method the user tapped, never the account's own (D-10).
class AccountLinkBanner extends StatelessWidget {
  const AccountLinkBanner({super.key, required this.provider});

  final LinkingProvider provider;

  /// The banner's words. If the account has no password (it was made with the other provider),
  /// the user can go back and use that. Android offers no other provider than Google (D-2), so
  /// that sentence is left out there.
  static String textFor(LinkingProvider provider, {required bool appleOffered}) {
    final add = 'You already have a Muse account with this email. '
        'Sign in with your password to add ${provider.label}.';
    return appleOffered ? '$add Or go back and use the other sign-in option.' : add;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('account-link-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Icon(Icons.info_outline, color: AppColors.primaryDeep, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              textFor(provider, appleOffered: appleSignInSupported()),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
