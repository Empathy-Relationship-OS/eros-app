/// Centralized API endpoint definitions
/// All endpoints are strongly-typed and provide compile-time safety
class ApiEndpoints {
  ApiEndpoints._(); // Private constructor - use static members only

  // Root health check
  static const String healthCheck = '/';

  // Feature-specific endpoint groups
  static final users = _UsersEndpoints();
  static final photos = _PhotosEndpoints();
  static final qa = _QAEndpoints();
  static final match = _MatchEndpoints();
  static final dates = _DatesEndpoints();
}

// ====================
// USERS ENDPOINTS
// ====================
class _UsersEndpoints {
  /// POST /users - Create new user
  String create() => '/users';

  /// GET /users/exists - Check if user exists
  String checkExists() => '/users/exists';

  /// GET /users/me - Get current user profile
  String getCurrentUser() => '/users/me';

  /// PATCH /users/me - Update current user profile
  String updateCurrentUser() => '/users/me';

  /// GET /users/id/{userId}/public - Get public profile by ID
  String getPublicProfile(String userId) => '/users/id/$userId/public';
}

// ====================
// PHOTOS ENDPOINTS
// ====================
class _PhotosEndpoints {
  /// POST /users/me/photos/presigned-url - Get S3 presigned upload URL
  String getPresignedUrl() => '/users/me/photos/presigned-url';

  /// POST /users/me/photos - Confirm photo upload to S3
  String confirmUpload() => '/users/me/photos';

  /// DELETE /users/me/photos/{photoId} - Delete photo
  String delete(String photoId) => '/users/me/photos/$photoId';

  /// PATCH /users/me/photos/reorder - Reorder photos
  String reorder() => '/users/me/photos/reorder';
}

// ====================
// Q&A ENDPOINTS
// ====================
class _QAEndpoints {
  /// GET /users/qa/me - Get user's Q&A collection
  String getCurrentUserQA() => '/users/qa/me';

  /// POST /users/qa/me/collection - Create/update Q&A collection
  String createOrUpdateCollection() => '/users/qa/me/collection';

  /// GET /users/qa/id/{userId} - Get public Q&A for user
  String getPublicQA(String userId) => '/users/qa/id/$userId';
}

// ====================
// MATCHING ENDPOINTS
// ====================
class _MatchEndpoints {
  /// GET /match/ - Fetch daily batch of matches
  String fetchBatch() => '/match/';

  /// PATCH /match/action/{matchId} - Like or pass on match
  String action(String matchId) => '/match/action/$matchId';

  /// GET /match/last-24 - Get last 24 hours of passes
  String getLast24Hours() => '/match/last-24';
}

// ====================
// DATES ENDPOINTS (Future)
// ====================
class _DatesEndpoints {
  /// Placeholder for future date scheduling endpoints
  /// Will be populated as date features are implemented
}
