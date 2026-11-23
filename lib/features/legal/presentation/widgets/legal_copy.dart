import 'package:eros_app/features/legal/domain/models/legal_document.dart';

/// Short app copy for safety notices (RFC-009 §5.7, CF-F5). The legal wording is the
/// `FRAUD_NOTICE` document the server links to; this is the app's summary of it (primer rule 18).
/// No em dashes.
abstract final class SafetyNoticeCopy {
  static const String title = 'A safety notice';

  /// Says what happened without naming anyone: the API doesn't say who, and the app mustn't guess.
  static const String fraudContactBanned =
      "We've removed someone you spoke to on Muse because they broke our rules on fraud. If they "
      "asked you for money or personal details, don't send them, and contact your bank if you "
      'already have.';

  static const String readMore = 'Read more';
  static const String ok = 'OK';
}

/// Short UI copy for "Privacy, safety and legal" in Settings (CF-F3). The legal wording itself is
/// on the website, opened from each document's URL (primer rule 18). No em dashes.
class PrivacySettingsCopy {
  PrivacySettingsCopy._();

  static const String settingsSectionTitle = 'Privacy, safety and legal';
  static const String settingsRowTitle = 'Privacy, safety and legal';
  static const String settingsRowSubtitle = 'Documents, your choices, your data and your account';

  static const String screenTitle = 'Privacy, safety and legal';
  static const String loadFailed = "We couldn't load your privacy settings.";
  static const String retry = 'Try again';

  // Documents
  static const String documentsTitle = 'Documents';
  static const String noDocuments = 'No documents to show yet.';
  static const String linkFailed = "We couldn't open that page.";

  /// The title the app shows for a document of [kind].
  static String documentTitle(DocumentKind kind) => switch (kind) {
        DocumentKind.terms => 'Terms of use',
        DocumentKind.privacyNotice => 'Privacy notice',
        DocumentKind.safetyNotice => 'Safety notice',
        DocumentKind.datingBillOfRights => 'New York Dating Bill of Rights',
        DocumentKind.sensitiveData => 'Sensitive data',
        DocumentKind.locationPin => 'Starting pin location',
        DocumentKind.marketing => 'Marketing messages',
        DocumentKind.fraudNotice => 'Fraud notice',
      };

  // Choices
  static const String choicesTitle = 'Your choices';
  static const String marketingTitle = 'Marketing messages';
  static const String marketingSubtitle = 'News and offers from Muse';
  static const String locationPinTitle = 'Starting pin location';
  static const String locationPinSubtitle =
      'Lets us keep your starting pin to pick venues near you. Turning it off removes your pins.';
  static const String sensitiveDataTitle = 'Sensitive data';
  static const String sensitiveDataOn = 'On: your sexual orientation, ethnicity and religion';
  static const String sensitiveDataOff = 'Off';
  static const String notAvailableYet = 'Not available yet';
  static const String readMore = 'Read more';
  static const String choiceFailed = "We couldn't save that. Please try again.";
  static const String choiceStale =
      "We've updated this document since you opened the page. Read it and try again.";
  static const String choiceRequired = "This can't be turned off while you use Muse.";

  static const String sensitiveDataOffTitle = 'Turn off sensitive data?';
  static const String sensitiveDataOffBody =
      "We'll remove your religion and ethnicity and the filters that use them. We still need "
      "your sexual orientation to find you matches. If you don't want us to hold it, you can "
      'delete your account.';
  static const String sensitiveDataOffConfirm = 'Turn off';
  static const String sensitiveDataRetainedTitle = 'Sensitive data is off';
  static const String deleteAccountLink = 'Delete my account';
  static const String close = 'Close';
  static const String cancel = 'Cancel';

  static const String sensitiveDataOnTitle = 'Turn on sensitive data?';
  static const String sensitiveDataOnBody =
      'We use your sexual orientation, ethnicity and religion for your profile and to find you '
      'matches, including answers you hide.';
  static const String sensitiveDataOnConfirm = 'Turn on';

  // Your data
  static const String yourDataTitle = 'Your data';
  static const String requestDataTitle = 'Request my data';
  static const String requestDataSubtitle = 'Ask for a copy of your data, or to correct it';
  static const String complaintTitle = 'Make a complaint';
  static const String complaintSubtitle = 'Tell us about something we did with your data';

  /// The subject of the "Request my data" email.
  static const String dataRequestSubject = 'Data request';

  /// The subject of the "Make a complaint" email.
  static const String complaintSubject = 'Complaint';

  /// The whole body of a support email: the account id and nothing else personal.
  static String supportEmailBody(String accountId) => 'Account id: $accountId\n\n';

