import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';
import 'package:eros_app/features/legal/presentation/legal_links.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_copy.dart';

/// Opens [url], and says so if the phone couldn't.
Future<void> openLegalLink(BuildContext context, WidgetRef ref, Uri url) async {
  final opened = await ref.read(legalLinksProvider).open(url);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(LegalCopy.linkFailed)));
  }
}

/// A document's title and a "Read" link to it. The wording is on the website (primer rule 18).
class LegalDocumentTile extends ConsumerWidget {
  final DocumentKind kind;

  /// The region's current document, or null to link to the website's page for [kind].
  final LegalDocument? document;

  const LegalDocumentTile({super.key, required this.kind, this.document});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, color: AppColors.primaryDeep),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                LegalCopy.documentTitle(kind),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Semantics(
              link: true,
              label: LegalCopy.readHint(kind),
              excludeSemantics: true,
              child: TextButton(
                key: Key('read-${kind.backendValue}'),
                onPressed: () => openLegalLink(context, ref, LegalLinks.urlFor(kind, document)),
                child: const Text(LegalCopy.read),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tick box with a label, for one consent. Starts unticked unless the user ticked it before.
class ConsentCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ConsentCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// Why the user is back on a sign-up step: the server wanted something agreed to again.
class ReviewAgainBanner extends StatelessWidget {
  const ReviewAgainBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Text(LegalCopy.reviewAgain, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
