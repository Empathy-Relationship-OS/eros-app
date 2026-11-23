import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_theme.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/core/widgets/sign_out_dialog.dart';
import 'package:eros_app/features/legal/data/legal_repository.dart';
import 'package:eros_app/features/legal/domain/models/consent.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';
import 'package:eros_app/features/legal/presentation/providers/legal_documents_provider.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_copy.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_document_tile.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';

/// Shown when `GET /users/me` has `outstandingConsents`: a document the user must accept is new
/// or has changed (RFC-009 §5.2). Full screen and can't be dismissed: "Accept and continue"
/// posts the consents with `source: REPROMPT` and refetches `GET /users/me` (primer rule 20);
/// signing out is the only other way off it. Pops with true once nothing is outstanding.
class ReconsentScreen extends ConsumerStatefulWidget {
  /// The outstanding kinds, as the backend names them.
  final List<String> outstanding;

  /// The user's home city, whose region's documents are the ones to accept.
  final String? cityName;

  const ReconsentScreen({super.key, required this.outstanding, required this.cityName});

  static Route<bool> route({required List<String> outstanding, required String? cityName}) =>
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        settings: const RouteSettings(name: routeName),
        builder: (_) => ReconsentScreen(outstanding: outstanding, cityName: cityName),
      );

  static const String routeName = '/legal/reconsent';

  @override
  ConsumerState<ReconsentScreen> createState() => _ReconsentScreenState();
}

class _ReconsentScreenState extends ConsumerState<ReconsentScreen> {
  final Logger _logger = Logger();
  late List<String> _outstanding = widget.outstanding;
  bool _saving = false;
  String? _message;

  List<DocumentKind> get _kinds => [
        for (final name in _outstanding)
          ?DocumentKind.fromBackend(name),
      ];

  bool get _hasUnknown => _kinds.length < _outstanding.length;

  Future<void> _accept(List<LegalDocument> documents) async {
    final choices = [
      for (final kind in _kinds)
        if (documentOf(documents, kind) case final document?)
          ConsentChoice(kind: kind, version: document.version, granted: true),
    ];
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      if (choices.isNotEmpty) {
        await ref.read(legalRepositoryProvider).recordConsents(
              choices,
              source: ConsentSource.reprompt,
            );
      }
      // State comes from the server (rule 20): ask again what is still outstanding.
      final profile = await ref.read(profileRepositoryProvider).getCurrentUser();
      if (!mounted) return;
      if (profile.outstandingConsents.isEmpty) {
        Navigator.of(context).pop(true);
        return;
      }
      ref.invalidate(legalDocumentsForCityProvider(widget.cityName));
      setState(() {
        _outstanding = profile.outstandingConsents;
        _saving = false;
        _message = _hasUnknown ? null : LegalCopy.reconsentStale;
      });
    } on ConsentVersionStale {
      if (!mounted) return;
      ref.invalidate(legalDocumentsForCityProvider(widget.cityName));
      setState(() {
        _saving = false;
        _message = LegalCopy.reconsentStale;
      });
    } catch (e) {
      _logger.w('⚠️  Re-consent failed (${e.runtimeType})');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = LegalCopy.reconsentFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(legalDocumentsForCityProvider(widget.cityName));
    final loaded = documents.valueOrNull;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(LegalCopy.reconsentTitle, style: textTheme.displaySmall),
                const SizedBox(height: 8),
                Text(
                  LegalCopy.reconsentBody,
                  style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: switch (documents) {
                    AsyncData(:final value) => ListView(
                        children: [
                          for (final kind in _kinds) ...[
                            LegalDocumentTile(kind: kind, document: documentOf(value, kind)),
                            const SizedBox(height: 8),
                          ],
                          if (_hasUnknown) Text(LegalCopy.reconsentUnknown, style: textTheme.bodyMedium),
                          if (_message != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _message!,
                              style: textTheme.bodyMedium?.copyWith(color: AppColors.error),
                            ),
                          ],
                        ],
                      ),
                    AsyncError() => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(LegalCopy.loadFailed),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(legalDocumentsForCityProvider(widget.cityName)),
                            child: const Text(LegalCopy.retry),
                          ),
                        ],
                      ),
                    _ => const Center(child: CircularProgressIndicator()),
                  },
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: LegalCopy.acceptAndContinue,
                  loading: _saving,
                  onPressed: loaded == null || _saving ? null : () => _accept(loaded),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    style: AppTheme.quietLink,
                    onPressed: _saving
                        ? null
                        : () => showSignOutDialog(context, ref, message: LegalCopy.signOutMessage),
                    child: const Text(LegalCopy.signOut),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
