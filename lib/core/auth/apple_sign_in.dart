import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Sign in with Apple (RFC-011 §5.3). iOS only (D-2): every Apple call and the button sit behind
/// [appleSignInSupported].

/// True on iOS, the only platform that offers Apple (D-2). Android never shows or calls Apple.
///
/// `defaultTargetPlatform` rather than `Platform.isIOS`, so widget tests can set the platform.
bool appleSignInSupported() => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Firebase's provider id for Apple, as it appears in `User.providerData`.
const appleProviderId = 'apple.com';

/// The two calls the app makes to the `sign_in_with_apple` plugin, so tests can fake them.
class AppleSignInClient {
  const AppleSignInClient();

  /// Shows Apple's sheet. [nonce] is embedded in the identity token Apple returns.
  Future<AuthorizationCredentialAppleID> getAppleIDCredential({
    required List<AppleIDAuthorizationScopes> scopes,
    required String nonce,
  }) =>
      SignInWithApple.getAppleIDCredential(scopes: scopes, nonce: nonce);

  /// Whether the Apple ID [appleUserId] still lets Muse sign in. No sheet.
  Future<CredentialState> getCredentialState(String appleUserId) =>
      SignInWithApple.getCredentialState(appleUserId);
}

final appleSignInClientProvider = Provider<AppleSignInClient>((ref) => const AppleSignInClient());

/// One Apple authorisation from `AuthRepository.requestAppleAuthorization`: what Firebase needs to
/// sign in, the name Apple sends only the first time, and the authorization code that SI-F4 hands
/// to `revokeTokenWithAuthorizationCode`.
///
/// Holds secrets: never log it or put it in a crash report (primer rule 10). [toString] says
/// nothing about the contents.
class AppleAuthorization {
  /// The nonce before hashing. Apple got its SHA-256; Firebase needs this to check the token.
  final String rawNonce;
  final String? identityToken;

  /// Short-lived (five minutes) and single use.
  final String authorizationCode;

  /// Only on the user's first authorisation of Muse; null on every later one (D-7).
  final String? givenName;
  final String? familyName;

  const AppleAuthorization({
    required this.rawNonce,
    required this.identityToken,
    required this.authorizationCode,
    this.givenName,
    this.familyName,
  });

  /// The credential for `FirebaseAuth.signInWithCredential` (RFC-011 §5.3). Null without an
  /// identity token.
  OAuthCredential? get firebaseCredential {
    final token = identityToken;
    if (token == null) return null;
    return OAuthProvider(appleProviderId).credential(
      idToken: token,
      rawNonce: rawNonce,
      accessToken: authorizationCode,
    );
  }

  @override
  String toString() => 'AppleAuthorization(redacted)';
}

/// A fresh nonce for one Apple request: 32 random bytes from [Random.secure], base64url encoded.
String generateAppleNonce([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => source.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

/// The SHA-256 of [rawNonce] in hex: what Apple embeds in the identity token, and what Firebase
/// checks against the raw nonce.
String sha256OfNonce(String rawNonce) => sha256.convert(utf8.encode(rawNonce)).toString();
