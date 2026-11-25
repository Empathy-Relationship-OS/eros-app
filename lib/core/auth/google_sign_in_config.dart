import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';

/// Google sign-in setup (RFC-011 §5.2).
///
/// The ids here are public OAuth client ids, not secrets.
class GoogleSignInConfig {
  GoogleSignInConfig._();

  /// The project's web OAuth client (`client_type: 3` in `android/app/google-services.json`, and
  /// Firebase → Authentication → Google → Web SDK configuration). Android needs it as the
  /// server client id to get an ID token that Firebase accepts. If SI-C1 regenerates the config
  /// files with a different web client, change it here too.
  ///
  /// iOS takes its own client id from `GIDClientID` in `ios/Runner/Info.plist` (the `CLIENT_ID`
  /// of `GoogleService-Info.plist`).
  static const String serverClientId =
      '785930119954-4bngqiu2rav7uc4fijh5cogpmprlr53l.apps.googleusercontent.com';
}

/// The Google sign-in client. A singleton in `google_sign_in` 7; tests override this provider.
final googleSignInProvider = Provider<GoogleSignIn>((ref) => GoogleSignIn.instance);

/// Initialises Google sign-in once, at start-up. `google_sign_in` 7 throws if `authenticate()`
/// runs before this. A failure here is logged and doesn't stop the app: the Google button then
/// fails with its "isn't available" message and email still works.
Future<void> initializeGoogleSignIn(GoogleSignIn googleSignIn, {Logger? logger}) async {
  try {
    await googleSignIn.initialize(serverClientId: GoogleSignInConfig.serverClientId);
  } catch (e) {
    (logger ?? Logger()).w('Google sign-in could not be initialised (${e.runtimeType})');
  }
}
