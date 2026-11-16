import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/auth/presentation/providers/marketing_consent_provider.dart';

/// Terms & Conditions acceptance screen
/// Matches screenshot: @screenshots/login/create-user/2B2A66BB-FECA-4ECA-B133-53CC77A34D91.png
class TermsScreen extends ConsumerStatefulWidget {
  const TermsScreen({super.key});

  @override
  ConsumerState<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends ConsumerState<TermsScreen> {
  bool _acceptedTerms = false;
  bool _acceptsMarketing = false;

  Future<void> _continue() async {
    if (!_acceptedTerms) return;

    // Store marketing consent locally
    await ref
        .read(marketingConsentProvider.notifier)
        .setMarketingConsent(_acceptsMarketing);

    // Basic info collection is complete!
    // Navigate to profile preferences/interests section, or for now, to a completion screen
    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/complete-basic');
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(profileCreationProvider);
    final firstName = draft.firstName ?? 'there';

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
              ProfileProgressBar(
                currentStep: ProfileCreationConstants.basicInfoStepTerms,
                totalSteps: ProfileCreationConstants.basicInfoTotalSteps,
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome, $firstName!',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Before we begin, please review our terms',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terms & Conditions',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _termsText,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: () {
                  // TODO: Show full guidelines page
                },
                child: Text(
                  'See our community guidelines',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primaryDeep,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _acceptedTerms,
                onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
                title: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.primaryDeep,
                            ),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.primaryDeep,
                            ),
                      ),
                    ],
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _acceptsMarketing,
                onChanged: (value) => setState(() => _acceptsMarketing = value ?? false),
                title: Text(
                  'I consent to receive promotional emails and updates from Muse',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              AppButton(label: 'Accept and Continue', onPressed: _acceptedTerms ? _continue : null),
            ],
          ),
        ),
      ),
    );
  }

  static const String _termsText = '''
By creating an account on Muse, you agree to the following terms and conditions:

1. You are at least 18 years of age
2. You will provide accurate and truthful information
3. You will not use the service for illegal purposes
4. You understand that dates require a deposit commitment
5. You agree to our cancellation and refund policies
6. You will treat all users with respect
7. You will not share inappropriate content
8. You understand your data will be processed according to our Privacy Policy

These terms are subject to change. Continued use of the service constitutes acceptance of any modifications.

For full terms, visit: https://muse.app/terms
For privacy policy, visit: https://muse.app/privacy
''';
}
