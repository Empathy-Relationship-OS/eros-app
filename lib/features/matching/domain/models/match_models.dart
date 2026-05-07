/// Match-related data models matching backend DTOs
library;

/// Lightweight profile DTO returned when fetching daily match batches.
///
/// Contains minimal user information for initial display in the matching interface.
/// Client can fetch full profile details separately when user taps to view more.
class UserMatchProfile {
  final int matchId;
  final String userId;
  final String name;
  final int age;
  final String? thumbnailUrl;
  final Set<String>? badges;
  final DateTime servedAt;

  UserMatchProfile({
    required this.matchId,
    required this.userId,
    required this.name,
    required this.age,
    this.thumbnailUrl,
    this.badges,
    required this.servedAt,
  }) {
    if (matchId <= 0) {
      throw ArgumentError('matchId must be positive');
    }
    if (userId.trim().isEmpty) {
      throw ArgumentError('userId cannot be blank');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('name cannot be blank');
    }
    if (age <= 0) {
      throw ArgumentError('age must be positive');
    }
  }

  factory UserMatchProfile.fromJson(Map<String, dynamic> json) {
    return UserMatchProfile(
      matchId: json['matchId'] as int,
      userId: json['userId'] as String,
      name: json['name'] as String,
      age: json['age'] as int,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      badges: json['badges'] != null
          ? Set<String>.from(json['badges'] as List)
          : null,
      servedAt: DateTime.parse(json['servedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'userId': userId,
      'name': name,
      'age': age,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (badges != null) 'badges': badges!.toList(),
      'servedAt': servedAt.toIso8601String(),
    };
  }
}

/// Response DTO for daily batch fetch endpoint.
///
/// Wraps the list of profiles with metadata about batch progress and remaining batches.
class DailyBatchResponse {
  static const int maxDailyBatches = 3;
  static const int batchSize = 7;

  final List<UserMatchProfile> profiles;
  final int batchNumber;
  final int remainingBatches;

  DailyBatchResponse({
    required this.profiles,
    required this.batchNumber,
    required this.remainingBatches,
  }) {
    if (batchNumber < 1 || batchNumber > maxDailyBatches) {
      throw ArgumentError(
        'batchNumber must be between 1 and $maxDailyBatches, got: $batchNumber',
      );
    }
    if (remainingBatches < 0 || remainingBatches >= maxDailyBatches) {
      throw ArgumentError(
        'remainingBatches must be between 0 and ${maxDailyBatches - 1}, got: $remainingBatches',
      );
    }
    if (profiles.length > batchSize) {
      throw ArgumentError(
        'profiles must contain at most $batchSize items, got: ${profiles.length}',
      );
    }
  }

  factory DailyBatchResponse.fromJson(Map<String, dynamic> json) {
    return DailyBatchResponse(
      profiles: (json['profiles'] as List)
          .map((profile) =>
              UserMatchProfile.fromJson(profile as Map<String, dynamic>))
          .toList(),
      batchNumber: json['batchNumber'] as int,
      remainingBatches: json['remainingBatches'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
      'batchNumber': batchNumber,
      'remainingBatches': remainingBatches,
    };
  }
}

/// Error response DTO when daily batch limit is exceeded.
///
/// Returned with 429 Too Many Requests status when user has already fetched 3 batches today.
class DailyBatchLimitError {
  final String error;
  final int batchesUsed;
  final int maxBatches;
  final DateTime resetAt;

  DailyBatchLimitError({
    required this.error,
    required this.batchesUsed,
    required this.maxBatches,
    required this.resetAt,
  }) {
    if (batchesUsed < 0) {
      throw ArgumentError('batchesUsed must be non-negative, got: $batchesUsed');
    }
    if (maxBatches <= 0) {
      throw ArgumentError('maxBatches must be positive, got: $maxBatches');
    }
  }

  factory DailyBatchLimitError.fromJson(Map<String, dynamic> json) {
    return DailyBatchLimitError(
      error: json['error'] as String,
      batchesUsed: json['batchesUsed'] as int,
      maxBatches: json['maxBatches'] as int,
      resetAt: DateTime.parse(json['resetAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'error': error,
      'batchesUsed': batchesUsed,
      'maxBatches': maxBatches,
      'resetAt': resetAt.toIso8601String(),
    };
  }
}
