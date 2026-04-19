/// Public profile models matching backend DTOs
/// Used for previewing own profile and viewing other users' profiles
library;

/// Top-level public profile response
class PublicProfileDTO {
  final String userId;
  final String name;
  final int age;
  final int height;
  final String city;
  final String language;
  final String education;
  final String? occupation;
  final Set<String>? badges;
  final PublicProfileDetailsDTO profile;

  PublicProfileDTO({
    required this.userId,
    required this.name,
    required this.age,
    required this.height,
    required this.city,
    required this.language,
    required this.education,
    this.occupation,
    this.badges,
    required this.profile,
  });

  factory PublicProfileDTO.fromJson(Map<String, dynamic> json) {
    return PublicProfileDTO(
      userId: json['userId'] as String,
      name: json['name'] as String,
      age: json['age'] as int,
      height: json['height'] as int,
      city: json['city'] as String,
      language: json['language'] as String,
      education: json['education'] as String,
      occupation: json['occupation'] as String?,
      badges: json['badges'] != null
          ? Set<String>.from(json['badges'] as List)
          : null,
      profile: PublicProfileDetailsDTO.fromJson(
        json['profile'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'age': age,
      'height': height,
      'city': city,
      'language': language,
      'education': education,
      if (occupation != null) 'occupation': occupation,
      if (badges != null) 'badges': badges!.toList(),
      'profile': profile.toJson(),
    };
  }
}

/// Detailed public profile information
class PublicProfileDetailsDTO {
  final String? coverPhoto;
  final List<String> photos;
  final String? bio;
  final List<String> hobbies;
  final List<String> traits;
  final HabitsResponse habits;
  final RelationshipResponse relationshipGoals;
  final List<String> sharedInterests;
  final List<String>? spokenLanguages;
  final String? religion;
  final String? politicalView;
  final String? sexualOrientation;
  final String? pronouns;
  final String? starSign;
  final List<String>? ethnicity;
  final List<String>? brainAttribute;
  final String? brainDescription;
  final List<String>? bodyAttribute;
  final String? bodyDescription;
  final List<PublicQAItemDTO> qas;

  PublicProfileDetailsDTO({
    this.coverPhoto,
    required this.photos,
    this.bio,
    required this.hobbies,
    required this.traits,
    required this.habits,
    required this.relationshipGoals,
    required this.sharedInterests,
    this.spokenLanguages,
    this.religion,
    this.politicalView,
    this.sexualOrientation,
    this.pronouns,
    this.starSign,
    this.ethnicity,
    this.brainAttribute,
    this.brainDescription,
    this.bodyAttribute,
    this.bodyDescription,
    required this.qas,
  });

  factory PublicProfileDetailsDTO.fromJson(Map<String, dynamic> json) {
    return PublicProfileDetailsDTO(
      coverPhoto: json['coverPhoto'] as String?,
      photos: List<String>.from(json['photos'] as List),
      bio: json['bio'] as String?,
      hobbies: List<String>.from(json['hobbies'] as List),
      traits: List<String>.from(json['traits'] as List),
      habits: HabitsResponse.fromJson(json['habits'] as Map<String, dynamic>),
      relationshipGoals: RelationshipResponse.fromJson(
        json['relationshipGoals'] as Map<String, dynamic>,
      ),
      sharedInterests: List<String>.from(json['sharedInterests'] as List),
      spokenLanguages: json['spokenLanguages'] != null
          ? List<String>.from(json['spokenLanguages'] as List)
          : null,
      religion: json['religion'] as String?,
      politicalView: json['politicalView'] as String?,
      sexualOrientation: json['sexualOrientation'] as String?,
      pronouns: json['pronouns'] as String?,
      starSign: json['starSign'] as String?,
      ethnicity: json['ethnicity'] != null
          ? List<String>.from(json['ethnicity'] as List)
          : null,
      brainAttribute: json['brainAttribute'] != null
          ? List<String>.from(json['brainAttribute'] as List)
          : null,
      brainDescription: json['brainDescription'] as String?,
      bodyAttribute: json['bodyAttribute'] != null
          ? List<String>.from(json['bodyAttribute'] as List)
          : null,
      bodyDescription: json['bodyDescription'] as String?,
      qas: (json['qas'] as List)
          .map((qa) => PublicQAItemDTO.fromJson(qa as Map<String, dynamic>))
          .toList()
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (coverPhoto != null) 'coverPhoto': coverPhoto,
      'photos': photos,
      if (bio != null) 'bio': bio,
      'hobbies': hobbies,
      'traits': traits,
      'habits': habits.toJson(),
      'relationshipGoals': relationshipGoals.toJson(),
      'sharedInterests': sharedInterests,
      if (spokenLanguages != null) 'spokenLanguages': spokenLanguages,
      if (religion != null) 'religion': religion,
      if (politicalView != null) 'politicalView': politicalView,
      if (sexualOrientation != null) 'sexualOrientation': sexualOrientation,
      if (pronouns != null) 'pronouns': pronouns,
      if (starSign != null) 'starSign': starSign,
      if (ethnicity != null) 'ethnicity': ethnicity,
      if (brainAttribute != null) 'brainAttribute': brainAttribute,
      if (brainDescription != null) 'brainDescription': brainDescription,
      if (bodyAttribute != null) 'bodyAttribute': bodyAttribute,
      if (bodyDescription != null) 'bodyDescription': bodyDescription,
      'qas': qas.map((qa) => qa.toJson()).toList(),
    };
  }
}

/// Habits information
class HabitsResponse {
  final String? alcoholConsumption;
  final String? smokingStatus;
  final String? diet;

  HabitsResponse({
    this.alcoholConsumption,
    this.smokingStatus,
    this.diet,
  });

  factory HabitsResponse.fromJson(Map<String, dynamic> json) {
    return HabitsResponse(
      alcoholConsumption: json['alcoholConsumption'] as String?,
      smokingStatus: json['smokingStatus'] as String?,
      diet: json['diet'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (alcoholConsumption != null) 'alcoholConsumption': alcoholConsumption,
      if (smokingStatus != null) 'smokingStatus': smokingStatus,
      if (diet != null) 'diet': diet,
    };
  }
}

/// Relationship goals information
class RelationshipResponse {
  final String? intention;
  final String? kidsPreference;
  final String? relationshipType;

  RelationshipResponse({
    this.intention,
    this.kidsPreference,
    this.relationshipType,
  });

  factory RelationshipResponse.fromJson(Map<String, dynamic> json) {
    return RelationshipResponse(
      intention: json['intention'] as String?,
      kidsPreference: json['kidsPreference'] as String?,
      relationshipType: json['relationshipType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (intention != null) 'intention': intention,
      if (kidsPreference != null) 'kidsPreference': kidsPreference,
      if (relationshipType != null) 'relationshipType': relationshipType,
    };
  }
}

/// Lightweight Q&A DTO for public profiles
/// Excludes sensitive fields like userId and timestamps that aren't needed
/// when viewing another user's profile
class PublicQAItemDTO {
  final String question;
  final String answer;
  final int displayOrder;

  PublicQAItemDTO({
    required this.question,
    required this.answer,
    required this.displayOrder,
  });

  factory PublicQAItemDTO.fromJson(Map<String, dynamic> json) {
    return PublicQAItemDTO(
      question: json['question'] as String,
      answer: json['answer'] as String,
      displayOrder: json['displayOrder'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'answer': answer,
      'displayOrder': displayOrder,
    };
  }
}
