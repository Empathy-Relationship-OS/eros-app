/// Dating intentions
enum DateIntentions {
  casualDating,
  seriousDating,
  friendship,
  networking,
  notSure;

  String get displayName {
    switch (this) {
      case DateIntentions.casualDating:
        return 'Casual Dating';
      case DateIntentions.seriousDating:
        return 'Serious Dating';
      case DateIntentions.friendship:
        return 'Friendship';
      case DateIntentions.networking:
        return 'Networking';
      case DateIntentions.notSure:
        return 'Not Sure';
    }
  }

  /// Convert to backend format (display name)
  String toBackend() => displayName;

  /// Parse from backend format (display name)
  static DateIntentions fromBackend(String value) {
    return DateIntentions.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => throw ArgumentError(
        'Invalid DateIntentions value: $value. Expected one of: ${DateIntentions.values.map((e) => e.displayName).join(", ")}',
      ),
    );
  }
}

/// Kids preference
enum KidsPreference {
  wantKids,
  dontWantKids,
  haveKids,
  openToKids,
  preferNotToSay;

  String get displayName {
    switch (this) {
      case KidsPreference.wantKids:
        return 'Want Kids';
      case KidsPreference.dontWantKids:
        return "Don't Want Kids";
      case KidsPreference.haveKids:
        return 'Have Kids';
      case KidsPreference.openToKids:
        return 'Open to Kids';
      case KidsPreference.preferNotToSay:
        return 'Prefer not to say';
    }
  }

  /// Convert to backend format (display name)
  String toBackend() => displayName;

  /// Parse from backend format (display name)
  static KidsPreference fromBackend(String value) {
    return KidsPreference.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => throw ArgumentError(
        'Invalid KidsPreference value: $value. Expected one of: ${KidsPreference.values.map((e) => e.displayName).join(", ")}',
      ),
    );
  }
}

/// Alcohol consumption habits
enum AlcoholConsumption {
  never,
  sometimes,
  regularly,
  preferNotToSay;

  String get displayName {
    switch (this) {
      case AlcoholConsumption.never:
        return 'Never';
      case AlcoholConsumption.sometimes:
        return 'Sometimes';
      case AlcoholConsumption.regularly:
        return 'Regularly';
      case AlcoholConsumption.preferNotToSay:
        return 'Prefer not to say';
    }
  }

  /// Convert to backend format (display name)
  String toBackend() => displayName;

  /// Parse from backend format (display name)
  static AlcoholConsumption fromBackend(String value) {
    return AlcoholConsumption.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => throw ArgumentError(
        'Invalid AlcoholConsumption value: $value. Expected one of: ${AlcoholConsumption.values.map((e) => e.displayName).join(", ")}',
      ),
    );
  }
}

/// Smoking status
enum SmokingStatus {
  never,
  sometimes,
  regularly,
  quitting,
  preferNotToSay;

  String get displayName {
    switch (this) {
      case SmokingStatus.never:
        return 'Never';
      case SmokingStatus.sometimes:
        return 'Sometimes';
      case SmokingStatus.regularly:
        return 'Regularly';
      case SmokingStatus.quitting:
        return 'Quitting';
      case SmokingStatus.preferNotToSay:
        return 'Prefer not to say';
    }
  }

  /// Convert to backend format (display name)
  String toBackend() => displayName;

  /// Parse from backend format (display name)
  static SmokingStatus fromBackend(String value) {
    return SmokingStatus.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => throw ArgumentError(
        'Invalid SmokingStatus value: $value. Expected one of: ${SmokingStatus.values.map((e) => e.displayName).join(", ")}',
      ),
    );
  }
}

/// Education level
enum EducationLevel {
  college,
  university,
  apprenticeship,
  preferNotToSay;

  String get displayName {
    switch (this) {
      case EducationLevel.college:
        return 'College';
      case EducationLevel.university:
        return 'University';
      case EducationLevel.apprenticeship:
        return 'Apprenticeship';
      case EducationLevel.preferNotToSay:
        return 'Prefer not to say';
    }
  }

  /// Convert to backend format (display name)
  String toBackend() => displayName;

  /// Parse from backend format (display name)
  static EducationLevel fromBackend(String value) {
    return EducationLevel.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => throw ArgumentError(
        'Invalid EducationLevel value: $value. Expected one of: ${EducationLevel.values.map((e) => e.displayName).join(", ")}',
      ),
    );
  }
}

/// Relationship type preference
enum RelationshipType {
  monogamous,
  nonMonogamous,
  open;

  String get displayName {
    switch (this) {
      case RelationshipType.monogamous:
        return 'Monogamous';
      case RelationshipType.nonMonogamous:
        return 'Non-Monogamous';
      case RelationshipType.open:
        return 'Open';
    }
  }

