/// Sports and physical activities
enum Sport {
  kickBoxing,
  golf,
  kiteSurfing,
  athletics,
  badminton,
  ballet,
  baseball,
  basketball,
  bouldering,
  bowling,
  climbing,
  cricket,
  crossTraining,
  cycling,
  dancing,
  extremeSports,
  fencing,
  fitness,
  football,
  handball,
  hockey,
  horseRiding,
  iceSkating,
  kayaking,
  kitesurfing,
  martialArts,
  motorcycling,
  mountainbiking,
  padel,
  pickleball,
  pilates,
  rowing,
  rugby,
  running,
  sup,
  sailing,
  scubaDiving,
  skateboarding,
  skiing,
  snowboarding,
  spikeball,
  squash,
  surfing,
  swimming,
  tennis,
  volleyball,
  yoga;

  String get displayName {
    switch (this) {
      case Sport.kickBoxing:
        return 'Kick Boxing';
      case Sport.golf:
        return 'Golf';
      case Sport.kiteSurfing:
        return 'Kite Surfing';
      case Sport.athletics:
        return 'Athletics';
      case Sport.badminton:
        return 'Badminton';
      case Sport.ballet:
        return 'Ballet';
      case Sport.baseball:
        return 'Baseball';
      case Sport.basketball:
        return 'Basketball';
      case Sport.bouldering:
        return 'Bouldering';
      case Sport.bowling:
        return 'Bowling';
      case Sport.climbing:
        return 'Climbing';
      case Sport.cricket:
        return 'Cricket';
      case Sport.crossTraining:
        return 'Cross Training';
      case Sport.cycling:
        return 'Cycling';
      case Sport.dancing:
        return 'Dancing';
      case Sport.extremeSports:
        return 'Extreme Sports';
      case Sport.fencing:
        return 'Fencing';
      case Sport.fitness:
        return 'Fitness';
      case Sport.football:
        return 'Football';
      case Sport.handball:
        return 'Handball';
      case Sport.hockey:
        return 'Hockey';
      case Sport.horseRiding:
        return 'Horse Riding';
      case Sport.iceSkating:
        return 'Ice Skating';
      case Sport.kayaking:
        return 'Kayaking';
      case Sport.kitesurfing:
        return 'Kitesurfing';
      case Sport.martialArts:
        return 'Martial Arts';
      case Sport.motorcycling:
        return 'Motorcycling';
      case Sport.mountainbiking:
        return 'Mountain Biking';
      case Sport.padel:
        return 'Padel';
      case Sport.pickleball:
        return 'Pickleball';
      case Sport.pilates:
        return 'Pilates';
      case Sport.rowing:
        return 'Rowing';
      case Sport.rugby:
        return 'Rugby';
      case Sport.running:
        return 'Running';
      case Sport.sup:
        return 'SUP';
      case Sport.sailing:
        return 'Sailing';
      case Sport.scubaDiving:
        return 'Scuba Diving';
      case Sport.skateboarding:
        return 'Skateboarding';
      case Sport.skiing:
        return 'Skiing';
      case Sport.snowboarding:
        return 'Snowboarding';
      case Sport.spikeball:
        return 'Spikeball';
      case Sport.squash:
        return 'Squash';
      case Sport.surfing:
        return 'Surfing';
      case Sport.swimming:
        return 'Swimming';
      case Sport.tennis:
        return 'Tennis';
      case Sport.volleyball:
        return 'Volleyball';
      case Sport.yoga:
        return 'Yoga';
    }
  }

  String toBackend() => name.toUpperCase();

  static Sport fromBackend(String value) {
    return Sport.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => throw ArgumentError('Invalid Sport value: $value'),
    );
  }
}

/// Food and drink preferences
enum FoodAndDrink {
  bbq,
  barbecue,
  beer,
  biryani,
  boba,
  champagne,
  charcuterie,
  cheese,
  chocolate,
  cocktails,
  coffee,
  craftBeers,
  curry,
  empanada,
  falafel,
  hotPot,
  jollof,
  matcha,
  pasta,
  pizza,
  pubs,
  ramen,
  roti,
  sushi,
  tapas,
  tea,
  whiskey,
  wine;

