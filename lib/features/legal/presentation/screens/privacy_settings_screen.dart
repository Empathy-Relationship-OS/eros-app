import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/config/support_config.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/theme/app_theme.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/legal/data/account_repository.dart';
import 'package:eros_app/features/legal/data/legal_repository.dart';
import 'package:eros_app/features/legal/data/support_email.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';
import 'package:eros_app/features/legal/presentation/providers/privacy_settings_provider.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_copy.dart';

/// "Privacy, safety and legal" in Settings (RFC-009 §5.11, CF-F3): the documents, the consent
/// choices, data requests and complaints by email (D-9), and account deletion.
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  /// Kinds with a change in flight, so their control shows a spinner and can't be tapped twice.
  final Set<DocumentKind> _saving = {};
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(privacySettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(PrivacySettingsCopy.screenTitle)),
      body: async.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _LoadError(
          onRetry: () => ref.read(privacySettingsProvider.notifier).refresh(),
        ),
        data: _content,
      ),
    );
  }

  Widget _content(PrivacySettingsData data) {
    final documents = [
      for (final document in data.documents)
        if (!_choiceKinds.contains(document.kind)) document,
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          title: PrivacySettingsCopy.documentsTitle,
          children: [
            if (documents.isEmpty)
              const ListTile(title: Text(PrivacySettingsCopy.noDocuments))
            else
              for (final document in documents)
                ListTile(
                  key: ValueKey('document-${document.kind.backendValue}'),
                  title: Text(PrivacySettingsCopy.documentTitle(document.kind)),
                  trailing: const Icon(Icons.open_in_new, color: AppColors.textSecondary),
                  onTap: () => _openDocument(document),
                ),
          ],
        ),
        const SizedBox(height: 24),
        _Section(
          title: PrivacySettingsCopy.choicesTitle,
          children: [
            _switchTile(
              data,
              DocumentKind.marketing,
              PrivacySettingsCopy.marketingTitle,
              PrivacySettingsCopy.marketingSubtitle,
            ),
            _switchTile(
              data,
              DocumentKind.locationPin,
              PrivacySettingsCopy.locationPinTitle,
              PrivacySettingsCopy.locationPinSubtitle,
            ),
            _sensitiveDataTile(data),
          ],
        ),
        const SizedBox(height: 24),
        _Section(
          title: PrivacySettingsCopy.yourDataTitle,
          children: [
            ListTile(
              key: const ValueKey('request-data'),
              leading: const Icon(Icons.download_outlined, color: AppColors.textPrimary),
              title: const Text(PrivacySettingsCopy.requestDataTitle),
              subtitle: const Text(PrivacySettingsCopy.requestDataSubtitle),
              trailing: const Icon(Icons.mail_outline, color: AppColors.textSecondary),
              onTap: () => _email(SupportRequest.dataRequest, data.accountId),
            ),
            ListTile(
              key: const ValueKey('complaint'),
              leading: const Icon(Icons.report_outlined, color: AppColors.textPrimary),
              title: const Text(PrivacySettingsCopy.complaintTitle),
              subtitle: const Text(PrivacySettingsCopy.complaintSubtitle),
              trailing: const Icon(Icons.mail_outline, color: AppColors.textSecondary),
              onTap: () => _email(SupportRequest.complaint, data.accountId),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _Section(
          title: PrivacySettingsCopy.accountTitle,
          children: [
            ListTile(
              key: const ValueKey('delete-account'),
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(
                PrivacySettingsCopy.deleteAccountTitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.error),
              ),
              trailing: _deleting ? const _SmallSpinner() : null,
              onTap: _deleting ? null : _confirmDelete,
            ),
          ],
        ),
      ],
    );
  }

  static const Set<DocumentKind> _choiceKinds = {
    DocumentKind.marketing,
    DocumentKind.locationPin,
    DocumentKind.sensitiveData,
  };

  Widget _switchTile(PrivacySettingsData data, DocumentKind kind, String title, String subtitle) {
    final available = data.documentFor(kind) != null;
    final saving = _saving.contains(kind);
    return SwitchListTile(
      key: ValueKey('choice-${kind.backendValue}'),
      title: Text(title),
      subtitle: Text(available ? subtitle : PrivacySettingsCopy.notAvailableYet),
      value: data.consents.isGranted(kind),
      onChanged: !available || saving ? null : (value) => _setConsent(kind, granted: value),
    );
  }

  Widget _sensitiveDataTile(PrivacySettingsData data) {
    const kind = DocumentKind.sensitiveData;
    final available = data.documentFor(kind) != null;
    final granted = data.consents.isGranted(kind);
    final saving = _saving.contains(kind);
    return ListTile(
      key: const ValueKey('choice-SENSITIVE_DATA'),
      title: const Text(PrivacySettingsCopy.sensitiveDataTitle),
      subtitle: Text(
        !available
            ? PrivacySettingsCopy.notAvailableYet
            : granted
                ? PrivacySettingsCopy.sensitiveDataOn
                : PrivacySettingsCopy.sensitiveDataOff,
      ),
      trailing: saving
          ? const _SmallSpinner()
          : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: !available || saving
          ? null
          : () => granted ? _turnOffSensitiveData() : _turnOnSensitiveData(data),
    );
  }

  // ---------------------------------------------------------------------------------------------
  // Choices
  // ---------------------------------------------------------------------------------------------

  /// Records the choice and returns the server's answer, or null if it failed (already shown).
  Future<bool?> _setConsent(DocumentKind kind, {required bool granted}) async {
    setState(() => _saving.add(kind));
    try {
      final answer = await ref
          .read(privacySettingsProvider.notifier)
          .setConsent(kind, granted: granted);
      return answer.orientationRetained;
    } on ConsentVersionStale {
      _snack(PrivacySettingsCopy.choiceStale);
    } on ConsentRequiredForService {
      _snack(PrivacySettingsCopy.choiceRequired);
    } catch (_) {
      _snack(PrivacySettingsCopy.choiceFailed);
    } finally {
      if (mounted) setState(() => _saving.remove(kind));
    }
    return null;
  }

  Future<void> _turnOffSensitiveData() async {
    final confirmed = await _confirm(
      title: PrivacySettingsCopy.sensitiveDataOffTitle,
      body: PrivacySettingsCopy.sensitiveDataOffBody,
      confirmLabel: PrivacySettingsCopy.sensitiveDataOffConfirm,
      confirmKind: AppButtonKind.primary,
    );
    if (confirmed != true || !mounted) return;
    final retained = await _setConsent(DocumentKind.sensitiveData, granted: false);
    if (retained == true && mounted) await _showOrientationRetained();
  }

  Future<void> _turnOnSensitiveData(PrivacySettingsData data) async {
    final document = data.documentFor(DocumentKind.sensitiveData);
    final confirmed = await _confirm(
      title: PrivacySettingsCopy.sensitiveDataOnTitle,
      body: PrivacySettingsCopy.sensitiveDataOnBody,
      confirmLabel: PrivacySettingsCopy.sensitiveDataOnConfirm,
      confirmKind: AppButtonKind.primary,
      link: document == null
          ? null
          : (label: PrivacySettingsCopy.readMore, onTap: () => _openDocument(document)),
    );
    if (confirmed != true || !mounted) return;
    await _setConsent(DocumentKind.sensitiveData, granted: true);
  }

  /// Sensitive data is off but orientation was kept: say so again, with a way to delete.
  Future<void> _showOrientationRetained() async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('orientation-retained'),
        title: const Text(PrivacySettingsCopy.sensitiveDataRetainedTitle),
        content: const Text(PrivacySettingsCopy.sensitiveDataOffBody),
        actions: [
          TextButton(
            style: AppTheme.quietLink,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(PrivacySettingsCopy.deleteAccountLink),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(PrivacySettingsCopy.close),
          ),
        ],
      ),
    );
    if (delete == true && mounted) await _confirmDelete();
  }

  // ---------------------------------------------------------------------------------------------
  // Links and emails
  // ---------------------------------------------------------------------------------------------

  Future<void> _openDocument(LegalDocument document) async {
    final url = Uri.tryParse(document.url);
    final opened = url != null && await ref.read(legalLinksProvider).openDocument(url);
    if (!opened) _snack(PrivacySettingsCopy.linkFailed);
  }

  Future<void> _email(SupportRequest request, String accountId) async {
    final opened = await ref.read(legalLinksProvider).openEmail(supportEmailUri(request, accountId));
    if (!opened) _snack(PrivacySettingsCopy.noEmailApp(SupportConfig.supportEmail));
  }

  // ---------------------------------------------------------------------------------------------
  // Delete account
  // ---------------------------------------------------------------------------------------------

  Future<void> _confirmDelete() async {
    final confirmed = await _confirm(
      title: PrivacySettingsCopy.deleteAccountConfirmTitle,
      body: PrivacySettingsCopy.deleteAccountConfirmBody,
      confirmLabel: PrivacySettingsCopy.deleteAccountConfirm,
      confirmKind: AppButtonKind.destructive,
    );
    if (confirmed != true || !mounted) return;

    final navigator = Navigator.of(context);
    setState(() => _deleting = true);
    try {
      await ref.read(accountRepositoryProvider).closeAccount();
    } catch (_) {
      if (mounted) setState(() => _deleting = false);
      _snack(PrivacySettingsCopy.deleteAccountFailed);
      return;
    }

    // The account is closed: sign out whatever happens next.
    try {
      await ref.read(authStateProvider.notifier).signOut();
    } catch (_) {
      _snack(PrivacySettingsCopy.signOutFailed);
    }
    navigator.pushNamedAndRemoveUntil('/welcome', (route) => false);
  }

  // ---------------------------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------------------------

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    required AppButtonKind confirmKind,
    ({String label, VoidCallback onTap})? link,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body),
            if (link != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(onPressed: link.onTap, child: Text(link.label)),
              ),
          ],
        ),
        actions: [
          TextButton(
            style: AppTheme.quietLink,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(PrivacySettingsCopy.cancel),
          ),
          AppButton(
            label: confirmLabel,
            kind: confirmKind,
            expand: false,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: Column(children: children),
          ),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              PrivacySettingsCopy.loadFailed,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: PrivacySettingsCopy.retry,
              kind: AppButtonKind.outline,
              expand: false,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallSpinner extends StatelessWidget {
  const _SmallSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
  }
}
