import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eros_app/core/constants/support_contact.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_photos_screen.dart';

/// Where the verification flow sends the user outside itself. Overridden in tests.
class VerificationLinks {
  const VerificationLinks();

  static final Uri privacyPolicy = Uri.parse('https://muse.app/privacy');

  Future<void> openPrivacyPolicy() async {
    await launchUrl(privacyPolicy, mode: LaunchMode.externalApplication);
  }

  /// Didit's ID check page (RFC-009 §5.3.2), in the phone's browser. False if it couldn't open.
  ///
  /// The system browser rather than an in-app tab: leaving the app is what makes it refetch the
  /// state when the user comes back, and the ID photo is taken in Didit's page, never by us
  /// (CF primer rule 19).
  Future<bool> openAgeCheck(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// An email to support, in the phone's mail app. False if there's no mail app to open.
  Future<bool> emailSupport({required String subject}) async {
    try {
      return await launchUrl(SupportContact.mailto(subject: subject));
    } catch (_) {
      return false;
    }
  }

  /// The app's page in the phone's Settings, to turn camera access back on.
  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// The profile photo editor, for someone with fewer than 3 photos. Completes when they leave.
  Future<void> openPhotoEditor(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EditPhotosScreen()));
}

final verificationLinksProvider = Provider<VerificationLinks>((ref) => const VerificationLinks());
