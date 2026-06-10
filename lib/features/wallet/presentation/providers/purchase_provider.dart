import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/wallet/data/repositories/wallet_repository.dart';
import 'package:eros_app/features/wallet/domain/models/wallet_models.dart';
import 'package:eros_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:eros_app/features/wallet/services/stripe_service.dart';
import 'package:eros_app/features/wallet/services/idempotency_manager.dart';

// ====================
// SERVICE PROVIDERS
// ====================

/// Provider for StripeService
final stripeServiceProvider = Provider<StripeService>((ref) {
  return StripeService();
});

/// Provider for IdempotencyManager
final idempotencyManagerProvider = Provider<IdempotencyManager>((ref) {
  return IdempotencyManager();
});

// ====================
// STATE MODELS
// ====================

/// Purchase flow state
enum PurchaseFlowStep {
  selectPackage,
  enterPayment,
  processing,
  completed,
  failed,
}

/// State for token purchase flow
class PurchaseState {
  final PurchaseFlowStep step;
  final TokenPackageType? selectedPackage;
  final bool acceptedTerms;
  final bool isProcessing;
  final String? errorMessage;
  final PurchaseResponse? purchaseResponse;
  final String? idempotencyKey;

  const PurchaseState({
    this.step = PurchaseFlowStep.selectPackage,
    this.selectedPackage,
    this.acceptedTerms = false,
    this.isProcessing = false,
    this.errorMessage,
    this.purchaseResponse,
    this.idempotencyKey,
  });

  bool get hasError => errorMessage != null;
  bool get canProceed => selectedPackage != null && acceptedTerms;

  PurchaseState copyWith({
    PurchaseFlowStep? step,
    TokenPackageType? selectedPackage,
    bool? acceptedTerms,
    bool? isProcessing,
    String? errorMessage,
    PurchaseResponse? purchaseResponse,
    String? idempotencyKey,
    bool clearError = false,
    bool clearPackage = false,
  }) {
    return PurchaseState(
      step: step ?? this.step,
      selectedPackage: clearPackage ? null : (selectedPackage ?? this.selectedPackage),
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      purchaseResponse: purchaseResponse ?? this.purchaseResponse,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }
}

// ====================
// STATE NOTIFIER
// ====================

/// Notifier for token purchase flow
class PurchaseNotifier extends StateNotifier<PurchaseState> {
  final WalletRepository _walletRepository;
  final StripeService _stripeService;
  final IdempotencyManager _idempotencyManager;
  final Ref _ref;
  final Logger _logger = Logger();

  PurchaseNotifier(
    this._walletRepository,
    this._stripeService,
    this._idempotencyManager,
    this._ref,
  ) : super(const PurchaseState());

  /// Select a token package
  void selectPackage(TokenPackageType package) {
    _logger.d('📦 Selected package: ${package.displayName}');
    state = state.copyWith(selectedPackage: package, clearError: true);
  }

  /// Toggle terms acceptance
  void setAcceptedTerms(bool accepted) {
    state = state.copyWith(acceptedTerms: accepted);
  }

  /// Initialize purchase flow
  Future<void> initializePurchase() async {
    try {
      // Get or create idempotency key
      final key = await _idempotencyManager.getCurrentPurchaseKey();
      state = state.copyWith(
        idempotencyKey: key,
        step: PurchaseFlowStep.enterPayment,
      );
    } catch (e) {
      _logger.e('Failed to initialize purchase', error: e);
      state = state.copyWith(
        errorMessage: 'Failed to initialize payment',
      );
    }
  }