  String get displayName {
    switch (this) {
      case FoodAndDrink.bbq:
        return 'BBQ';
      case FoodAndDrink.barbecue:
        return 'Barbecue';
      case FoodAndDrink.beer:
        return 'Beer';
      case FoodAndDrink.biryani:
        return 'Biryani';
      case FoodAndDrink.boba:
        return 'Boba';
      case FoodAndDrink.champagne:
        return 'Champagne';
      case FoodAndDrink.charcuterie:
        return 'Charcuterie';
      case FoodAndDrink.cheese:
        return 'Cheese';
      case FoodAndDrink.chocolate:
        return 'Chocolate';
      case FoodAndDrink.cocktails:
        return 'Cocktails';
      case FoodAndDrink.coffee:
        return 'Coffee';
      case FoodAndDrink.craftBeers:
        return 'Craft Beers';
      case FoodAndDrink.curry:
        return 'Curry';
      case FoodAndDrink.empanada:
        return 'Empanada';
      case FoodAndDrink.falafel:
        return 'Falafel';
      case FoodAndDrink.hotPot:
        return 'Hot Pot';
      case FoodAndDrink.jollof:
        return 'Jollof';
      case FoodAndDrink.matcha:
        return 'Matcha';
      case FoodAndDrink.pasta:
        return 'Pasta';
      case FoodAndDrink.pizza:
        return 'Pizza';
      case FoodAndDrink.pubs:
        return 'Pubs';
      case FoodAndDrink.ramen:
        return 'Ramen';
      case FoodAndDrink.roti:
        return 'Roti';
      case FoodAndDrink.sushi:
        return 'Sushi';
      case FoodAndDrink.tapas:
        return 'Tapas';
      case FoodAndDrink.tea:
        return 'Tea';
      case FoodAndDrink.whiskey:
        return 'Whiskey';
      case FoodAndDrink.wine:
        return 'Wine';
    }
  }

  String toBackend() => name.toUpperCase();

  static FoodAndDrink fromBackend(String value) {
    return FoodAndDrink.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => throw ArgumentError('Invalid FoodAndDrink value: $value'),
    );
  }
}

/// Creative pursuits
enum Creative {
  acting,
  composingMusic,
  crafts,
  diy,
  design,
  drawing,
  fashion,
  knitting,
  painting,
  photography,
  playingInstruments,
  poetry,
  pottery,
  sewing,
  singing,
  writing;

  String get displayName {
    switch (this) {
      case Creative.acting:
        return 'Acting';
      case Creative.composingMusic:
        return 'Composing Music';
      case Creative.crafts:
        return 'Crafts';
      case Creative.diy:
        return 'DIY';
      case Creative.design:
        return 'Design';
      case Creative.drawing:
        return 'Drawing';
      case Creative.fashion:
        return 'Fashion';
      case Creative.knitting:
        return 'Knitting';
      case Creative.painting:
        return 'Painting';
      case Creative.photography:
        return 'Photography';
      case Creative.playingInstruments:
        return 'Playing Instruments';
      case Creative.poetry:
        return 'Poetry';
      case Creative.pottery:
        return 'Pottery';
      case Creative.sewing:
        return 'Sewing';
      case Creative.singing:
        return 'Singing';
      case Creative.writing:
        return 'Writing';
    }
  }

  String toBackend() => name.toUpperCase();

  static Creative fromBackend(String value) {
    return Creative.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => throw ArgumentError('Invalid Creative value: $value'),
    );
  }
}

/// Entertainment preferences
enum Entertainment {
  reading,
  anime,
  boardGames,
  cartoons,
  chess,
  comedy,
  comics,
  disney,
  documentaries,
  fantasy,
  gaming,
  horror,
  memes,
  movies,
  musicals,
  netflix,
  podcasts,
  puzzles,
  sciFi,
  sitcoms,
  trueCrime,
  vinylRecords,
  youtube;