  /// Convert to backend format (display name)
  String toBackend() => displayName;

  /// Parse from backend format (display name)
  static RelationshipType fromBackend(String value) {
    return RelationshipType.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => throw ArgumentError(
        'Invalid RelationshipType value: $value. Expected one of: ${RelationshipType.values.map((e) => e.displayName).join(", ")}',
      ),
    );
  }
}

/// Sexual orientation
enum SexualOrientation {
  straight,
  gay,
  lesbian,
  bisexual,
  pansexual,
  asexual,
  questioning,
  other,
  preferNotToSay;

  String get displayName {
    switch (this) {
      case SexualOrientation.straight:
        return 'Straight';
      case SexualOrientation.gay:
        return 'Gay';
      case SexualOrientation.lesbian:
        return 'Lesbian';
      case SexualOrientation.bisexual:
        return 'Bisexual';
      case SexualOrientation.pansexual:
        return 'Pansexual';
      case SexualOrientation.asexual:
        return 'Asexual';
      case SexualOrientation.questioning:
        return 'Questioning';
      case SexualOrientation.other:
        return 'Other';
      case SexualOrientation.preferNotToSay:
        return 'Prefer not to say';
    }
  }

  /// Convert to backend format (display name)
  String toBackend() => displayName;

  /// Parse from backend format (display name)
  static SexualOrientation fromBackend(String value) {
    return SexualOrientation.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => throw ArgumentError(
        'Invalid SexualOrientation value: $value. Expected one of: ${SexualOrientation.values.map((e) => e.displayName).join(", ")}',
      ),
    );
  }
}

/// Pronouns
enum Pronouns {
  heHim,
  sheHer,
  theyThem,
  other,
  preferNotToSay;

  String get displayName {
    switch (this) {
      case Pronouns.heHim:
        return 'He/Him';
      case Pronouns.sheHer:
        return 'She/Her';
      case Pronouns.theyThem:
        return 'They/Them';
      case Pronouns.other:
        return 'Other';
      case Pronouns.preferNotToSay:
        return 'Prefer not to say';
    }
  }

  /// Convert to backend format (display name)
  String toBackend() => displayName;

  /// Parse from backend format (display name)
  static Pronouns fromBackend(String value) {
    return Pronouns.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => throw ArgumentError(
        'Invalid Pronouns value: $value. Expected one of: ${Pronouns.values.map((e) => e.displayName).join(", ")}',
      ),
    );
  }
}

/// Religion
enum Religion {
  christianity,
  islam,
  hinduism,
  buddhism,
  judaism,
  sikhism,
  atheist,
  agnostic,
  spiritual,
  other,
  preferNotToSay;

  String get displayName {
    switch (this) {
      case Religion.christianity:
        return 'Christianity';
      case Religion.islam:
        return 'Islam';
      case Religion.hinduism:
        return 'Hinduism';
      case Religion.buddhism:
        return 'Buddhism';
      case Religion.judaism:
        return 'Judaism';
      case Religion.sikhism:
        return 'Sikhism';
      case Religion.atheist:
        return 'Atheist';
      case Religion.agnostic:
        return 'Agnostic';
      case Religion.spiritual:
        return 'Spiritual';
      case Religion.other:
        return 'Other';
      case Religion.preferNotToSay:
        return 'Prefer not to say';
    }
  }

  /// Convert to backend format (display name)
  String toBackend() => displayName;

  /// Parse from backend format (display name)
  static Religion fromBackend(String value) {
    return Religion.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => throw ArgumentError(
        'Invalid Religion value: $value. Expected one of: ${Religion.values.map((e) => e.displayName).join(", ")}',
      ),
    );
  }
}

/// Political view
enum PoliticalView {
  liberal,
  moderate,
  conservative,
  apolitical,
  other,
  preferNotToSay;

  String get displayName {
    switch (this) {
      case PoliticalView.liberal:
        return 'Liberal';
      case PoliticalView.moderate:
        return 'Moderate';
      case PoliticalView.conservative:
        return 'Conservative';
      case PoliticalView.apolitical:
        return 'Apolitical';
      case PoliticalView.other:
        return 'Other';
      case PoliticalView.preferNotToSay:
        return 'Prefer not to say';
    }
  }

  /// Convert to backend format (display name)
  String toBackend() => displayName;

  /// Parse from backend format (display name)
  static PoliticalView fromBackend(String value) {
    return PoliticalView.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => throw ArgumentError(
        'Invalid PoliticalView value: $value. Expected one of: ${PoliticalView.values.map((e) => e.displayName).join(", ")}',
      ),
    );
  }
}

