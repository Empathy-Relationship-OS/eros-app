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
        return 'Casual dating';
      case DateIntentions.seriousDating:
        return 'Serious dating';
      case DateIntentions.friendship:
        return 'Friendship';
      case DateIntentions.networking:
        return 'Networking';
      case DateIntentions.notSure:
        return 'Not sure';
    }
  }

  String toBackend() {
    switch (this) {
      case DateIntentions.casualDating:
        return 'CASUAL_DATING';
      case DateIntentions.seriousDating:
        return 'SERIOUS_DATING';
      case DateIntentions.friendship:
        return 'FRIENDSHIP';
      case DateIntentions.networking:
        return 'NETWORKING';
      case DateIntentions.notSure:
        return 'NOT_SURE';
    }
  }

  static DateIntentions fromBackend(String value) {
    switch (value) {
      case 'CASUAL_DATING':
        return DateIntentions.casualDating;
      case 'SERIOUS_DATING':
        return DateIntentions.seriousDating;
      case 'FRIENDSHIP':
        return DateIntentions.friendship;
      case 'NETWORKING':
        return DateIntentions.networking;
      case 'NOT_SURE':
        return DateIntentions.notSure;
      default:
        throw ArgumentError('Invalid DateIntentions value: $value');
    }
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
        return 'Want kids';
      case KidsPreference.dontWantKids:
        return "Don't want kids";
      case KidsPreference.haveKids:
        return 'Have kids';
      case KidsPreference.openToKids:
        return 'Open to kids';
      case KidsPreference.preferNotToSay:
        return 'Prefer not to say';
    }
  }

  String toBackend() {
    switch (this) {
      case KidsPreference.wantKids:
        return 'WANT_KIDS';
      case KidsPreference.dontWantKids:
        return 'DONT_WANT_KIDS';
      case KidsPreference.haveKids:
        return 'HAVE_KIDS';
      case KidsPreference.openToKids:
        return 'OPEN_TO_KIDS';
      case KidsPreference.preferNotToSay:
        return 'PREFER_NOT_TO_SAY';
    }
  }

  static KidsPreference fromBackend(String value) {
    switch (value) {
      case 'WANT_KIDS':
        return KidsPreference.wantKids;
      case 'DONT_WANT_KIDS':
        return KidsPreference.dontWantKids;
      case 'HAVE_KIDS':
        return KidsPreference.haveKids;
      case 'OPEN_TO_KIDS':
        return KidsPreference.openToKids;
      case 'PREFER_NOT_TO_SAY':
        return KidsPreference.preferNotToSay;
      default:
        throw ArgumentError('Invalid KidsPreference value: $value');
    }
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

  String toBackend() {
    switch (this) {
      case AlcoholConsumption.never:
        return 'NEVER';
      case AlcoholConsumption.sometimes:
        return 'SOMETIMES';
      case AlcoholConsumption.regularly:
        return 'REGULARLY';
      case AlcoholConsumption.preferNotToSay:
        return 'PREFER_NOT_TO_SAY';
    }
  }

  static AlcoholConsumption fromBackend(String value) {
    switch (value) {
      case 'NEVER':
        return AlcoholConsumption.never;
      case 'SOMETIMES':
        return AlcoholConsumption.sometimes;
      case 'REGULARLY':
        return AlcoholConsumption.regularly;
      case 'PREFER_NOT_TO_SAY':
        return AlcoholConsumption.preferNotToSay;
      default:
        throw ArgumentError('Invalid AlcoholConsumption value: $value');
    }
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

  String toBackend() {
    switch (this) {
      case SmokingStatus.never:
        return 'NEVER';
      case SmokingStatus.sometimes:
        return 'SOMETIMES';
      case SmokingStatus.regularly:
        return 'REGULARLY';
      case SmokingStatus.quitting:
        return 'QUITTING';
      case SmokingStatus.preferNotToSay:
        return 'PREFER_NOT_TO_SAY';
    }
  }

  static SmokingStatus fromBackend(String value) {
    switch (value) {
      case 'NEVER':
        return SmokingStatus.never;
      case 'SOMETIMES':
        return SmokingStatus.sometimes;
      case 'REGULARLY':
        return SmokingStatus.regularly;
      case 'QUITTING':
        return SmokingStatus.quitting;
      case 'PREFER_NOT_TO_SAY':
        return SmokingStatus.preferNotToSay;
      default:
        throw ArgumentError('Invalid SmokingStatus value: $value');
    }
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

  String toBackend() {
    switch (this) {
      case EducationLevel.college:
        return 'COLLEGE';
      case EducationLevel.university:
        return 'UNIVERSITY';
      case EducationLevel.apprenticeship:
        return 'APPRENTICESHIP';
      case EducationLevel.preferNotToSay:
        return 'PREFER_NOT_TO_SAY';
    }
  }

  static EducationLevel fromBackend(String value) {
    switch (value) {
      case 'COLLEGE':
        return EducationLevel.college;
      case 'UNIVERSITY':
        return EducationLevel.university;
      case 'APPRENTICESHIP':
        return EducationLevel.apprenticeship;
      case 'PREFER_NOT_TO_SAY':
        return EducationLevel.preferNotToSay;
      default:
        throw ArgumentError('Invalid EducationLevel value: $value');
    }
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
        return 'Non-monogamous';
      case RelationshipType.open:
        return 'Open';
    }
  }

  String toBackend() {
    switch (this) {
      case RelationshipType.monogamous:
        return 'MONOGAMOUS';
      case RelationshipType.nonMonogamous:
        return 'NON_MONOGAMOUS';
      case RelationshipType.open:
        return 'OPEN';
    }
  }

  static RelationshipType fromBackend(String value) {
    switch (value) {
      case 'MONOGAMOUS':
        return RelationshipType.monogamous;
      case 'NON_MONOGAMOUS':
        return RelationshipType.nonMonogamous;
      case 'OPEN':
        return RelationshipType.open;
      default:
        throw ArgumentError('Invalid RelationshipType value: $value');
    }
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

  String toBackend() {
    switch (this) {
      case SexualOrientation.straight:
        return 'STRAIGHT';
      case SexualOrientation.gay:
        return 'GAY';
      case SexualOrientation.lesbian:
        return 'LESBIAN';
      case SexualOrientation.bisexual:
        return 'BISEXUAL';
      case SexualOrientation.pansexual:
        return 'PANSEXUAL';
      case SexualOrientation.asexual:
        return 'ASEXUAL';
      case SexualOrientation.questioning:
        return 'QUESTIONING';
      case SexualOrientation.other:
        return 'OTHER';
      case SexualOrientation.preferNotToSay:
        return 'PREFER_NOT_TO_SAY';
    }
  }

  static SexualOrientation fromBackend(String value) {
    switch (value) {
      case 'STRAIGHT':
        return SexualOrientation.straight;
      case 'GAY':
        return SexualOrientation.gay;
      case 'LESBIAN':
        return SexualOrientation.lesbian;
      case 'BISEXUAL':
        return SexualOrientation.bisexual;
      case 'PANSEXUAL':
        return SexualOrientation.pansexual;
      case 'ASEXUAL':
        return SexualOrientation.asexual;
      case 'QUESTIONING':
        return SexualOrientation.questioning;
      case 'OTHER':
        return SexualOrientation.other;
      case 'PREFER_NOT_TO_SAY':
        return SexualOrientation.preferNotToSay;
      default:
        throw ArgumentError('Invalid SexualOrientation value: $value');
    }
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

  String toBackend() {
    switch (this) {
      case Pronouns.heHim:
        return 'HE_HIM';
      case Pronouns.sheHer:
        return 'SHE_HER';
      case Pronouns.theyThem:
        return 'THEY_THEM';
      case Pronouns.other:
        return 'OTHER';
      case Pronouns.preferNotToSay:
        return 'PREFER_NOT_TO_SAY';
    }
  }

  static Pronouns fromBackend(String value) {
    switch (value) {
      case 'HE_HIM':
        return Pronouns.heHim;
      case 'SHE_HER':
        return Pronouns.sheHer;
      case 'THEY_THEM':
        return Pronouns.theyThem;
      case 'OTHER':
        return Pronouns.other;
      case 'PREFER_NOT_TO_SAY':
        return Pronouns.preferNotToSay;
      default:
        throw ArgumentError('Invalid Pronouns value: $value');
    }
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

  String toBackend() {
    switch (this) {
      case Religion.christianity:
        return 'CHRISTIANITY';
      case Religion.islam:
        return 'ISLAM';
      case Religion.hinduism:
        return 'HINDUISM';
      case Religion.buddhism:
        return 'BUDDHISM';
      case Religion.judaism:
        return 'JUDAISM';
      case Religion.sikhism:
        return 'SIKHISM';
      case Religion.atheist:
        return 'ATHEIST';
      case Religion.agnostic:
        return 'AGNOSTIC';
      case Religion.spiritual:
        return 'SPIRITUAL';
      case Religion.other:
        return 'OTHER';
      case Religion.preferNotToSay:
        return 'PREFER_NOT_TO_SAY';
    }
  }

  static Religion fromBackend(String value) {
    switch (value) {
      case 'CHRISTIANITY':
        return Religion.christianity;
      case 'ISLAM':
        return Religion.islam;
      case 'HINDUISM':
        return Religion.hinduism;
      case 'BUDDHISM':
        return Religion.buddhism;
      case 'JUDAISM':
        return Religion.judaism;
      case 'SIKHISM':
        return Religion.sikhism;
      case 'ATHEIST':
        return Religion.atheist;
      case 'AGNOSTIC':
        return Religion.agnostic;
      case 'SPIRITUAL':
        return Religion.spiritual;
      case 'OTHER':
        return Religion.other;
      case 'PREFER_NOT_TO_SAY':
        return Religion.preferNotToSay;
      default:
        throw ArgumentError('Invalid Religion value: $value');
    }
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

  String toBackend() {
    switch (this) {
      case PoliticalView.liberal:
        return 'LIBERAL';
      case PoliticalView.moderate:
        return 'MODERATE';
      case PoliticalView.conservative:
        return 'CONSERVATIVE';
      case PoliticalView.apolitical:
        return 'APOLITICAL';
      case PoliticalView.other:
        return 'OTHER';
      case PoliticalView.preferNotToSay:
        return 'PREFER_NOT_TO_SAY';
    }
  }

  static PoliticalView fromBackend(String value) {
    switch (value) {
      case 'LIBERAL':
        return PoliticalView.liberal;
      case 'MODERATE':
        return PoliticalView.moderate;
      case 'CONSERVATIVE':
        return PoliticalView.conservative;
      case 'APOLITICAL':
        return PoliticalView.apolitical;
      case 'OTHER':
        return PoliticalView.other;
      case 'PREFER_NOT_TO_SAY':
        return PoliticalView.preferNotToSay;
      default:
        throw ArgumentError('Invalid PoliticalView value: $value');
    }
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

  String toBackend() {
    switch (this) {
      case Diet.omnivore:
        return 'OMNIVORE';
      case Diet.flexitarian:
        return 'FLEXITARIAN';
      case Diet.vegetarian:
        return 'VEGETARIAN';
      case Diet.vegan:
        return 'VEGAN';
      case Diet.pescatarian:
        return 'PESCATARIAN';
      case Diet.halal:
        return 'HALAL';
      case Diet.kosher:
        return 'KOSHER';
      case Diet.other:
        return 'OTHER';
      case Diet.preferNotToSay:
        return 'PREFER_NOT_TO_SAY';
    }
  }

  static Diet fromBackend(String value) {
    switch (value) {
      case 'OMNIVORE':
        return Diet.omnivore;
      case 'FLEXITARIAN':
        return Diet.flexitarian;
      case 'VEGETARIAN':
        return Diet.vegetarian;
      case 'VEGAN':
        return Diet.vegan;
      case 'PESCATARIAN':
        return Diet.pescatarian;
      case 'HALAL':
        return Diet.halal;
      case 'KOSHER':
        return Diet.kosher;
      case 'OTHER':
        return Diet.other;
      case 'PREFER_NOT_TO_SAY':
        return Diet.preferNotToSay;
      default:
        throw ArgumentError('Invalid Diet value: $value');
    }
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

  String toBackend() {
    switch (this) {
      case Ethnicity.blackAfricanDescent:
        return 'BLACK_AFRICAN_DESCENT';
      case Ethnicity.eastAsian:
        return 'EAST_ASIAN';
      case Ethnicity.hispanicLatino:
        return 'HISPANIC_LATINO';
      case Ethnicity.middleEastern:
        return 'MIDDLE_EASTERN';
      case Ethnicity.nativeAmerican:
        return 'NATIVE_AMERICAN';
      case Ethnicity.pacificIslander:
        return 'PACIFIC_ISLANDER';
      case Ethnicity.southAsian:
        return 'SOUTH_ASIAN';
      case Ethnicity.southeastAsian:
        return 'SOUTHEAST_ASIAN';
      case Ethnicity.whiteCaucasian:
        return 'WHITE_CAUCASIAN';
      case Ethnicity.other:
        return 'OTHER';
    }
  }

  static Ethnicity fromBackend(String value) {
    switch (value) {
      case 'BLACK_AFRICAN_DESCENT':
        return Ethnicity.blackAfricanDescent;
      case 'EAST_ASIAN':
        return Ethnicity.eastAsian;
      case 'HISPANIC_LATINO':
        return Ethnicity.hispanicLatino;
      case 'MIDDLE_EASTERN':
        return Ethnicity.middleEastern;
      case 'NATIVE_AMERICAN':
        return Ethnicity.nativeAmerican;
      case 'PACIFIC_ISLANDER':
        return Ethnicity.pacificIslander;
      case 'SOUTH_ASIAN':
        return Ethnicity.southAsian;
      case 'SOUTHEAST_ASIAN':
        return Ethnicity.southeastAsian;
      case 'WHITE_CAUCASIAN':
        return Ethnicity.whiteCaucasian;
      case 'OTHER':
        return Ethnicity.other;
      default:
        throw ArgumentError('Invalid Ethnicity value: $value');
    }
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

  String toBackend() {
    switch (this) {
      case BrainAttribute.adhd:
        return 'ADHD';
      case BrainAttribute.learningDisability:
        return 'LEARNING_DISABILITY';
      case BrainAttribute.mentalHealthChallenges:
        return 'MENTAL_HEALTH_CHALLENGES';
      case BrainAttribute.hsp:
        return 'HSP';
      case BrainAttribute.autistic:
        return 'AUTISTIC';
      case BrainAttribute.neurodivergent:
        return 'NEURODIVERGENT';
    }
  }

  static BrainAttribute fromBackend(String value) {
    switch (value) {
      case 'ADHD':
        return BrainAttribute.adhd;
      case 'LEARNING_DISABILITY':
        return BrainAttribute.learningDisability;
      case 'MENTAL_HEALTH_CHALLENGES':
        return BrainAttribute.mentalHealthChallenges;
      case 'HSP':
        return BrainAttribute.hsp;
      case 'AUTISTIC':
        return BrainAttribute.autistic;
      case 'NEURODIVERGENT':
        return BrainAttribute.neurodivergent;
      default:
        throw ArgumentError('Invalid BrainAttribute value: $value');
    }
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

  String toBackend() {
    switch (this) {
      case BodyAttribute.chronicIllness:
        return 'CHRONIC_ILLNESS';
      case BodyAttribute.visualImpairment:
        return 'VISUAL_IMPAIRMENT';
      case BodyAttribute.deaf:
        return 'DEAF';
      case BodyAttribute.immunocompromised:
        return 'IMMUNOCOMPROMISED';
      case BodyAttribute.mobilityAid:
        return 'MOBILITY_AID';
      case BodyAttribute.wheelchair:
        return 'WHEELCHAIR';
    }
  }

  static BodyAttribute fromBackend(String value) {
    switch (value) {
      case 'CHRONIC_ILLNESS':
        return BodyAttribute.chronicIllness;
      case 'VISUAL_IMPAIRMENT':
        return BodyAttribute.visualImpairment;
      case 'DEAF':
        return BodyAttribute.deaf;
      case 'IMMUNOCOMPROMISED':
        return BodyAttribute.immunocompromised;
      case 'MOBILITY_AID':
        return BodyAttribute.mobilityAid;
      case 'WHEELCHAIR':
        return BodyAttribute.wheelchair;
      default:
        throw ArgumentError('Invalid BodyAttribute value: $value');
    }
  }
}
