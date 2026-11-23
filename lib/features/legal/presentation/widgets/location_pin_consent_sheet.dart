import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/theme/app_theme.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/features/legal/data/legal_repository.dart';
import 'package:eros_app/features/legal/domain/models/consent.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';
import 'package:eros_app/features/legal/presentation/legal_links.dart';
import 'package:eros_app/features/legal/presentation/providers/legal_documents_provider.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_copy.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_document_tile.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';

final Logger _logger = Logger();

/// Makes sure the user allows us to keep a starting pin (`LOCATION_PIN`, RFC-009 §5.4, D-6)
/// before one is set. True if they already had, or allow it now; false if they said not now.
///
/// If the consents can't be read, it lets the pin through: saving it then answers 403
/// `CONSENT_REQUIRED` and the screen asks with [askForLocationPin].
Future<bool> ensureLocationPinConsent(BuildContext context, WidgetRef ref) async {
  try {
    final state = await ref.read(legalRepositoryProvider).consents();
    if (state.isGranted(DocumentKind.locationPin)) return true;
  } catch (e) {
    _logger.w('⚠️  Could not read consents before a pin (${e.runtimeType})');
    return true;
  }
  if (!context.mounted) return false;
  return askForLocationPin(context, ref);
}

/// Shows the pin sheet and, on "Allow", records `LOCATION_PIN` on the current version for the
/// user's region. True once it is recorded.
Future<bool> askForLocationPin(BuildContext context, WidgetRef ref) async {
  final allowed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const LocationPinConsentSheet(),
  );
  return allowed ?? false;
}

/// "We keep this pin to pick venues near you", with Allow and Not now. Pops true once the
/// consent is recorded.
class LocationPinConsentSheet extends ConsumerStatefulWidget {
  const LocationPinConsentSheet({super.key});

  @override
  ConsumerState<LocationPinConsentSheet> createState() => _LocationPinConsentSheetState();
}

class _LocationPinConsentSheetState extends ConsumerState<LocationPinConsentSheet> {
  bool _saving = false;
  String? _error;

  Future<List<LegalDocument>> _documents() async {
    final profile = await ref.read(myProfileProvider.future);
    return ref.read(legalDocumentsForCityProvider(profile.city).future);
  }

  Future<void> _allow() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final document = documentOf(await _documents(), DocumentKind.locationPin);
      if (document != null) {
        await ref.read(legalRepositoryProvider).recordConsents([
          ConsentChoice(kind: DocumentKind.locationPin, version: document.version, granted: true),
        ]);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _logger.w('⚠️  Could not record the pin consent (${e.runtimeType})');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = LegalCopy.pinFailed;
      });
    }
  }

  Future<void> _read() async {
    LegalDocument? document;
    try {
      document = documentOf(await _documents(), DocumentKind.locationPin);
    } catch (_) {
      // The website's page will do.
    }
    if (!mounted) return;
    await openLegalLink(context, ref, LegalLinks.urlFor(DocumentKind.locationPin, document));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(LegalCopy.pinTitle, style: textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(LegalCopy.pinBody, style: textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(LegalCopy.pinAlternative, style: textTheme.bodyMedium),
            TextButton(onPressed: _read, child: const Text(LegalCopy.pinLink)),
            if (_error != null) Text(_error!, style: textTheme.bodyMedium),
            const SizedBox(height: 12),
            AppButton(
              key: const Key('pin-allow'),
              label: LegalCopy.pinAllow,
              loading: _saving,
              onPressed: _saving ? null : _allow,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                key: const Key('pin-not-now'),
                style: AppTheme.quietLink,
                onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                child: const Text(LegalCopy.pinNotNow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