/// Diet preference
enum Diet {
  omnivore,
  flexitarian,
  vegetarian,
  vegan,
  pescatarian,
  halal,
  kosher,
  other,
  preferNotToSay;

  String get displayName {
    switch (this) {
      case Diet.omnivore:
        return 'Omnivore';
      case Diet.flexitarian:
        return 'Flexitarian';
      case Diet.vegetarian:
        return 'Vegetarian';
      case Diet.vegan:
        return 'Vegan';
      case Diet.pescatarian:
        return 'Pescatarian';
      case Diet.halal:
        return 'Halal';
      case Diet.kosher:
        return 'Kosher';
      case Diet.other:
        return 'Other';
      case Diet.preferNotToSay:
        return 'Prefer not to say';
    }
  }

  /// Convert to backend format (display name)
  String toBackend() => displayName;

  /// Parse from backend format (display name)
  static Diet fromBackend(String value) {
    return Diet.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => throw ArgumentError(
        'Invalid Diet value: $value. Expected one of: ${Diet.values.map((e) => e.displayName).join(", ")}',
      ),
    );
  }
}

/// Ethnicity
enum Ethnicity {
  blackAfricanDescent,
  eastAsian,
  hispanicLatino,
  middleEastern,
  nativeAmerican,
  pacificIslander,
  southAsian,
  southeastAsian,
  whiteCaucasian,
  other;

  String get displayName {
    switch (this) {
      case Ethnicity.blackAfricanDescent:
        return 'Black/African Descent';
      case Ethnicity.eastAsian:
        return 'East Asian';
      case Ethnicity.hispanicLatino:
        return 'Hispanic/Latino';
      case Ethnicity.middleEastern:
        return 'Middle Eastern';
      case Ethnicity.nativeAmerican:
        return 'Native American';
      case Ethnicity.pacificIslander:
        return 'Pacific Islander';
      case Ethnicity.southAsian:
        return 'South Asian';
      case Ethnicity.southeastAsian:
        return 'Southeast Asian';
      case Ethnicity.whiteCaucasian:
        return 'White/Caucasian';
      case Ethnicity.other:
        return 'Other';
    }
  }

  /// Convert to backend format (display name)
  String toBackend() => displayName;

  /// Parse from backend format (display name)
  static Ethnicity fromBackend(String value) {
    return Ethnicity.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => throw ArgumentError(
        'Invalid Ethnicity value: $value. Expected one of: ${Ethnicity.values.map((e) => e.displayName).join(", ")}',
      ),
    );
  }
}

/// Brain attributes - neurodiversity and mental health
/// Optional multi-select field with description support
enum BrainAttribute {
  adhd,
  learningDisability,
  mentalHealthChallenges,
  hsp, // Highly Sensitive Person
  autistic,
  neurodivergent;

  String get displayName {
    switch (this) {
      case BrainAttribute.adhd:
        return 'I have AD(H)D';
      case BrainAttribute.learningDisability:
        return 'I have a learning disability';
      case BrainAttribute.mentalHealthChallenges:
        return 'I have mental health challenges';
      case BrainAttribute.hsp:
        return "I'm an HSP";
      case BrainAttribute.autistic:
        return "I'm autistic";
      case BrainAttribute.neurodivergent:
        return "I'm neurodivergent";
    }
  }

  /// Convert to backend format (display name)
  String toBackend() => displayName;

  /// Parse from backend format (display name)
  static BrainAttribute fromBackend(String value) {
    return BrainAttribute.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => throw ArgumentError(
        'Invalid BrainAttribute value: $value. Expected one of: ${BrainAttribute.values.map((e) => e.displayName).join(", ")}',
      ),
    );
  }
}

/// Body attributes - physical health and accessibility
/// Optional multi-select field with description support
enum BodyAttribute {
  chronicIllness,
  visualImpairment,
  deaf,
  immunocompromised,
  mobilityAid,
  wheelchair;

  String get displayName {
    switch (this) {
      case BodyAttribute.chronicIllness:
        return 'I have a chronic illness';
      case BodyAttribute.visualImpairment:
        return 'I have a visual impairment';
      case BodyAttribute.deaf:
        return "I'm deaf";
      case BodyAttribute.immunocompromised:
        return "I'm immunocompromised";
      case BodyAttribute.mobilityAid:
        return 'I use a mobility aid';
      case BodyAttribute.wheelchair:
        return 'I use a wheelchair';
    }
  }

  /// Convert to backend format (display name)
  String toBackend() => displayName;

  /// Parse from backend format (display name)
  static BodyAttribute fromBackend(String value) {
    return BodyAttribute.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => throw ArgumentError(
        'Invalid BodyAttribute value: $value. Expected one of: ${BodyAttribute.values.map((e) => e.displayName).join(", ")}',
      ),
    );
  }
}