  /// Execute the purchase flow
  ///
  /// This handles the complete payment flow:
  /// 1. Create payment method with Stripe
  /// 2. Call backend to create payment intent
  /// 3. Confirm payment with Stripe
  /// 4. Refresh wallet balance
  Future<void> executePurchase() async {
    if (!state.canProceed) {
      _logger.w('⚠️  Cannot proceed - package not selected or terms not accepted');
      return;
    }

    if (state.idempotencyKey == null) {
      _logger.e('🚨 No idempotency key - must call initializePurchase() first');
      state = state.copyWith(
        errorMessage: 'Payment session expired. Please try again.',
      );
      return;
    }

    state = state.copyWith(
      isProcessing: true,
      step: PurchaseFlowStep.processing,
      clearError: true,
    );

    try {
      // Step 1: Create payment method
      _logger.d('💳 Creating payment method...');
      final paymentMethodId = await _stripeService.createPaymentMethod();

      // Step 2: Call backend to create payment intent
      _logger.d('🌐 Creating payment intent on backend...');
      final purchase = await _walletRepository.purchaseTokens(
        packageType: state.selectedPackage!,
        paymentMethodId: paymentMethodId,
        idempotencyKey: state.idempotencyKey!,
        acceptedTerms: state.acceptedTerms,
      );

      state = state.copyWith(purchaseResponse: purchase);

      // Step 3: Confirm payment with Stripe
      _logger.d('🔐 Confirming payment with Stripe...');
      final paymentStatus = await _stripeService.confirmPayment(
        purchase.clientSecret,
      );

      // Step 4: Handle result
      if (paymentStatus == PaymentIntentsStatus.Succeeded ||
          paymentStatus == PaymentIntentsStatus.Processing) {
        _logger.d('✅ Payment ${paymentStatus == PaymentIntentsStatus.Succeeded ? 'succeeded' : 'processing'}!');

        // Clear idempotency key
        await _idempotencyManager.clearCurrentPurchaseKey();

        // Refresh balance
        await _ref.read(walletBalanceProvider.notifier).refresh();

        // Refresh transaction history
        await _ref.read(transactionHistoryProvider.notifier).refresh();

        state = state.copyWith(
          isProcessing: false,
          step: PurchaseFlowStep.completed,
        );
      } else {
        _logger.w('⚠️  Payment not succeeded: $paymentStatus');
        state = state.copyWith(
          isProcessing: false,
          step: PurchaseFlowStep.failed,
          errorMessage: 'Payment was not completed. Please try again.',
        );
      }
    } on StripeException catch (e) {
      _logger.e('🚨 Stripe error: ${e.error.message}');
      state = state.copyWith(
        isProcessing: false,
        step: PurchaseFlowStep.failed,
        errorMessage: _stripeService.getErrorMessage(e),
      );
    } on ValidationException catch (e) {
      _logger.e('🚨 Validation error: ${e.message}');
      state = state.copyWith(
        isProcessing: false,
        step: PurchaseFlowStep.failed,
        errorMessage: e.message,
      );
    } on NetworkException catch (e) {
      _logger.e('🚨 Network error: ${e.message}');
      state = state.copyWith(
        isProcessing: false,
        step: PurchaseFlowStep.failed,
        errorMessage: 'Connection error. Please check your internet and try again.',
      );
    } on ApiException catch (e) {
      _logger.e('🚨 API error: ${e.message}');
      state = state.copyWith(
        isProcessing: false,
        step: PurchaseFlowStep.failed,
        errorMessage: e.message,
      );
    } catch (e, stackTrace) {
      _logger.e('🚨 Unexpected error during purchase', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isProcessing: false,
        step: PurchaseFlowStep.failed,
        errorMessage: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Retry a failed purchase
  ///
  /// Reuses the same idempotency key to prevent duplicate charges.
  Future<void> retry() async {
    if (state.idempotencyKey == null) {
      // If no key exists, need to restart the flow
      await initializePurchase();
    } else {
      // Reuse existing key
      state = state.copyWith(
        step: PurchaseFlowStep.enterPayment,
        clearError: true,
      );
    }
  }

  /// Reset the purchase flow
  ///
  /// Call this when user cancels or wants to start over.
  Future<void> reset() async {
    // Clear idempotency key
    await _idempotencyManager.clearCurrentPurchaseKey();

    state = const PurchaseState();
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ====================
// PROVIDER INSTANCES
// ====================

/// Provider for purchase flow state
final purchaseProvider =
    StateNotifierProvider.autoDispose<PurchaseNotifier, PurchaseState>((ref) {
  final walletRepository = ref.watch(walletRepositoryProvider);
  final stripeService = ref.watch(stripeServiceProvider);
  final idempotencyManager = ref.watch(idempotencyManagerProvider);

  return PurchaseNotifier(
    walletRepository,
    stripeService,
    idempotencyManager,
    ref,
  );
});
