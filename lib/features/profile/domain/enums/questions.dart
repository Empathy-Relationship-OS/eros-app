/// Predefined questions for Q&A section
/// Organized into 4 categories: Fun, Ambitions, Interests, Personal
enum PredefinedQuestion {
  // Fun category
  lastMealEver,
  secondDateIdea,
  perfectHoliday,
  rainySundayActivity,
  mythicalCreatureRelate,
  weirdestFoodCombo,
  neverFailsToLaugh,
  lifeThemeSong,
  mostBeautifulView,
  superpowerForFun,
  dinnerWith3Famous,

  // Ambitions category
  wantToLearn,
  dreamJobNoMoney,
  lifeGoal,
  proudOf,
  wishReallyGoodAt,
  challengeSurprisedBeating,
  randomBucketList,
  idealPlaceToLive,
  lookingForwardTo,
  pointlessSkillProudOf,

  // Interests category
  talkAboutForHours,
  readingAtMoment,
  favouriteMusicArtist,
  favouriteBookMovieTv,
  thingsGiveJoy,
  everyoneShouldTry,
  currentlyObsessedSong,
  obscureFactKnow,
  activityLoseMyselfIn,
  fictionalCharacterRelate,
  nicheRabbitHole,

  // Personal category
  unusualFindAttractive,
  coreValues,
  randomFacts,
  mostAwkwardMoment,
  personalMotto,
  favouriteTattooStory,
  whatHomeMeans,
  bringsOutInnerChild,
  complimentNeverForgotten,
  friendsComeToMeFor,
  emojiCapturesEnergy,
  lookingFor,
  relationshipGoals;

  /// Get the display text for the question
  String get displayText {
    switch (this) {
      // Fun
      case PredefinedQuestion.lastMealEver:
        return 'My last meal ever would be';
      case PredefinedQuestion.secondDateIdea:
        return 'If I could organize our second date, we would';
      case PredefinedQuestion.perfectHoliday:
        return 'My perfect holiday';
      case PredefinedQuestion.rainySundayActivity:
        return 'What I like to do on a rainy Sunday';
      case PredefinedQuestion.mythicalCreatureRelate:
        return 'The mythical creature I relate to most';
      case PredefinedQuestion.weirdestFoodCombo:
        return 'The weirdest food combination I enjoy';
      case PredefinedQuestion.neverFailsToLaugh:
        return 'This never fails to make me laugh';
      case PredefinedQuestion.lifeThemeSong:
        return 'If my life had a theme song, it would be';
      case PredefinedQuestion.mostBeautifulView:
        return 'The most beautiful view I have ever seen';
      case PredefinedQuestion.superpowerForFun:
        return 'A superpower I\'d like to have just for fun';
      case PredefinedQuestion.dinnerWith3Famous:
        return 'I\'d host dinner for these 3 famous people';

      // Ambitions
      case PredefinedQuestion.wantToLearn:
        return 'Something I still want to learn';
      case PredefinedQuestion.dreamJobNoMoney:
        return 'My dream job if money didn\'t matter';
      case PredefinedQuestion.lifeGoal:
        return 'A life goal of mine';
      case PredefinedQuestion.proudOf:
        return 'What I\'m proud of';
      case PredefinedQuestion.wishReallyGoodAt:
        return 'Something I wish I was really good at';
      case PredefinedQuestion.challengeSurprisedBeating:
        return 'A challenge I surprised myself by beating';
      case PredefinedQuestion.randomBucketList:
        return 'The most random thing on my bucket list';
      case PredefinedQuestion.idealPlaceToLive:
        return 'My ideal place to live';
      case PredefinedQuestion.lookingForwardTo:
        return 'Something I\'m currently looking forward to';
      case PredefinedQuestion.pointlessSkillProudOf:
        return 'A pointless skill I\'m oddly proud of';

      // Interests
      case PredefinedQuestion.talkAboutForHours:
        return 'Something I could talk about for hours';
      case PredefinedQuestion.readingAtMoment:
        return 'What I\'m reading at the moment';
      case PredefinedQuestion.favouriteMusicArtist:
        return 'My favourite music artist or band';
      case PredefinedQuestion.favouriteBookMovieTv:
        return 'My favourite book/movie/tv series';
      case PredefinedQuestion.thingsGiveJoy:
        return 'Things that give me joy';
      case PredefinedQuestion.everyoneShouldTry:
        return 'What everyone should try at least once';
      case PredefinedQuestion.currentlyObsessedSong:
        return 'The song I\'m currently obsessed with';
      case PredefinedQuestion.obscureFactKnow:
        return 'The most obscure fact I know';
      case PredefinedQuestion.activityLoseMyselfIn:
        return 'An activity I lose myself in';
      case PredefinedQuestion.fictionalCharacterRelate:
        return 'The fictional character I relate to most';
      case PredefinedQuestion.nicheRabbitHole:
        return 'A niche rabbit hole that fascinates me';

      // Personal
      case PredefinedQuestion.unusualFindAttractive:
        return 'Something unusual I find attractive in a person';
      case PredefinedQuestion.coreValues:
        return 'My core values';
      case PredefinedQuestion.randomFacts:
        return 'Random facts about me';
      case PredefinedQuestion.mostAwkwardMoment:
        return 'Most awkward moment of my life';
      case PredefinedQuestion.personalMotto:
        return 'My personal motto';
      case PredefinedQuestion.favouriteTattooStory:
        return 'The story behind my favourite tattoo';
      case PredefinedQuestion.whatHomeMeans:
        return 'What \'home\' means to me';
      case PredefinedQuestion.bringsOutInnerChild:
        return 'What brings out my inner child';
      case PredefinedQuestion.complimentNeverForgotten:
        return 'A compliment I\'ve never forgotten';
      case PredefinedQuestion.friendsComeToMeFor:
        return 'Friends always come to me for';
      case PredefinedQuestion.emojiCapturesEnergy:
        return 'The emoji(s) that captures my energy best';
      case PredefinedQuestion.lookingFor:
        return 'I\'m looking for';
      case PredefinedQuestion.relationshipGoals:
        return 'My relationship goals';
    }
  }

