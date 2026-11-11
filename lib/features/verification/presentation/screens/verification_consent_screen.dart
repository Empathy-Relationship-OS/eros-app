import 'package:flutter/material.dart';
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
    const bodyStyle = TextStyle(fontSize: 16, height: 1.5, color: AppColors.textPrimary);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
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
                    child: const Text(
                      VerificationCopy.consentTitle,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(VerificationCopy.consentIntro, style: bodyStyle),
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
                                  size: 20, color: AppColors.primary),
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
                  ElevatedButton(
                    onPressed: busy ? null : onAgree,
                    child: busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(VerificationCopy.consentAgree),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: busy ? null : onPersonInstead,
                    child: const Text(
                      VerificationCopy.consentPersonInstead,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const Text(
                    VerificationCopy.consentPersonInsteadHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
