import 'package:flutter/material.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';
import 'package:eros_app/features/legal/presentation/providers/legal_documents_provider.dart';
import 'package:eros_app/features/legal/presentation/providers/signup_consents_provider.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_copy.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_document_tile.dart';
import 'package:eros_app/features/legal/presentation/legal_routes.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

/// The last basic-info step (RFC-009 §5.11, CF-F1). Shows the documents for the region of the
/// user's city, each with a link: one tick for the terms and the privacy notice, an
/// acknowledgement for the safety notice and, in New York, one for the Dating Bill of Rights.
/// Marketing is a separate, unticked choice.
///
/// Nothing is sent here: [signupConsentsProvider] keeps each version shown, and `POST /users`
/// sends them with the profile.
class TermsScreen extends ConsumerStatefulWidget {
  const TermsScreen({super.key});

  @override
  ConsumerState<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends ConsumerState<TermsScreen> {
  late bool _acceptedTerms;
  late bool _acknowledgedSafety;
  late bool _acknowledgedBillOfRights;
  late bool _acceptsMarketing;

  @override
  void initState() {
    super.initState();
    final agreed = ref.read(signupConsentsProvider);
    _acceptedTerms =
        agreed.has(DocumentKind.terms) && agreed.has(DocumentKind.privacyNotice);
    _acknowledgedSafety = agreed.has(DocumentKind.safetyNotice);
    _acknowledgedBillOfRights = agreed.has(DocumentKind.datingBillOfRights);
    _acceptsMarketing = agreed.has(DocumentKind.marketing);
  }

  bool _canContinue(List<LegalDocument> documents) {
    final billOfRightsShown = documentOf(documents, DocumentKind.datingBillOfRights) != null;
    return _acceptedTerms &&
        _acknowledgedSafety &&
        (!billOfRightsShown || _acknowledgedBillOfRights);
  }

  Future<void> _continue(List<LegalDocument> documents) async {
    if (!_canContinue(documents)) return;
    String? versionOf(DocumentKind kind) => documentOf(documents, kind)?.version;

    final consents = ref.read(signupConsentsProvider.notifier);
    final billOfRights = versionOf(DocumentKind.datingBillOfRights);
    await consents.agree({
      DocumentKind.terms: versionOf(DocumentKind.terms),
      DocumentKind.privacyNotice: versionOf(DocumentKind.privacyNotice),
      DocumentKind.safetyNotice: versionOf(DocumentKind.safetyNotice),
      DocumentKind.datingBillOfRights: ?billOfRights,
      if (_acceptsMarketing) DocumentKind.marketing: versionOf(DocumentKind.marketing),
    });
    await consents.forget([
      // A city outside New York since the last visit: nothing to acknowledge any more.
      if (billOfRights == null) DocumentKind.datingBillOfRights,
      if (!_acceptsMarketing) DocumentKind.marketing,
    ]);
    final review = ref.read(consentsToReviewProvider.notifier);
    review.state = review.state.difference(LegalRoutes.termsStepKinds);

    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/complete-basic');
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(profileCreationProvider);
    final firstName = draft.firstName ?? 'there';
    final documents = ref.watch(legalDocumentsForCityProvider(draft.city));
    final loaded = documents.valueOrNull;
    final sentBack =
        ref.watch(consentsToReviewProvider).any(LegalRoutes.termsStepKinds.contains);

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
                LegalCopy.termsWelcome(firstName),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                LegalCopy.termsSubtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: switch (documents) {
                  AsyncData(:final value) => _Documents(
                      documents: value,
                      sentBack: sentBack,
                      acceptedTerms: _acceptedTerms,
                      acknowledgedSafety: _acknowledgedSafety,
                      acknowledgedBillOfRights: _acknowledgedBillOfRights,
                      acceptsMarketing: _acceptsMarketing,
                      onTerms: (v) => setState(() => _acceptedTerms = v),
                      onSafety: (v) => setState(() => _acknowledgedSafety = v),
                      onBillOfRights: (v) => setState(() => _acknowledgedBillOfRights = v),
                      onMarketing: (v) => setState(() => _acceptsMarketing = v),
                    ),
                  AsyncError() => _LoadError(
                      onRetry: () => ref.invalidate(legalDocumentsForCityProvider(draft.city)),
                    ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
              const SizedBox(height: 16),
              AppButton(
                label: LegalCopy.acceptAndContinue,
                onPressed:
                    loaded != null && _canContinue(loaded) ? () => _continue(loaded) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Documents extends StatelessWidget {
  final List<LegalDocument> documents;
  final bool sentBack;
  final bool acceptedTerms;
  final bool acknowledgedSafety;
  final bool acknowledgedBillOfRights;
  final bool acceptsMarketing;
  final ValueChanged<bool> onTerms;
  final ValueChanged<bool> onSafety;
  final ValueChanged<bool> onBillOfRights;
  final ValueChanged<bool> onMarketing;

  const _Documents({
    required this.documents,
    required this.sentBack,
    required this.acceptedTerms,
    required this.acknowledgedSafety,
    required this.acknowledgedBillOfRights,
    required this.acceptsMarketing,
    required this.onTerms,
    required this.onSafety,
    required this.onBillOfRights,
    required this.onMarketing,
  });

  Widget _tile(DocumentKind kind) =>
      LegalDocumentTile(kind: kind, document: documentOf(documents, kind));

  @override
  Widget build(BuildContext context) {
    final billOfRights = documentOf(documents, DocumentKind.datingBillOfRights);
    return ListView(
      children: [
        if (sentBack) ...[const ReviewAgainBanner(), const SizedBox(height: 16)],
        _tile(DocumentKind.terms),
        const SizedBox(height: 8),
        _tile(DocumentKind.privacyNotice),
        ConsentCheckbox(
          key: const Key('consent-terms'),
          label: LegalCopy.agreeTermsAndPrivacy,
          value: acceptedTerms,
          onChanged: onTerms,
        ),
        const SizedBox(height: 8),
        _tile(DocumentKind.safetyNotice),
        ConsentCheckbox(
          key: const Key('consent-safety'),
          label: LegalCopy.acknowledgeSafety,
          value: acknowledgedSafety,
          onChanged: onSafety,
        ),
        if (billOfRights != null) ...[
          const SizedBox(height: 8),
          LegalDocumentTile(kind: DocumentKind.datingBillOfRights, document: billOfRights),
          ConsentCheckbox(
            key: const Key('consent-bill-of-rights'),
            label: LegalCopy.acknowledgeBillOfRights,
            value: acknowledgedBillOfRights,
            onChanged: onBillOfRights,
          ),
        ],
        const SizedBox(height: 16),
        ConsentCheckbox(
          key: const Key('consent-marketing'),
          label: LegalCopy.marketingOptIn,
          value: acceptsMarketing,
          onChanged: onMarketing,
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(LegalCopy.loadFailed, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text(LegalCopy.retry)),
        ],
      ),
    );
  }
}
