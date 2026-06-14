/// Stripe configuration for different environments
class StripeConfig {
  /// Get the appropriate Stripe publishable key based on environment
  static String get publishableKey {
    const env = String.fromEnvironment('ENV', defaultValue: 'local');

    switch (env) {
      case 'production':
        const key = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY_PROD');
        if (key.isEmpty) {
          throw AssertionError(
            'STRIPE_PUBLISHABLE_KEY_PROD must be provided for production builds. '
            'Run: flutter run --dart-define=ENV=production --dart-define=STRIPE_PUBLISHABLE_KEY_PROD=pk_live_...',
          );
        }
        return key;
      case 'beta':
        const key = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY_BETA');
        if (key.isEmpty) {
          throw AssertionError(
            'STRIPE_PUBLISHABLE_KEY_BETA must be provided for beta builds. '
            'Run: flutter run --dart-define=ENV=beta --dart-define=STRIPE_PUBLISHABLE_KEY_BETA=pk_test_...',
          );
        }
        return key;
      case 'develop':
      case 'local':
      default:
        // Test key for development only
        return 'pk_test_51T9EaKFLd1WxoaURw3vL1lbq32KcFGcErm1lkvRV2yHQPFhNggyO5wHQR1cyA7o1a7kS4TJNc4DTMjHzvNMFzcgK00BT066K9r';
    }
  }

  /// Apple Pay Merchant Identifier (iOS only - registered in Apple Developer account)
  ///
  /// This is the technical identifier for Apple Pay, NOT the display name.
  /// Only used on iOS devices for Apple Pay. Set via Stripe.merchantIdentifier on app init.
  ///
  /// Format: merchant.com.yourcompany.appname
  /// Register at: https://developer.apple.com/account/resources/identifiers/list/merchant
  static String get applePayMerchantId {
    const env = String.fromEnvironment('ENV', defaultValue: 'local');

    switch (env) {
      case 'production':
        const id = String.fromEnvironment('APPLE_PAY_MERCHANT_ID_PROD');
        if (id.isEmpty) {
          throw AssertionError(
            'APPLE_PAY_MERCHANT_ID_PROD must be provided for production builds. '
            'Run: flutter run --dart-define=ENV=production --dart-define=APPLE_PAY_MERCHANT_ID_PROD=merchant.com.muse.app',
          );
        }
        return id;
      case 'beta':
        const id = String.fromEnvironment('APPLE_PAY_MERCHANT_ID_BETA');
        if (id.isEmpty) {
          throw AssertionError(
            'APPLE_PAY_MERCHANT_ID_BETA must be provided for beta builds. '
            'Run: flutter run --dart-define=ENV=beta --dart-define=APPLE_PAY_MERCHANT_ID_BETA=merchant.com.muse.beta',
          );
        }
        return id;
      case 'develop':
      case 'local':
      default:
        // Test merchant ID for development
        // TODO: Replace with actual merchant ID registered in Apple Developer account
        return 'merchant.com.muse.dev';
    }
  }

  /// Google Pay Merchant ID (Android only - registered in Google Pay Business Console)
  ///
  /// This is the technical identifier for Google Pay, NOT the display name.
  /// Only used on Android devices for Google Pay. Set via GooglePayConfiguration when
  /// presenting payment sheet (not during app initialization like Apple Pay).
  ///
  /// Format: BCR2DN4TR6JK3456 (12-character alphanumeric ID)
  /// Register at: https://pay.google.com/business/console
  static String get googlePayMerchantId {
    const env = String.fromEnvironment('ENV', defaultValue: 'local');

    switch (env) {
      case 'production':
        const id = String.fromEnvironment('GOOGLE_PAY_MERCHANT_ID_PROD');
        if (id.isEmpty) {
          throw AssertionError(
            'GOOGLE_PAY_MERCHANT_ID_PROD must be provided for production builds. '
            'Run: flutter run --dart-define=ENV=production --dart-define=GOOGLE_PAY_MERCHANT_ID_PROD=BCR2DN4TR6JK3456',
          );
        }
        return id;
      case 'beta':
        const id = String.fromEnvironment('GOOGLE_PAY_MERCHANT_ID_BETA');
        if (id.isEmpty) {
          throw AssertionError(
            'GOOGLE_PAY_MERCHANT_ID_BETA must be provided for beta builds. '
            'Run: flutter run --dart-define=ENV=beta --dart-define=GOOGLE_PAY_MERCHANT_ID_BETA=BCR2DN4TR6JK3456',
          );
        }
        return id;
      case 'develop':
      case 'local':
      default:
        // Test merchant ID for development
        // TODO: Replace with actual merchant ID registered in Google Pay Business Console
        return 'BCR2DN4XXXXXXXXX';
    }
  }

  /// Merchant display name (shown to users in Apple Pay / Google Pay)
  ///
  /// This is the user-facing name, separate from the technical merchant identifiers.
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
