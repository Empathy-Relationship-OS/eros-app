import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/wallet/domain/models/wallet_models.dart';
import 'package:eros_app/features/wallet/presentation/providers/purchase_provider.dart';
import 'package:eros_app/features/wallet/presentation/screens/purchase_tokens_screen.dart';
import 'package:eros_app/features/wallet/presentation/screens/payment_screen.dart';
import 'package:eros_app/features/wallet/data/repositories/wallet_repository.dart';
import 'package:eros_app/features/wallet/services/stripe_service.dart';
import 'package:eros_app/features/wallet/services/idempotency_manager.dart';

void main() {
  group('PurchaseTokensScreen - _handleContinue navigation tests', () {
    testWidgets(
      'should navigate to PaymentScreen when initialization succeeds',
      (WidgetTester tester) async {
        // Create a mock notifier that simulates successful initialization
        final mockNotifier = _MockPurchaseNotifier(
          initialState: const PurchaseState(
            selectedPackage: TokenPackageType.starter,
            acceptedTerms: true,
          ),
          onInitialize: (notifier) {
            // Simulate successful initialization
            notifier.state = notifier.state.copyWith(
              idempotencyKey: 'test-key-123',
              step: PurchaseFlowStep.enterPayment,
            );
          },
        );

        // Build widget with provider override
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              purchaseProvider.overrideWith((ref) => mockNotifier),
            ],
            child: const MaterialApp(
              home: PurchaseTokensScreen(),
            ),
          ),
        );

        // Wait for initial build
        await tester.pumpAndSettle();

        // Find and verify the continue button
        final continueButton = find.byType(ElevatedButton);
        expect(continueButton, findsOneWidget);
        expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNotNull);

        // Tap the continue button
        await tester.tap(continueButton);
        await tester.pumpAndSettle();

        // Verify navigation to PaymentScreen occurred
        expect(find.byType(PaymentScreen), findsOneWidget);
        expect(find.byType(PurchaseTokensScreen), findsNothing);
      },
    );

    testWidgets(
      'should show error SnackBar and block navigation when initialization fails',
      (WidgetTester tester) async {
        // Create a mock notifier that simulates failed initialization
        final mockNotifier = _MockPurchaseNotifier(
          initialState: const PurchaseState(
            selectedPackage: TokenPackageType.starter,
            acceptedTerms: true,
          ),
          onInitialize: (notifier) {
            // Simulate failed initialization
            notifier.state = notifier.state.copyWith(
              errorMessage: 'Failed to initialize payment',
            );
          },
        );

        // Build widget with provider override
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              purchaseProvider.overrideWith((ref) => mockNotifier),
            ],
            child: const MaterialApp(
              home: PurchaseTokensScreen(),
            ),
          ),
        );

        // Wait for initial build
        await tester.pumpAndSettle();

        // Tap the continue button
        final continueButton = find.byType(ElevatedButton);
        await tester.tap(continueButton);
        await tester.pumpAndSettle();

        // Verify error SnackBar is shown
        expect(find.text('Failed to initialize payment'), findsOneWidget);
        expect(find.byType(SnackBar), findsOneWidget);

        // Verify navigation did NOT occur - should still be on PurchaseTokensScreen
        expect(find.byType(PaymentScreen), findsNothing);
        expect(find.byType(PurchaseTokensScreen), findsOneWidget);
      },
    );

    testWidgets(
      'should block navigation when idempotencyKey is null (even without error message)',
      (WidgetTester tester) async {
        // Create a mock notifier that returns null idempotency key
        final mockNotifier = _MockPurchaseNotifier(
          initialState: const PurchaseState(
            selectedPackage: TokenPackageType.starter,
            acceptedTerms: true,
          ),
          onInitialize: (notifier) {
            // Simulate initialization that doesn't set idempotency key
            // (edge case where error wasn't set but key also wasn't generated)
            notifier.state = notifier.state.copyWith(
              step: PurchaseFlowStep.enterPayment,
            );
          },
        );

        // Build widget with provider override
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              purchaseProvider.overrideWith((ref) => mockNotifier),
            ],
            child: const MaterialApp(
              home: PurchaseTokensScreen(),
            ),
          ),
        );

        // Wait for initial build
        await tester.pumpAndSettle();

        // Tap the continue button
        final continueButton = find.byType(ElevatedButton);
        await tester.tap(continueButton);
        await tester.pumpAndSettle();

        // Verify navigation did NOT occur
        expect(find.byType(PaymentScreen), findsNothing);
        expect(find.byType(PurchaseTokensScreen), findsOneWidget);
      },
    );

    testWidgets(
      'should disable continue button when package not selected',
      (WidgetTester tester) async {
        // Create a mock notifier with no package selected
        final mockNotifier = _MockPurchaseNotifier(
          initialState: const PurchaseState(
            selectedPackage: null,
            acceptedTerms: true,
          ),
        );

        // Build widget with provider override
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              purchaseProvider.overrideWith((ref) => mockNotifier),
            ],
            child: const MaterialApp(
              home: PurchaseTokensScreen(),
            ),
          ),
        );

        // Wait for initial build
        await tester.pumpAndSettle();

        // Verify button is disabled
        final continueButton = find.byType(ElevatedButton);
        expect(continueButton, findsOneWidget);
        expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNull);
      },
    );

    testWidgets(
      'should disable continue button when terms not accepted',
      (WidgetTester tester) async {
        // Create a mock notifier with terms not accepted
        final mockNotifier = _MockPurchaseNotifier(
          initialState: const PurchaseState(
            selectedPackage: TokenPackageType.starter,
            acceptedTerms: false,
          ),
        );

        // Build widget with provider override
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              purchaseProvider.overrideWith((ref) => mockNotifier),
            ],
            child: const MaterialApp(
              home: PurchaseTokensScreen(),
            ),
          ),
        );

        // Wait for initial build
        await tester.pumpAndSettle();

        // Verify button is disabled
        final continueButton = find.byType(ElevatedButton);
        expect(continueButton, findsOneWidget);
        expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNull);
      },
    );
  });
}

/// Mock PurchaseNotifier for testing
///
/// This extends PurchaseNotifier and overrides initializePurchase to simulate
/// success/failure scenarios without calling real services.
class _MockPurchaseNotifier extends PurchaseNotifier {
  final void Function(_MockPurchaseNotifier)? onInitialize;

  _MockPurchaseNotifier({
    required PurchaseState initialState,
    this.onInitialize,
  }) : super(
          _MockWalletRepository(),
          _MockStripeService(),
          _MockIdempotencyManager(),
          _MockRef(),
        ) {
    state = initialState;
  }

  @override
  Future<void> initializePurchase() async {
    // Call the test-provided initialization behavior instead of real logic
    onInitialize?.call(this);
  }
}

/// Minimal mock implementations for testing
class _MockWalletRepository implements WalletRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'Mock method ${invocation.memberName} not implemented - should not be called in navigation tests',
      );
}

class _MockStripeService implements StripeService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'Mock method ${invocation.memberName} not implemented - should not be called in navigation tests',
      );
}

class _MockIdempotencyManager implements IdempotencyManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'Mock method ${invocation.memberName} not implemented - should not be called in navigation tests',
      );
}

class _MockRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'Mock method ${invocation.memberName} not implemented - should not be called in navigation tests',
      );
}
