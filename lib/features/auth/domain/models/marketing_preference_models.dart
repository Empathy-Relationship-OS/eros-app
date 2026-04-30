/// Request DTO for creating a marketing consent record.
///
/// Used when a user sets their marketing preference for the first time.
class CreateMarketingConsentRequest {
  /// Whether the user consents to receive marketing communications
  final bool marketingConsent;

  const CreateMarketingConsentRequest({
    required this.marketingConsent,
  });

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() => {
        'marketingConsent': marketingConsent,
      };

  /// Create from JSON
  factory CreateMarketingConsentRequest.fromJson(Map<String, dynamic> json) {
    return CreateMarketingConsentRequest(
      marketingConsent: json['marketingConsent'] as bool,
    );
  }
}

/// Response DTO for marketing preference endpoints.
///
/// Returned when retrieving or modifying a user's marketing consent record.
class MarketingPreferenceResponse {
  /// The user's unique identifier
  final String userId;

  /// Whether the user has consented to receive marketing communications
  final bool marketingConsent;

  /// When the consent record was created
  final DateTime createdAt;

  /// When the consent record was last updated
  final DateTime updatedAt;

  const MarketingPreferenceResponse({
    required this.userId,
    required this.marketingConsent,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'userId': userId,
        'marketingConsent': marketingConsent,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Create from JSON response
  factory MarketingPreferenceResponse.fromJson(Map<String, dynamic> json) {
    return MarketingPreferenceResponse(
      userId: json['userId'] as String,
      marketingConsent: json['marketingConsent'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
