import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/verification/presentation/screens/verification_flow_screen.dart';

/// Opens selfie verification: consent, the camera, review, then the result (RFC-008 VF-F2).
///
/// The one entry point: the Profile row and the first-match card (VF-F3) and the wall on a
/// date (VF-F4) all call this. It completes when the flow closes, however it ended. The
/// verification status provider is refreshed by then if anything was submitted or refused, so
/// callers read the outcome from `verificationStatusProvider` rather than from this.
///
/// Full screen above any tab bar, on the root navigator.
Future<void> startVerification(BuildContext context, WidgetRef ref) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const VerificationFlowScreen(),
    ),
  );
}
