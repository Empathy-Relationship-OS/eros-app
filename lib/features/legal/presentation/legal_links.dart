import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';

/// Opens legal documents. Overridden in tests.
class LegalLinks {
  const LegalLinks();

  /// The website's page for each kind (CF-W1), for screens shown before sign-in, when
  /// `GET /legal/documents` can't be called. Everywhere else the URL comes from the server's
  /// document (primer rule 18). The site keeps one stable path per kind.
  static final Map<DocumentKind, Uri> website = {
    DocumentKind.terms: Uri.parse('https://meetmymuse.com/terms'),
    DocumentKind.privacyNotice: Uri.parse('https://meetmymuse.com/privacy'),
    DocumentKind.safetyNotice: Uri.parse('https://meetmymuse.com/safety'),
    DocumentKind.datingBillOfRights:
        Uri.parse('https://meetmymuse.com/new-york-dating-bill-of-rights'),
    DocumentKind.sensitiveData: Uri.parse('https://meetmymuse.com/privacy#sensitive-data'),
    DocumentKind.locationPin: Uri.parse('https://meetmymuse.com/privacy#location'),
    DocumentKind.marketing: Uri.parse('https://meetmymuse.com/privacy#marketing'),
    DocumentKind.fraudNotice: Uri.parse('https://meetmymuse.com/fraud-notice'),
  };

  /// [document]'s URL, or the website's page for [kind] when there is no document in effect.
  static Uri urlFor(DocumentKind kind, LegalDocument? document) =>
      document == null ? website[kind]! : Uri.parse(document.url);

  /// Opens [url] in the browser. False if it couldn't.
  Future<bool> open(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

final legalLinksProvider = Provider<LegalLinks>((ref) => const LegalLinks());
