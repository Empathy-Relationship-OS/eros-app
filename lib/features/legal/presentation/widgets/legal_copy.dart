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
