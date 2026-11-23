import 'package:flutter/material.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';

/// The sign-up steps that take consents (RFC-009 §5.11), as registered in `main.dart`.
abstract final class LegalRoutes {
  /// The last basic-info step: terms, privacy, the safety notice, the regional document and
  /// marketing.
  static const String terms = '/profile-creation/terms';

  /// The sensitive data consent, just before the first special category question.
  static const String sensitiveData = '/profile-creation/preferences/sensitive-data';

  /// The step after [sensitiveData]: the earliest special category question.
  static const String afterSensitiveData = '/profile-creation/preferences/sexual-orientation';

  /// The kinds the [terms] step takes.
  static const Set<DocumentKind> termsStepKinds = {
    DocumentKind.terms,
    DocumentKind.privacyNotice,
    DocumentKind.safetyNotice,
    DocumentKind.datingBillOfRights,
    DocumentKind.marketing,
  };

  /// The step for the first of [missing] in the order sign-up asks: the terms step comes first.
  /// Null if none of them is taken at sign-up.
  static String? stepFor(Iterable<DocumentKind> missing) {
    if (missing.any(termsStepKinds.contains)) return terms;
    if (missing.contains(DocumentKind.sensitiveData)) return sensitiveData;
    return null;
  }

  /// Goes back to [route] if it is in the stack, or opens it. The profile draft keeps everything
  /// else, so the user walks the later steps again with them filled in.
  static void returnTo(BuildContext context, String route) {
    var found = false;
    Navigator.of(context).popUntil((r) {
      found = r.settings.name == route;
      return found || r.isFirst;
    });
    if (!found) Navigator.of(context).pushNamed(route);
  }
}