  static String noEmailApp(String address) => 'No email app found. Write to us at $address.';

  // Account
  static const String accountTitle = 'Account';
  static const String deleteAccountTitle = 'Delete account';
  static const String deleteAccountConfirmTitle = 'Delete your account?';
  static const String deleteAccountConfirmBody =
      'Your account closes now and your data is erased after 30 days. Your dates and payments '
      'are kept as records.';
  static const String deleteAccountConfirm = 'Delete account';
  static const String deleteAccountFailed = "We couldn't delete your account. Please try again.";
  static const String signOutFailed =
      'Your account is closed, but we could not sign you out. Please sign out.';
}

/// Short UI copy for the consents at sign-up, the re-consent screen and the starting pin
/// (CF-F1). The legal wording itself is on the website, opened from each document's URL (primer
/// rule 18). No em dashes.
class LegalCopy {
  LegalCopy._();

  /// The title the app shows for a document of [kind].
  static String documentTitle(DocumentKind kind) => switch (kind) {
        DocumentKind.terms => 'Terms of use',
        DocumentKind.privacyNotice => 'Privacy notice',
        DocumentKind.safetyNotice => 'Safety notice',
        DocumentKind.datingBillOfRights => 'New York Dating Bill of Rights',
        DocumentKind.sensitiveData => 'Sensitive data',
        DocumentKind.locationPin => 'Starting pin location',
        DocumentKind.marketing => 'Marketing messages',
        DocumentKind.fraudNotice => 'Fraud notice',
      };

  static const String read = 'Read';
  static String readHint(DocumentKind kind) => 'Read the ${documentTitle(kind)}';
  static const String linkFailed = "We couldn't open that page.";
  static const String loadFailed = "We couldn't load our documents. Check your connection.";
  static const String retry = 'Try again';

  // Auth screen
  static const String authAgreePrefix = 'By continuing, you agree to our';
  static const String authTerms = 'Terms of use';
  static const String authAnd = 'and';
  static const String authPrivacy = 'Privacy notice';

  // Final sign-up step
  static String termsWelcome(String firstName) => 'Welcome, $firstName!';
  static const String termsSubtitle = 'Before we begin, please read these and tell us you agree.';
  static const String agreeTermsAndPrivacy = 'I agree to the Terms of use and the Privacy notice';
  static const String acknowledgeSafety = 'I have read the Safety notice';
  static const String acknowledgeBillOfRights = 'I have read the New York Dating Bill of Rights';
  static const String marketingOptIn = 'Send me news and offers from Muse. You can stop any time.';
  static const String acceptAndContinue = 'Accept and continue';

  /// Shown on a sign-up step the server sent the user back to.
  /// The server wants a consent this build can't show.
  static const String updateToSignUp = 'Please update Muse to finish signing up.';

  static const String reviewAgain =
      'Something changed since you agreed. Please read it again and tick to carry on.';

  // Sensitive data
  static const String sensitiveTitle = 'About your more personal answers';
  static const String sensitiveWhat =
      'Next we ask about your sexual orientation, your ethnicity and your religion.';
  static const String sensitiveUse =
      'We use these answers to build your profile and to find your matches. Matching uses them '
      'even if you choose to hide an answer from your profile.';
  static const String sensitiveLink = 'How we handle sensitive data';
  static const String sensitiveAgree =
      'I agree that Muse can use my orientation, ethnicity and religion for my profile and '
      'for matching';
  static const String sensitiveRequired =
      "Matching can't work without these, so you need to agree to carry on with sign-up.";
  static const String continueLabel = 'Continue';

  // Re-consent
  static const String reconsentTitle = 'We have updated our documents';
  static const String reconsentBody = 'Please read what changed and accept to keep using Muse.';
  static const String reconsentUnknown = 'Something else changed too. Update Muse to read it.';
  static const String reconsentStale = 'One of these changed again just now. Please look again.';
  static const String reconsentFailed = "We couldn't save that. Please try again.";
  static const String signOut = 'Sign out';
  static const String signOutMessage =
      'You can sign back in later. You will be asked to accept these then.';

  // Starting pin
  static const String pinTitle = 'Keep your starting pin?';
  static const String pinBody =
      'We keep this pin to pick venues near you. Only you can see it.';
  static const String pinAlternative =
      'Rather not? Use the city centre instead. That needs no permission.';
  static const String pinLink = 'How we use your starting pin';
  static const String pinAllow = 'Allow';
  static const String pinNotNow = 'Not now';
  static const String pinNotSaved =
      'To keep a starting pin, allow us to store it. Or use the city centre instead.';
  static const String pinFailed = "We couldn't save your choice. Please try again.";
}
