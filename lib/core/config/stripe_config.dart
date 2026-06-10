/// Stripe configuration for different environments
class StripeConfig {
  /// Get the appropriate Stripe publishable key based on environment
  static String get publishableKey {
    const env = String.fromEnvironment('ENV', defaultValue: 'local');

    switch (env) {
      case 'production':
        // TODO: Replace with production key when ready
        return 'pk_test_51T9EaKFLd1WxoaURw3vL1lbq32KcFGcErm1lkvRV2yHQPFhNggyO5wHQR1cyA7o1a7kS4TJNc4DTMjHzvNMFzcgK00BT066K9r';
      case 'beta':
        // TODO: Replace with beta key when ready
        return 'pk_test_51T9EaKFLd1WxoaURw3vL1lbq32KcFGcErm1lkvRV2yHQPFhNggyO5wHQR1cyA7o1a7kS4TJNc4DTMjHzvNMFzcgK00BT066K9r';
      case 'develop':
      case 'local':
      default:
        return 'pk_test_51T9EaKFLd1WxoaURw3vL1lbq32KcFGcErm1lkvRV2yHQPFhNggyO5wHQR1cyA7o1a7kS4TJNc4DTMjHzvNMFzcgK00BT066K9r';
    }
  }

  /// Merchant display name (shown in Apple Pay / Google Pay)
  static const String merchantDisplayName = 'Muse';

  /// Whether to enable Google Pay
  static const bool enableGooglePay = true;

  /// Whether to enable Apple Pay
  static const bool enableApplePay = true;

  /// Merchant country code (ISO 3166-1 alpha-2)
  static const String merchantCountryCode = 'GB';

  /// Currency code
  static const String currencyCode = 'GBP';
}
