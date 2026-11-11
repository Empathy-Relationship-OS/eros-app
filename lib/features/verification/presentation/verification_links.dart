import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_photos_screen.dart';

/// Where the verification flow sends the user outside itself. Overridden in tests.
class VerificationLinks {
  const VerificationLinks();

  static final Uri privacyPolicy = Uri.parse('https://muse.app/privacy');

  Future<void> openPrivacyPolicy() async {
    await launchUrl(privacyPolicy, mode: LaunchMode.externalApplication);
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