  String get displayName {
    switch (this) {
      case Entertainment.reading:
        return 'Reading';
      case Entertainment.anime:
        return 'Anime';
      case Entertainment.boardGames:
        return 'Board Games';
      case Entertainment.cartoons:
        return 'Cartoons';
      case Entertainment.chess:
        return 'Chess';
      case Entertainment.comedy:
        return 'Comedy';
      case Entertainment.comics:
        return 'Comics';
      case Entertainment.disney:
        return 'Disney';
      case Entertainment.documentaries:
        return 'Documentaries';
      case Entertainment.fantasy:
        return 'Fantasy';
      case Entertainment.gaming:
        return 'Gaming';
      case Entertainment.horror:
        return 'Horror';
      case Entertainment.memes:
        return 'Memes';
      case Entertainment.movies:
        return 'Movies';
      case Entertainment.musicals:
        return 'Musicals';
      case Entertainment.netflix:
        return 'Netflix';
      case Entertainment.podcasts:
        return 'Podcasts';
      case Entertainment.puzzles:
        return 'Puzzles';
      case Entertainment.sciFi:
        return 'Sci-Fi';
      case Entertainment.sitcoms:
        return 'Sitcoms';
      case Entertainment.trueCrime:
        return 'True Crime';
      case Entertainment.vinylRecords:
        return 'Vinyl Records';
      case Entertainment.youtube:
        return 'YouTube';
    }
  }

  String toBackend() => name.toUpperCase();

  static Entertainment fromBackend(String value) {
    return Entertainment.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => throw ArgumentError('Invalid Entertainment value: $value'),
    );
  }
}

/// Music genres
enum MusicGenre {
  afroBeats,
  blues,
  classicalMusic,
  countryMusic,
  djing,
  dancehall,
  disco,
  drumAndBass,
  drums,
  dubstep,
  edm,
  funk,
  guitar,
  hardstyle,
  hiphop,
  house,
  indieMusic,
  jazz,
  kPop,
  latinMusic,
  metal,
  piano,
  popMusic,
  punk,
  rAndB,
  rap,
  reggae,
  reggaeton,
  rock,
  salsa,
  soul,
  techno;

  String get displayName {
    switch (this) {
      case MusicGenre.afroBeats:
        return 'Afro Beats';
      case MusicGenre.blues:
        return 'Blues';
      case MusicGenre.classicalMusic:
        return 'Classical Music';
      case MusicGenre.countryMusic:
        return 'Country Music';
      case MusicGenre.djing:
        return 'DJing';
      case MusicGenre.dancehall:
        return 'Dancehall';
      case MusicGenre.disco:
        return 'Disco';
      case MusicGenre.drumAndBass:
        return 'Drum and Bass';
      case MusicGenre.drums:
        return 'Drums';
      case MusicGenre.dubstep:
        return 'Dubstep';
      case MusicGenre.edm:
        return 'EDM';
      case MusicGenre.funk:
        return 'Funk';
      case MusicGenre.guitar:
        return 'Guitar';
      case MusicGenre.hardstyle:
        return 'Hardstyle';
      case MusicGenre.hiphop:
        return 'Hip Hop';
      case MusicGenre.house:
        return 'House';
      case MusicGenre.indieMusic:
        return 'Indie Music';
      case MusicGenre.jazz:
        return 'Jazz';
      case MusicGenre.kPop:
        return 'K-Pop';
      case MusicGenre.latinMusic:
        return 'Latin Music';
      case MusicGenre.metal:
        return 'Metal';
      case MusicGenre.piano:
        return 'Piano';
      case MusicGenre.popMusic:
        return 'Pop Music';
      case MusicGenre.punk:
        return 'Punk';
      case MusicGenre.rAndB:
        return 'R&B';
      case MusicGenre.rap:
        return 'Rap';
      case MusicGenre.reggae:
        return 'Reggae';
      case MusicGenre.reggaeton:
        return 'Reggaeton';
      case MusicGenre.rock:
        return 'Rock';
      case MusicGenre.salsa:
        return 'Salsa';
      case MusicGenre.soul:
        return 'Soul';
      case MusicGenre.techno:
        return 'Techno';
    }
  }

  String toBackend() => name.toUpperCase();

  static MusicGenre fromBackend(String value) {
    return MusicGenre.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => throw ArgumentError('Invalid MusicGenre value: $value'),
    );
  }
}

