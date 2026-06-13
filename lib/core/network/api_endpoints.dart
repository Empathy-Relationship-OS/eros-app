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
  static final marketing = _MarketingEndpoints();
  static final wallet = _WalletEndpoints();
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

// ====================
// MARKETING ENDPOINTS
// ====================
class _MarketingEndpoints {
  /// POST /marketing/preference - Create marketing preference
  String createPreference() => '/marketing/preference';

  /// PUT /marketing/preference - Update marketing preference
  String updatePreference() => '/marketing/preference';

  /// GET /marketing/preference - Get marketing preference
  String getPreference() => '/marketing/preference';
}

// ====================
// WALLET ENDPOINTS
// ====================
class _WalletEndpoints {
  /// GET /wallet/balance - Get wallet balance
  String getBalance() => '/wallet/balance';

  /// GET /wallet/transactions - Get transaction history (paginated)
  ///
  /// Supports filtering by type and multiple statuses:
  /// - type: PURCHASE, SPEND, REFUND, ADJUSTMENT
  /// - statuses: PENDING, COMPLETED, FAILED, CANCELLED, REFUNDED, REFUND_FAILED
  String getTransactions({
    required int limit,
    required int offset,
    String? type,
    List<String>? statuses,
  }) {
    final queryParts = <String>[];
    queryParts.add('limit=${Uri.encodeQueryComponent(limit.toString())}');
    queryParts.add('offset=${Uri.encodeQueryComponent(offset.toString())}');

    if (type != null) {
      queryParts.add('type=${Uri.encodeQueryComponent(type)}');
    }

    // Add multiple status parameters
    if (statuses != null && statuses.isNotEmpty) {
      for (final status in statuses) {
        queryParts.add('status=${Uri.encodeQueryComponent(status)}');
      }
    }

    return '/wallet/transactions?${queryParts.join('&')}';
  }

  /// POST /wallet/purchase - Purchase tokens
  String purchase() => '/wallet/purchase';

  /// POST /wallet/spend - Spend tokens on a date
  String spend() => '/wallet/spend';

  /// POST /wallet/refund - Request refund
  String refund() => '/wallet/refund';
}
