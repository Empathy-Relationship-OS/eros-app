import 'package:firebase_auth/firebase_auth.dart';

/// A sign-in method that can meet an email with an account already (RFC-011 §5.4).
enum LinkingProvider {
  apple('Apple'),
  google('Google');

  const LinkingProvider(this.label);

  /// How the app names the method the user just tapped. Only ever this one: the app never says
  /// which method the existing account uses (D-10).
  final String label;
}

/// A Google or Apple sign-in waiting to be added to the account that already has its email.
///
/// Firebase answered `account-exists-with-different-credential` (one account per email, D-5), so
/// the user signs in with their password and the app then calls `linkWithCredential` with
/// [credential]. Kept in memory only, passed from screen to screen, never saved. [toString] hides
/// the email and the credential (primer rule 10).
class PendingAccountLink {
  const PendingAccountLink({
    required this.email,
    required this.credential,
    required this.provider,
  });

  /// The email Firebase reported for the existing account. Shown to the user, never logged.
  final String email;

  /// The credential from the sign-in that Firebase turned down. Never logged.
  final AuthCredential credential;

  /// The method the user tapped, and the one that gets added.
  final LinkingProvider provider;

  @override
  String toString() => 'PendingAccountLink(${provider.name})';
}
