import 'dart:io' show Platform;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/config/stripe_config.dart';

/// Service for initializing and managing Stripe SDK
class StripeService {
  final Logger _logger = Logger();

  /// Initialize Stripe SDK
  ///
  /// Must be called before using any Stripe functionality.
  /// Typically called in main() before runApp().
  Future<void> initialize() async {
    try {
      _logger.d('🔧 Initializing Stripe SDK');

      // Set publishable key
      Stripe.publishableKey = StripeConfig.publishableKey;

      // Set Apple Pay merchant identifier (iOS only)
      // Note: Stripe.merchantIdentifier is for Apple Pay's merchant ID only.
      // Google Pay (Android) uses a separate Google Merchant ID configured via GooglePayConfiguration.
      if (Platform.isIOS) {
        Stripe.merchantIdentifier = StripeConfig.applePayMerchantId;
        _logger.d('🍎 Apple Pay merchant identifier set');
      }

      _logger.d('✅ Stripe SDK initialized successfully');
    } catch (e, stackTrace) {
      _logger.e('🚨 Failed to initialize Stripe SDK', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Create a payment method from card details
  ///
  /// Returns the payment method ID which can be sent to the backend.
  Future<String> createPaymentMethod() async {
    try {
      _logger.d('💳 Creating payment method');

      final paymentMethod = await Stripe.instance.createPaymentMethod(
        params: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );

      _logger.d('✅ Payment method created: ${paymentMethod.id}');
      return paymentMethod.id;
    } on StripeException catch (e) {
      _logger.e('🚨 Stripe error creating payment method: ${e.error.message}');
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('🚨 Unexpected error creating payment method', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Confirm a payment intent with client secret
  ///
  /// This completes the payment flow after the backend creates the PaymentIntent.
  /// The backend has already created the PaymentIntent with the payment method attached.
  /// We retrieve the payment intent status and handle any required actions (3D Secure, etc).
  ///
  /// Parameters:
  /// - [clientSecret]: The client secret returned from backend (format: pi_xxxxx_secret_yyyy)
  ///
  /// Returns the payment intent status.
  Future<PaymentIntentsStatus> confirmPayment(String clientSecret) async {
    try {
      _logger.d('🔐 Retrieving and handling payment intent');

      // Validate client secret format
      if (!_isValidClientSecret(clientSecret)) {
        _logger.e('🚨 Invalid client secret format: $clientSecret');
        throw StripeException(
          error: LocalizedErrorMessage(
            code: FailureCode.Failed,
            localizedMessage: 'Invalid payment configuration',
            message: 'Backend returned invalid client secret. Expected format: pi_xxxxx_secret_yyyy, got: $clientSecret',
          ),
        );
      }

      // First, retrieve the payment intent to check its status
      final paymentIntent = await Stripe.instance.retrievePaymentIntent(
        clientSecret,
      );

      _logger.d('📋 Payment intent status: ${paymentIntent.status}');

      // Handle different states
      switch (paymentIntent.status) {
        case PaymentIntentsStatus.RequiresConfirmation:
          // Payment needs to be confirmed on the client
          _logger.d('🔐 Confirming payment intent on client');
          final confirmedIntent = await Stripe.instance.confirmPayment(
            paymentIntentClientSecret: clientSecret,
            data: const PaymentMethodParams.card(
              paymentMethodData: PaymentMethodData(),
            ),
          );
          _logger.d('✅ Payment confirmed: ${confirmedIntent.status}');
          return confirmedIntent.status;

        case PaymentIntentsStatus.RequiresAction:
          // Handle 3D Secure or other authentication
          _logger.d('🔒 Authentication required, handling next action');
          final confirmedIntent = await Stripe.instance.handleNextAction(
            clientSecret,
          );
          _logger.d('✅ Payment authenticated: ${confirmedIntent.status}');
          return confirmedIntent.status;

        case PaymentIntentsStatus.Succeeded:
          // Payment already succeeded (no action needed)
          _logger.d('✅ Payment already succeeded');
          return PaymentIntentsStatus.Succeeded;

        case PaymentIntentsStatus.RequiresPaymentMethod:
          // Payment method not properly attached
          _logger.e('🚨 Payment intent requires payment method');
          throw StripeException(
            error: LocalizedErrorMessage(
              code: FailureCode.Failed,
              localizedMessage: 'Payment method not attached',
              message: 'Payment method was not properly attached to payment intent',
            ),
          );

        case PaymentIntentsStatus.Processing:
          // Payment is being processed (wait for webhook confirmation)
          _logger.d('⏳ Payment is processing');
          return PaymentIntentsStatus.Processing;

        default:
          // Other states (RequiresCapture, Canceled, Unknown)
          _logger.w('⚠️  Unexpected payment intent state: ${paymentIntent.status}');
          return paymentIntent.status;
      }
    } on StripeException catch (e) {
      _logger.e('🚨 Stripe error handling payment: ${e.error.message}');
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('🚨 Unexpected error handling payment', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get user-friendly error message from Stripe exception
  String getErrorMessage(StripeException exception) {
    final error = exception.error;

    switch (error.code) {
      case FailureCode.Canceled:
        return 'Payment was cancelled';
      case FailureCode.Failed:
        return 'Payment failed. Please try again';
      case FailureCode.Timeout:
        return 'Payment timed out. Please try again';
      default:
        return error.message ?? 'An error occurred during payment';
    }
  }

  /// Validate that the client secret has the correct format
  ///
  /// Stripe client secrets should be in format: pi_xxxxx_secret_yyyy
  /// This prevents crashes from invalid client secrets.
  bool _isValidClientSecret(String clientSecret) {
    // Client secret should contain '_secret_'
    // Format: pi_xxxxx_secret_yyyy or setup intent format
    return clientSecret.contains('_secret_') &&
        (clientSecret.startsWith('pi_') || clientSecret.startsWith('seti_'));
  }
}
