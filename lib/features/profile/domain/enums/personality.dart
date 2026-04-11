/// Personality traits and lifestyle attributes
enum Trait {
  adventurous,
  ambitious,
  spontaneous,
  energetic,
  honest,
  witty,
  familyOrientated,
  minimalist,
  healthConscious,
  competitionSeeker,
  ambivert,
  calm,
  caring,
  chaotic,
  creative,
  curious,
  deepThinker,
  dreamer,
  empathetic,
  extravert,
  flexible,
  generous,
  goGetter,
  introvert,
  kind,
  listener,
  openMinded,
  optimistic,
  organized,
  outgoing,
  passionate,
  patient,
  playful,
  practical,
  quiet,
  reliable,
  reserved,
  romantic,
  sarcastic,
  sensitive,
  serious,
  shy,
  thoughtful,
  traditional;

  String get displayName {
    switch (this) {
      case Trait.adventurous:
        return 'Adventurous';
      case Trait.ambitious:
        return 'Ambitious';
      case Trait.spontaneous:
        return 'Spontaneous';
      case Trait.energetic:
        return 'Energetic';
      case Trait.honest:
        return 'Honest';
      case Trait.witty:
        return 'Witty';
      case Trait.familyOrientated:
        return 'Family Orientated';
      case Trait.minimalist:
        return 'Minimalist';
      case Trait.healthConscious:
        return 'Health Conscious';
      case Trait.competitionSeeker:
        return 'Competition Seeker';
      case Trait.ambivert:
        return 'Ambivert';
      case Trait.calm:
        return 'Calm';
      case Trait.caring:
        return 'Caring';
      case Trait.chaotic:
        return 'Chaotic';
      case Trait.creative:
        return 'Creative';
      case Trait.curious:
        return 'Curious';
      case Trait.deepThinker:
        return 'Deep Thinker';
      case Trait.dreamer:
        return 'Dreamer';
      case Trait.empathetic:
        return 'Empathetic';
      case Trait.extravert:
        return 'Extravert';
      case Trait.flexible:
        return 'Flexible';
      case Trait.generous:
        return 'Generous';
      case Trait.goGetter:
        return 'Go Getter';
      case Trait.introvert:
        return 'Introvert';
      case Trait.kind:
        return 'Kind';
      case Trait.listener:
        return 'Listener';
      case Trait.openMinded:
        return 'Open Minded';
      case Trait.optimistic:
        return 'Optimistic';
      case Trait.organized:
        return 'Organized';
      case Trait.outgoing:
        return 'Outgoing';
      case Trait.passionate:
        return 'Passionate';
      case Trait.patient:
        return 'Patient';
      case Trait.playful:
        return 'Playful';
      case Trait.practical:
        return 'Practical';
      case Trait.quiet:
        return 'Quiet';
      case Trait.reliable:
        return 'Reliable';
      case Trait.reserved:
        return 'Reserved';
      case Trait.romantic:
        return 'Romantic';
      case Trait.sarcastic:
        return 'Sarcastic';
      case Trait.sensitive:
        return 'Sensitive';
      case Trait.serious:
        return 'Serious';
      case Trait.shy:
        return 'Shy';
      case Trait.thoughtful:
        return 'Thoughtful';
      case Trait.traditional:
        return 'Traditional';
    }
  }

  String toBackend() => name.toUpperCase();

  static Trait fromBackend(String value) {
    return Trait.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => throw ArgumentError('Invalid Trait value: $value'),
    );
  }
}

/// Astrological star signs
enum StarSign {
  aries,
  taurus,
  gemini,
  cancer,
  leo,
  virgo,
  libra,
  scorpio,
  sagittarius,
  capricorn,
  aquarius,
  pisces;

  String get displayName {
    switch (this) {
      case StarSign.aries:
        return 'Aries';
      case StarSign.taurus:
        return 'Taurus';
      case StarSign.gemini:
        return 'Gemini';
      case StarSign.cancer:
        return 'Cancer';
      case StarSign.leo:
        return 'Leo';
      case StarSign.virgo:
        return 'Virgo';
      case StarSign.libra:
        return 'Libra';
      case StarSign.scorpio:
        return 'Scorpio';
      case StarSign.sagittarius:
        return 'Sagittarius';
      case StarSign.capricorn:
        return 'Capricorn';
      case StarSign.aquarius:
        return 'Aquarius';
      case StarSign.pisces:
        return 'Pisces';
    }
  }

  String toBackend() => name.toUpperCase();

  static StarSign fromBackend(String value) {
    return StarSign.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => throw ArgumentError('Invalid StarSign value: $value'),
    );
  }
}
