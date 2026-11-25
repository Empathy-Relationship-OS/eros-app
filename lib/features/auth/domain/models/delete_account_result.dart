/// What the user sees when `DELETE /users/me` fails. They stay signed in (RFC-011 §5.6).
const deleteAccountFailedMessage = "We couldn't delete your account. Try again.";

/// The outcome of `AuthRepository.deleteAccount` (RFC-011 §5.6, SI-F4).
class DeleteAccountResult {
  /// True once `DELETE /users/me` succeeded. Nothing after it can undo that.
  final bool isSuccess;

  /// Set when [isSuccess] is false.
  final String? errorMessage;

  /// False when the user signed in with Apple and Muse's Apple tokens weren't revoked: they
  /// closed Apple's sheet, revoking failed, or the device can't show Apple (Android). The app
  /// then asks them to remove Muse in their Apple ID settings (D-9). True for everyone else.
  final bool appleRevoked;

  /// False when the account was deleted but signing out failed.
  final bool signedOut;

  const DeleteAccountResult._({
    required this.isSuccess,
    this.errorMessage,
    this.appleRevoked = true,
    this.signedOut = false,
  });

  const DeleteAccountResult.deleted({required bool appleRevoked, required bool signedOut})
      : this._(isSuccess: true, appleRevoked: appleRevoked, signedOut: signedOut);

  const DeleteAccountResult.failure(String errorMessage)
      : this._(isSuccess: false, errorMessage: errorMessage);
}