/// Activities and hobbies
enum Activity {
  cityTrips,
  outdoors,
  pubQuiz,
  wellness,
  backpacking,
  baking,
  beach,
  camping,
  concerts,
  cooking,
  cosplay,
  diningOut,
  dinnerParties,
  escapeRooms,
  festivals,
  havingDrinks,
  hiking,
  karaoke,
  meditation,
  mountains,
  museum,
  party,
  resortVacations,
  roadTrips,
  sauna,
  shopping,
  takingAWalk,
  thrifting;

  String get displayName {
    switch (this) {
      case Activity.cityTrips:
        return 'City Trips';
      case Activity.outdoors:
        return 'Outdoors';
      case Activity.pubQuiz:
        return 'Pub Quiz';
      case Activity.wellness:
        return 'Wellness';
      case Activity.backpacking:
        return 'Backpacking';
      case Activity.baking:
        return 'Baking';
      case Activity.beach:
        return 'Beach';
      case Activity.camping:
        return 'Camping';
      case Activity.concerts:
        return 'Concerts';
      case Activity.cooking:
        return 'Cooking';
      case Activity.cosplay:
        return 'Cosplay';
      case Activity.diningOut:
        return 'Dining Out';
      case Activity.dinnerParties:
        return 'Dinner Parties';
      case Activity.escapeRooms:
        return 'Escape Rooms';
      case Activity.festivals:
        return 'Festivals';
      case Activity.havingDrinks:
        return 'Having Drinks';
      case Activity.hiking:
        return 'Hiking';
      case Activity.karaoke:
        return 'Karaoke';
      case Activity.meditation:
        return 'Meditation';
      case Activity.mountains:
        return 'Mountains';
      case Activity.museum:
        return 'Museum';
      case Activity.party:
        return 'Party';
      case Activity.resortVacations:
        return 'Resort Vacations';
      case Activity.roadTrips:
        return 'Road Trips';
      case Activity.sauna:
        return 'Sauna';
      case Activity.shopping:
        return 'Shopping';
      case Activity.takingAWalk:
        return 'Taking a Walk';
      case Activity.thrifting:
        return 'Thrifting';
    }
  }

  String toBackend() => name.toUpperCase();

  static Activity fromBackend(String value) {
    return Activity.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => throw ArgumentError('Invalid Activity value: $value'),
    );
  }
}

/// General interests and topics
enum Interest {
  entrepreneurship,
  formula1,
  languages,
  ai,
  animals,
  architecture,
  art,
  biology,
  cars,
  cats,
  cinema,
  dogs,
  finance,
  history,
  horses,
  nature,
  personalDevelopment,
  philosophy,
  plants,
  politics,
  programming,
  psychology,
  science,
  sneakers,
  sustainability,
  tattoos,
  tech,
  theatre;

  String get displayName {
    switch (this) {
      case Interest.entrepreneurship:
        return 'Entrepreneurship';
      case Interest.formula1:
        return 'Formula 1';
      case Interest.languages:
        return 'Languages';
      case Interest.ai:
        return 'AI';
      case Interest.animals:
        return 'Animals';
      case Interest.architecture:
        return 'Architecture';
      case Interest.art:
        return 'Art';
      case Interest.biology:
        return 'Biology';
      case Interest.cars:
        return 'Cars';
      case Interest.cats:
        return 'Cats';
      case Interest.cinema:
        return 'Cinema';
      case Interest.dogs:
        return 'Dogs';
      case Interest.finance:
        return 'Finance';
      case Interest.history:
        return 'History';
      case Interest.horses:
        return 'Horses';
      case Interest.nature:
        return 'Nature';
      case Interest.personalDevelopment:
        return 'Personal Development';
      case Interest.philosophy:
        return 'Philosophy';
      case Interest.plants:
        return 'Plants';
      case Interest.politics:
        return 'Politics';
      case Interest.programming:
        return 'Programming';
      case Interest.psychology:
        return 'Psychology';
      case Interest.science:
        return 'Science';
      case Interest.sneakers:
        return 'Sneakers';
      case Interest.sustainability:
        return 'Sustainability';
      case Interest.tattoos:
        return 'Tattoos';
      case Interest.tech:
        return 'Tech';
      case Interest.theatre:
        return 'Theatre';
    }
  }

  String toBackend() => name.toUpperCase();

  static Interest fromBackend(String value) {
    return Interest.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => throw ArgumentError('Invalid Interest value: $value'),
    );
  }
}
