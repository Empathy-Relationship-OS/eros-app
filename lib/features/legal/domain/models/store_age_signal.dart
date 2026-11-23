/// An app-store age signal (RFC-009 §5.3.1, D-13, CF-F6): what Apple's Declared Age Range or
/// Google's Play Age Signals said about the account holder's age.
///
/// The band is sensitive (primer rules 3 and 19): it is never logged, never written to
/// SharedPreferences, and only lives in memory until it is sent. [toString] redacts it.
library;

/// Which store the signal came from. The names are the backend's (`AgeSignalRequest.source`).
enum AgeSignalSource {
  /// Apple's Declared Age Range (iOS 26 and later).
  apple('APPLE'),

  /// Google's Play Age Signals.
  google('GOOGLE');

  const AgeSignalSource(this.backendName);

  final String backendName;
}

/// The store's age band for the account holder (`AgeSignalRequest.band`).
enum AgeBand {
  under13('UNDER_13'),
  age13To15('AGE_13_15'),
  age16To17('AGE_16_17'),

  /// 18 and over.
  adult('ADULT');

  const AgeBand(this.backendName);

  final String backendName;

  /// Every band but [adult]. A minor band stops sign-up; for an existing user the backend
  /// freezes the account for an operator to review.
  bool get isMinor => this != AgeBand.adult;
}

/// How the store verified the age, where it says (`AgeSignalRequest.verificationMethod`).
enum AgeSignalVerificationMethod {
  id('ID'),
  creditCard('CREDIT_CARD'),
  other('OTHER');

  const AgeSignalVerificationMethod(this.backendName);

  final String backendName;
}

/// One store's signal, as the app read it. An adult band is never an age check on its own
/// (the ID check is CF-F2); it only means the store gave no reason to stop.
class StoreAgeSignal {
  final AgeSignalSource source;
  final AgeBand band;
  final AgeSignalVerificationMethod? verificationMethod;

  const StoreAgeSignal({required this.source, required this.band, this.verificationMethod});

  bool get isMinor => band.isMinor;

  /// The `AgeSignalRequest` body. `verificationMethod` is left out when the store gave none.
  Map<String, dynamic> toJson() => {
        'source': source.backendName,
        'band': band.backendName,
        if (verificationMethod != null) 'verificationMethod': verificationMethod!.backendName,
      };

  @override
  bool operator ==(Object other) =>
      other is StoreAgeSignal &&
      other.source == source &&
      other.band == band &&
      other.verificationMethod == verificationMethod;

  @override
  int get hashCode => Object.hash(source, band, verificationMethod);

  /// Redacts the band (primer rule 3).
  @override
  String toString() =>
      'StoreAgeSignal(source: ${source.backendName}, band: REDACTED, '
      'verificationMethod: ${verificationMethod?.backendName})';
}