  /// Get the category this question belongs to
  QuestionCategory get category {
    if ([
      PredefinedQuestion.lastMealEver,
      PredefinedQuestion.secondDateIdea,
      PredefinedQuestion.perfectHoliday,
      PredefinedQuestion.rainySundayActivity,
      PredefinedQuestion.mythicalCreatureRelate,
      PredefinedQuestion.weirdestFoodCombo,
      PredefinedQuestion.neverFailsToLaugh,
      PredefinedQuestion.lifeThemeSong,
      PredefinedQuestion.mostBeautifulView,
      PredefinedQuestion.superpowerForFun,
      PredefinedQuestion.dinnerWith3Famous,
    ].contains(this)) {
      return QuestionCategory.fun;
    }

    if ([
      PredefinedQuestion.wantToLearn,
      PredefinedQuestion.dreamJobNoMoney,
      PredefinedQuestion.lifeGoal,
      PredefinedQuestion.proudOf,
      PredefinedQuestion.wishReallyGoodAt,
      PredefinedQuestion.challengeSurprisedBeating,
      PredefinedQuestion.randomBucketList,
      PredefinedQuestion.idealPlaceToLive,
      PredefinedQuestion.lookingForwardTo,
      PredefinedQuestion.pointlessSkillProudOf,
    ].contains(this)) {
      return QuestionCategory.ambitions;
    }

    if ([
      PredefinedQuestion.talkAboutForHours,
      PredefinedQuestion.readingAtMoment,
      PredefinedQuestion.favouriteMusicArtist,
      PredefinedQuestion.favouriteBookMovieTv,
      PredefinedQuestion.thingsGiveJoy,
      PredefinedQuestion.everyoneShouldTry,
      PredefinedQuestion.currentlyObsessedSong,
      PredefinedQuestion.obscureFactKnow,
      PredefinedQuestion.activityLoseMyselfIn,
      PredefinedQuestion.fictionalCharacterRelate,
      PredefinedQuestion.nicheRabbitHole,
    ].contains(this)) {
      return QuestionCategory.interests;
    }

    return QuestionCategory.personal;
  }

  String toBackend() => name.toUpperCase();

  static PredefinedQuestion fromBackend(String value) {
    return PredefinedQuestion.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => throw ArgumentError('Invalid PredefinedQuestion value: $value'),
    );
  }
}

/// Question categories for organizing the Q&A section
enum QuestionCategory {
  fun,
  ambitions,
  interests,
  personal;

  String get displayName {
    switch (this) {
      case QuestionCategory.fun:
        return 'Fun';
      case QuestionCategory.ambitions:
        return 'Ambitions';
      case QuestionCategory.interests:
        return 'Interests';
      case QuestionCategory.personal:
        return 'Personal';
    }
  }

  /// Get all questions in this category
  List<PredefinedQuestion> get questions {
    return PredefinedQuestion.values
        .where((q) => q.category == this)
        .toList();
  }
}
