import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eros_app/core/config/support_config.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_copy.dart';

/// What a support email from the app is about. The ops team handles both from the support
/// mailbox (RFC-009 §5.10, D-9).
enum SupportRequest {
  dataRequest(PrivacySettingsCopy.dataRequestSubject),
  complaint(PrivacySettingsCopy.complaintSubject),

  /// From the "account deleted" screen: a deleted user asking to use Muse again (RFC-011 D-12).
  deletedAccount(PrivacySettingsCopy.deletedAccountSubject);

  final String subject;

  const SupportRequest(this.subject);
}

/// The `mailto:` link for [request]: the subject line, and a body with [accountId] and nothing
/// else personal.
///
/// Encoded by hand with `%20` for spaces: [Uri.queryParameters] would write `+`, which some mail
/// apps show as is.
Uri supportEmailUri(SupportRequest request, String accountId, {String? to}) {
  final address = to ?? SupportConfig.supportEmail;
  final subject = Uri.encodeComponent(request.subject);
  final body = Uri.encodeComponent(PrivacySettingsCopy.supportEmailBody(accountId));
  return Uri.parse('mailto:$address?subject=$subject&body=$body');
}

/// Opens links outside the app from "Privacy, safety and legal". Overridden in tests.
class LegalLinks {
  const LegalLinks();

  /// Opens a document's page in the browser. False if nothing could open it.
  Future<bool> openDocument(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Opens the mail app on [email]. False if there is no mail app.
  Future<bool> openEmail(Uri email) async {
    try {
      return await launchUrl(email);
    } catch (_) {
      return false;
    }
  }
}

final legalLinksProvider = Provider<LegalLinks>((ref) => const LegalLinks());
