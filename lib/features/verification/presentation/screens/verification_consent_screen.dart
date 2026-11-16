import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_theme.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter/services.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';

/// What verification involves, before the camera opens (RFC-008 §5.4, primer rule 20).
///
/// Two ways on: [onAgree] (the automated comparison, then staff) and the quieter
/// [onPersonInstead] (staff only, D-5). The wording is a placeholder until Q-8.
class VerificationConsentScreen extends StatelessWidget {
  /// True while the attempt is being started: both choices are disabled.
  final bool busy;
  final VoidCallback onAgree;
  final VoidCallback onPersonInstead;
  final VoidCallback onPrivacyPolicy;
  final VoidCallback onClose;

  const VerificationConsentScreen({
    super.key,
    required this.busy,
    required this.onAgree,
    required this.onPersonInstead,
    required this.onPrivacyPolicy,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5);
    return Scaffold(
      appBar: AppBar(
        // Dark status bar icons, for this light page
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          // Stated, not inherited: a test holds this to the dark colour
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          tooltip: VerificationCopy.closeLabel,
          onPressed: onClose,
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      VerificationCopy.consentTitle,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(VerificationCopy.consentIntro, style: bodyStyle),
                  const SizedBox(height: 16),
                  for (final point in VerificationCopy.consentPoints)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 3, right: 12),
                            child: ExcludeSemantics(
                              child: Icon(Icons.check_circle_outline,
                                  size: 20, color: AppColors.primaryDeep),
                            ),
                          ),
                          Expanded(child: Text(point, style: bodyStyle)),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onPrivacyPolicy,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Text(
                        VerificationCopy.privacyPolicyLink,
                        style: TextStyle(decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(
                    label: VerificationCopy.consentAgree,
                    loading: busy,
                    onPressed: onAgree,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: busy ? null : onPersonInstead,
                    style: AppTheme.quietLink,
                    child: const Text(VerificationCopy.consentPersonInstead),
                  ),
                  Text(
                    VerificationCopy.consentPersonInsteadHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
