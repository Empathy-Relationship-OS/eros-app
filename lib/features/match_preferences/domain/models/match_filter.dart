/// One filter on the Match preferences screen, in RFC-007 §4.1's order: the order the hub lists
/// them in.
enum MatchFilter {
  gender,
  age,
  distance,
  height,
  ethnicity,
  religion,
  relationshipType,
  dateIntentions,
  kidsPreference,
  smokingStatus,
  alcoholConsumption;

  /// The row's title: the label the Edit profile screen uses for the field it reads (primer
  /// rule 16), except Interested in and Age range, which have no profile row.
  String get label => switch (this) {
        MatchFilter.gender => 'Interested in',
        MatchFilter.age => 'Age range',
        MatchFilter.distance => 'Distance',
        MatchFilter.height => 'Height',
        MatchFilter.ethnicity => 'Ethnicity',
        MatchFilter.religion => 'Religion',
        MatchFilter.relationshipType => 'Relationship type',
        MatchFilter.dateIntentions => 'Dating intentions',
        MatchFilter.kidsPreference => 'Kids',
        MatchFilter.smokingStatus => 'Smoking',
        MatchFilter.alcoholConsumption => 'Drinking',
      };
}
