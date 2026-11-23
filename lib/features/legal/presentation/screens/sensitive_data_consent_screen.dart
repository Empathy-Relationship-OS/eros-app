import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';
import 'package:eros_app/features/legal/presentation/legal_links.dart';
import 'package:eros_app/features/legal/presentation/legal_routes.dart';
import 'package:eros_app/features/legal/presentation/providers/legal_documents_provider.dart';
import 'package:eros_app/features/legal/presentation/providers/signup_consents_provider.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_copy.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_document_tile.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';

/// Explicit consent to use sexual orientation, ethnicity and religion (RFC-009 §5.2, D-4), asked
/// just before the first of those questions. Its own unticked "I agree". Without it sign-up
/// can't go on, because the backend refuses a profile without `SENSITIVE_DATA`, and the screen
/// says so.
class SensitiveDataConsentScreen extends ConsumerStatefulWidget {
  const SensitiveDataConsentScreen({super.key});

  @override
  ConsumerState<SensitiveDataConsentScreen> createState() => _SensitiveDataConsentScreenState();
}

class _SensitiveDataConsentScreenState extends ConsumerState<SensitiveDataConsentScreen> {
  late bool _agreed = ref.read(signupConsentsProvider).has(DocumentKind.sensitiveData);

  Future<void> _continue(List<LegalDocument> documents) async {
    if (!_agreed) return;
    await ref.read(signupConsentsProvider.notifier).agree({
      DocumentKind.sensitiveData: documentOf(documents, DocumentKind.sensitiveData)?.version,
    });
    final review = ref.read(consentsToReviewProvider.notifier);
    review.state = {...review.state}..remove(DocumentKind.sensitiveData);
    if (mounted) Navigator.pushNamed(context, LegalRoutes.afterSensitiveData);
  }

  Future<void> _setAgreed(bool value) async {
    setState(() => _agreed = value);
    if (!value) await ref.read(signupConsentsProvider.notifier).forget([DocumentKind.sensitiveData]);
  }

  @override
  Widget build(BuildContext context) {
    final city = ref.watch(profileCreationProvider.select((d) => d.city));
    final documents = ref.watch(legalDocumentsForCityProvider(city));
    final loaded = documents.valueOrNull;
    final sentBack = ref.watch(consentsToReviewProvider).contains(DocumentKind.sensitiveData);
    final textTheme = Theme.of(context).textTheme;

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
                currentStep: ProfileCreationConstants.preferencesStepSexualOrientation,
                totalSteps: ProfileCreationConstants.preferencesTotalSteps,
                sectionLabel: 'Preferences',
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  children: [
                    if (sentBack) ...[const ReviewAgainBanner(), const SizedBox(height: 16)],
                    Text(LegalCopy.sensitiveTitle, style: textTheme.displaySmall),
                    const SizedBox(height: 16),
                    Text(LegalCopy.sensitiveWhat, style: textTheme.bodyLarge),
                    const SizedBox(height: 12),
                    Text(LegalCopy.sensitiveUse, style: textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: const Key('read-SENSITIVE_DATA'),
                        onPressed: documents.isLoading
                            ? null
                            : () => openLegalLink(
                                  context,
                                  ref,
                                  LegalLinks.urlFor(
                                    DocumentKind.sensitiveData,
                                    loaded == null
                                        ? null
                                        : documentOf(loaded, DocumentKind.sensitiveData),
                                  ),
                                ),
                        child: const Text(LegalCopy.sensitiveLink),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConsentCheckbox(
                      key: const Key('consent-sensitive-data'),
                      label: LegalCopy.sensitiveAgree,
                      value: _agreed,
                      onChanged: _setAgreed,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      LegalCopy.sensitiveRequired,
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    if (documents.hasError) ...[
                      const SizedBox(height: 16),
                      Text(LegalCopy.loadFailed, style: textTheme.bodyMedium),
                      TextButton(
                        onPressed: () => ref.invalidate(legalDocumentsForCityProvider(city)),
                        child: const Text(LegalCopy.retry),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: LegalCopy.continueLabel,
                onPressed: _agreed && loaded != null ? () => _continue(loaded) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
