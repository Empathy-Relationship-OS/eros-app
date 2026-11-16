import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/theme/app_theme.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/features/wallet/presentation/providers/purchase_provider.dart';

/// Screen for entering payment details and completing purchase
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _isCardComplete = false;

  @override
  Widget build(BuildContext context) {
    final purchaseState = ref.watch(purchaseProvider);

    // Listen for purchase completion or failure
    ref.listen<PurchaseState>(purchaseProvider, (previous, current) {
      if (current.step == PurchaseFlowStep.completed) {
        _showSuccessDialog();
      } else if (current.step == PurchaseFlowStep.failed && current.errorMessage != null) {
        _showErrorDialog(current.errorMessage!);
      }
    });

    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: purchaseState.isProcessing
              ? null
              : () => Navigator.of(context).pop(),
        ),
        title: const Text('Payment'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Purchase summary
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order Summary', style: textTheme.headlineSmall),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${purchaseState.selectedPackage?.displayName ?? ''} Package',
                                style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                              ),
                              Text(
                                '${purchaseState.selectedPackage?.tokens ?? 0} tokens',
                                style: textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total', style: textTheme.headlineMedium),
                              Text(
                                purchaseState.selectedPackage?.formattedPrice ?? '£0.00',
                                style: textTheme.displaySmall?.copyWith(
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Payment method section
                    Text('Payment method', style: textTheme.headlineSmall),
                    const SizedBox(height: 12),

                    // Stripe Card Field
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: CardField(
                        onCardChanged: (card) {
                          setState(() {
                            _isCardComplete = card?.complete ?? false;
                          });
                        },
                        enablePostalCode: false,
                        autofocus: true,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                        // The box around it draws the border, so the field itself has none
                        decoration: const InputDecoration(
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                          hintText: 'Card number',
                          hintStyle: TextStyle(color: AppColors.textTertiary),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Secure payment indicator
                    Row(
                      children: [
                        const Icon(Icons.lock_outline, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text('Secure payment powered by Stripe', style: textTheme.bodySmall),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Test card info (only show in non-production)
                    if (!kReleaseMode)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.input),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline, size: 16, color: AppColors.primaryDeep),
                                const SizedBox(width: 8),
                                Text(
                                  'Test mode',
                                  style: textTheme.labelLarge?.copyWith(color: AppColors.primaryDeep),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Use test card: 4242 4242 4242 4242\nAny future expiry date and CVC',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom CTA
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: SafeArea(
                top: false,
                child: AppButton(
                  label: 'Pay ${purchaseState.selectedPackage?.formattedPrice ?? '£0.00'}',
                  loading: purchaseState.isProcessing,
                  onPressed: _isCardComplete ? _handlePayment : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePayment() async {
    await ref.read(purchaseProvider.notifier).executePurchase();
  }

  void _showSuccessDialog() {
    final purchaseResponse = ref.read(purchaseProvider).purchaseResponse;
    final tokensAdded = purchaseResponse?.tokenAmount.toInt() ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 28),
            SizedBox(width: 12),
            Flexible(child: Text('Payment successful!')),
          ],
        ),
        content: Text(
          'Successfully added $tokensAdded ${tokensAdded == 1 ? 'token' : 'tokens'} to your wallet!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Close dialog
              Navigator.of(context).pop();
              // Close payment screen
              Navigator.of(context).pop();
              // Close purchase screen
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 28),
            SizedBox(width: 12),
            Flexible(child: Text('Payment failed')),
          ],
        ),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: AppTheme.quietLink,
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(purchaseProvider.notifier).retry();
            },
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
