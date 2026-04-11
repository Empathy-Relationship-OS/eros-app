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
  openRelationship,
  ethicallyNonMonogamous,
  preferNotToSay;

  String get displayName {
    switch (this) {
      case RelationshipType.monogamous:
        return 'Monogamous';
      case RelationshipType.openRelationship:
        return 'Open relationship';
      case RelationshipType.ethicallyNonMonogamous:
        return 'Ethically non-monogamous';
      case RelationshipType.preferNotToSay:
        return 'Prefer not to say';
    }
  }

  String toBackend() {
    switch (this) {
      case RelationshipType.monogamous:
        return 'MONOGAMOUS';
      case RelationshipType.openRelationship:
        return 'OPEN_RELATIONSHIP';
      case RelationshipType.ethicallyNonMonogamous:
        return 'ETHICALLY_NON_MONOGAMOUS';
      case RelationshipType.preferNotToSay:
        return 'PREFER_NOT_TO_SAY';
    }
  }

  static RelationshipType fromBackend(String value) {
    switch (value) {
      case 'MONOGAMOUS':
        return RelationshipType.monogamous;
      case 'OPEN_RELATIONSHIP':
        return RelationshipType.openRelationship;
      case 'ETHICALLY_NON_MONOGAMOUS':
        return RelationshipType.ethicallyNonMonogamous;
      case 'PREFER_NOT_TO_SAY':
        return RelationshipType.preferNotToSay;
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
  queer,
  questioning,
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
      case SexualOrientation.queer:
        return 'Queer';
      case SexualOrientation.questioning:
        return 'Questioning';
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
      case SexualOrientation.queer:
        return 'QUEER';
      case SexualOrientation.questioning:
        return 'QUESTIONING';
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
      case 'QUEER':
        return SexualOrientation.queer;
      case 'QUESTIONING':
        return SexualOrientation.questioning;
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
  other;

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
  leftWing,
  rightWing,
  centrist,
  apolitical,
  preferNotToSay;

  String get displayName {
    switch (this) {
      case PoliticalView.liberal:
        return 'Liberal';
      case PoliticalView.moderate:
        return 'Moderate';
      case PoliticalView.conservative:
        return 'Conservative';
      case PoliticalView.leftWing:
        return 'Left-wing';
      case PoliticalView.rightWing:
        return 'Right-wing';
      case PoliticalView.centrist:
        return 'Centrist';
      case PoliticalView.apolitical:
        return 'Apolitical';
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
      case PoliticalView.leftWing:
        return 'LEFT_WING';
      case PoliticalView.rightWing:
        return 'RIGHT_WING';
      case PoliticalView.centrist:
        return 'CENTRIST';
      case PoliticalView.apolitical:
        return 'APOLITICAL';
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
      case 'LEFT_WING':
        return PoliticalView.leftWing;
      case 'RIGHT_WING':
        return PoliticalView.rightWing;
      case 'CENTRIST':
        return PoliticalView.centrist;
      case 'APOLITICAL':
        return PoliticalView.apolitical;
      case 'PREFER_NOT_TO_SAY':
        return PoliticalView.preferNotToSay;
      default:
        throw ArgumentError('Invalid PoliticalView value: $value');
    }
  }
}

/// Diet preference
enum Diet {
  vegan,
  vegetarian,
  pescatarian,
  omnivore,
  keto,
  paleo,
  glutenFree,
  halal,
  kosher,
  other,
  preferNotToSay;

  String get displayName {
    switch (this) {
      case Diet.vegan:
        return 'Vegan';
      case Diet.vegetarian:
        return 'Vegetarian';
      case Diet.pescatarian:
        return 'Pescatarian';
      case Diet.omnivore:
        return 'Omnivore';
      case Diet.keto:
        return 'Keto';
      case Diet.paleo:
        return 'Paleo';
      case Diet.glutenFree:
        return 'Gluten-free';
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
      case Diet.vegan:
        return 'VEGAN';
      case Diet.vegetarian:
        return 'VEGETARIAN';
      case Diet.pescatarian:
        return 'PESCATARIAN';
      case Diet.omnivore:
        return 'OMNIVORE';
      case Diet.keto:
        return 'KETO';
      case Diet.paleo:
        return 'PALEO';
      case Diet.glutenFree:
        return 'GLUTEN_FREE';
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
      case 'VEGAN':
        return Diet.vegan;
      case 'VEGETARIAN':
        return Diet.vegetarian;
      case 'PESCATARIAN':
        return Diet.pescatarian;
      case 'OMNIVORE':
        return Diet.omnivore;
      case 'KETO':
        return Diet.keto;
      case 'PALEO':
        return Diet.paleo;
      case 'GLUTEN_FREE':
        return Diet.glutenFree;
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
  asian,
  black,
  hispanic,
  middleEastern,
  nativeAmerican,
  pacificIslander,
  white,
  mixed,
  other,
  preferNotToSay;

  String get displayName {
    switch (this) {
      case Ethnicity.asian:
        return 'Asian';
      case Ethnicity.black:
        return 'Black';
      case Ethnicity.hispanic:
        return 'Hispanic/Latino';
      case Ethnicity.middleEastern:
        return 'Middle Eastern';
      case Ethnicity.nativeAmerican:
        return 'Native American';
      case Ethnicity.pacificIslander:
        return 'Pacific Islander';
      case Ethnicity.white:
        return 'White';
      case Ethnicity.mixed:
        return 'Mixed';
      case Ethnicity.other:
        return 'Other';
      case Ethnicity.preferNotToSay:
        return 'Prefer not to say';
    }
  }

  String toBackend() {
    switch (this) {
      case Ethnicity.asian:
        return 'ASIAN';
      case Ethnicity.black:
        return 'BLACK';
      case Ethnicity.hispanic:
        return 'HISPANIC';
      case Ethnicity.middleEastern:
        return 'MIDDLE_EASTERN';
      case Ethnicity.nativeAmerican:
        return 'NATIVE_AMERICAN';
      case Ethnicity.pacificIslander:
        return 'PACIFIC_ISLANDER';
      case Ethnicity.white:
        return 'WHITE';
      case Ethnicity.mixed:
        return 'MIXED';
      case Ethnicity.other:
        return 'OTHER';
      case Ethnicity.preferNotToSay:
        return 'PREFER_NOT_TO_SAY';
    }
  }

  static Ethnicity fromBackend(String value) {
    switch (value) {
      case 'ASIAN':
        return Ethnicity.asian;
      case 'BLACK':
        return Ethnicity.black;
      case 'HISPANIC':
        return Ethnicity.hispanic;
      case 'MIDDLE_EASTERN':
        return Ethnicity.middleEastern;
      case 'NATIVE_AMERICAN':
        return Ethnicity.nativeAmerican;
      case 'PACIFIC_ISLANDER':
        return Ethnicity.pacificIslander;
      case 'WHITE':
        return Ethnicity.white;
      case 'MIXED':
        return Ethnicity.mixed;
      case 'OTHER':
        return Ethnicity.other;
      case 'PREFER_NOT_TO_SAY':
        return Ethnicity.preferNotToSay;
      default:
        throw ArgumentError('Invalid Ethnicity value: $value');
    }
  }
}

/// Brain attributes (thinking style)
enum BrainAttribute {
  analytical,
  creative,
  logical,
  intuitive,
  detailOriented,
  bigPictureThinker,
  strategic,
  spontaneous;

  String get displayName {
    switch (this) {
      case BrainAttribute.analytical:
        return 'Analytical';
      case BrainAttribute.creative:
        return 'Creative';
      case BrainAttribute.logical:
        return 'Logical';
      case BrainAttribute.intuitive:
        return 'Intuitive';
      case BrainAttribute.detailOriented:
        return 'Detail-oriented';
      case BrainAttribute.bigPictureThinker:
        return 'Big picture thinker';
      case BrainAttribute.strategic:
        return 'Strategic';
      case BrainAttribute.spontaneous:
        return 'Spontaneous';
    }
  }

  String toBackend() {
    switch (this) {
      case BrainAttribute.analytical:
        return 'ANALYTICAL';
      case BrainAttribute.creative:
        return 'CREATIVE';
      case BrainAttribute.logical:
        return 'LOGICAL';
      case BrainAttribute.intuitive:
        return 'INTUITIVE';
      case BrainAttribute.detailOriented:
        return 'DETAIL_ORIENTED';
      case BrainAttribute.bigPictureThinker:
        return 'BIG_PICTURE_THINKER';
      case BrainAttribute.strategic:
        return 'STRATEGIC';
      case BrainAttribute.spontaneous:
        return 'SPONTANEOUS';
    }
  }

  static BrainAttribute fromBackend(String value) {
    switch (value) {
      case 'ANALYTICAL':
        return BrainAttribute.analytical;
      case 'CREATIVE':
        return BrainAttribute.creative;
      case 'LOGICAL':
        return BrainAttribute.logical;
      case 'INTUITIVE':
        return BrainAttribute.intuitive;
      case 'DETAIL_ORIENTED':
        return BrainAttribute.detailOriented;
      case 'BIG_PICTURE_THINKER':
        return BrainAttribute.bigPictureThinker;
      case 'STRATEGIC':
        return BrainAttribute.strategic;
      case 'SPONTANEOUS':
        return BrainAttribute.spontaneous;
      default:
        throw ArgumentError('Invalid BrainAttribute value: $value');
    }
  }
}

/// Body attributes (physical attributes)
enum BodyAttribute {
  slim,
  athletic,
  average,
  curvy,
  muscular,
  heavyset,
  petite,
  tall;

  String get displayName {
    switch (this) {
      case BodyAttribute.slim:
        return 'Slim';
      case BodyAttribute.athletic:
        return 'Athletic';
      case BodyAttribute.average:
        return 'Average';
      case BodyAttribute.curvy:
        return 'Curvy';
      case BodyAttribute.muscular:
        return 'Muscular';
      case BodyAttribute.heavyset:
        return 'Heavyset';
      case BodyAttribute.petite:
        return 'Petite';
      case BodyAttribute.tall:
        return 'Tall';
    }
  }

  String toBackend() {
    switch (this) {
      case BodyAttribute.slim:
        return 'SLIM';
      case BodyAttribute.athletic:
        return 'ATHLETIC';
      case BodyAttribute.average:
        return 'AVERAGE';
      case BodyAttribute.curvy:
        return 'CURVY';
      case BodyAttribute.muscular:
        return 'MUSCULAR';
      case BodyAttribute.heavyset:
        return 'HEAVYSET';
      case BodyAttribute.petite:
        return 'PETITE';
      case BodyAttribute.tall:
        return 'TALL';
    }
  }

  static BodyAttribute fromBackend(String value) {
    switch (value) {
      case 'SLIM':
        return BodyAttribute.slim;
      case 'ATHLETIC':
        return BodyAttribute.athletic;
      case 'AVERAGE':
        return BodyAttribute.average;
      case 'CURVY':
        return BodyAttribute.curvy;
      case 'MUSCULAR':
        return BodyAttribute.muscular;
      case 'HEAVYSET':
        return BodyAttribute.heavyset;
      case 'PETITE':
        return BodyAttribute.petite;
      case 'TALL':
        return BodyAttribute.tall;
      default:
        throw ArgumentError('Invalid BodyAttribute value: $value');
    }
  }
}
