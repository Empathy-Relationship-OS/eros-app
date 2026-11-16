import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/features/wallet/domain/models/wallet_models.dart';
import 'package:eros_app/features/wallet/presentation/providers/purchase_provider.dart';
import 'package:eros_app/features/wallet/presentation/screens/payment_screen.dart';

/// Screen for selecting a token package to purchase
class PurchaseTokensScreen extends ConsumerWidget {
  const PurchaseTokensScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchaseState = ref.watch(purchaseProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            ref.read(purchaseProvider.notifier).reset();
            Navigator.of(context).pop();
          },
        ),
        title: const Text('Add tokens'),
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
                    // Header
                    Text('Select a package', style: textTheme.displaySmall),
                    const SizedBox(height: 8),
                    Text(
                      'Choose the number of tokens you\'d like to add to your wallet',
                      style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),

                    // Package cards
                    ...TokenPackageType.values.map((package) {
                      final isSelected = purchaseState.selectedPackage == package;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _PackageCard(
                          package: package,
                          isSelected: isSelected,
                          onTap: () {
                            ref.read(purchaseProvider.notifier).selectPackage(package);
                          },
                        ),
                      );
                    }),

                    const SizedBox(height: 12),

                    // Terms and conditions
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: purchaseState.acceptedTerms,
                          onChanged: (value) {
                            ref
                                .read(purchaseProvider.notifier)
                                .setAcceptedTerms(value ?? false);
                          },
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              ref
                                  .read(purchaseProvider.notifier)
                                  .setAcceptedTerms(!purchaseState.acceptedTerms);
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Text(
                                'I accept the terms and conditions. All token purchases are non-refundable.',
                                style: textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Info box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('About tokens', style: textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                            'Each token represents a commitment to a date. When you match with someone and agree to meet, you\'ll both use one token.',
                            style: textTheme.bodyMedium,
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
                  label: purchaseState.selectedPackage != null
                      ? 'Continue to payment (${purchaseState.selectedPackage!.formattedPrice})'
                      : 'Continue to payment',
                  onPressed:
                      purchaseState.canProceed ? () => _handleContinue(context, ref) : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleContinue(BuildContext context, WidgetRef ref) async {
    // Initialize purchase (generates idempotency key)
    await ref.read(purchaseProvider.notifier).initializePurchase();

    // Check if initialization succeeded before navigating
    final purchaseState = ref.read(purchaseProvider);
      if (purchaseState.errorMessage != null || purchaseState.idempotencyKey == null) {
        // Initialization failed - show error to user
        if (context.mounted && purchaseState.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(purchaseState.errorMessage!),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
    }

    // Navigate to payment screen only if initialization succeeded
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PaymentScreen(),
        ),
      );
    }
  }
}

/// Widget for displaying a token package option
class _PackageCard extends StatelessWidget {
  final TokenPackageType package;
  final bool isSelected;
  final VoidCallback onTap;

  const _PackageCard({
    required this.package,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isBestValue = package == TokenPackageType.mega;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      selected: isSelected,
      child: Material(
        color: isSelected ? AppColors.primaryTint : AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: isSelected ? AppColors.primaryDeep : AppColors.divider,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Package name and token count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(package.displayName, style: textTheme.headlineMedium),
                              if (isBestValue) const _BestValueBadge(),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${package.tokens} ${package.tokens == 1 ? 'token' : 'tokens'}',
                            style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          package.formattedPrice,
                          style: textTheme.displaySmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          '${package.formattedPricePerToken}/token',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),

                // Savings indicator (if applicable)
                if (package != TokenPackageType.starter) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      // Solid, so it stays a clean green on the selected card's tint
                      color: Color.alphaBlend(
                        AppColors.success.withValues(alpha: 0.12),
                        AppColors.cardBackground,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      _getSavingsText(package),
                      style: textTheme.labelMedium?.copyWith(color: AppColors.success),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getSavingsText(TokenPackageType package) {
    final starterPricePerToken = TokenPackageType.starter.pricePerToken;
    final savings = ((starterPricePerToken - package.pricePerToken) / starterPricePerToken * 100).round();
    return 'Save $savings%';
  }
}

/// "BEST VALUE", beside the package's name. It's a coral fill, so its text is ink.
class _BestValueBadge extends StatelessWidget {
  const _BestValueBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'BEST VALUE',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textOnPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}
