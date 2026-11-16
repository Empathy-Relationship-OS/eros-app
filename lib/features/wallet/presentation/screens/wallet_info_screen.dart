import 'package:flutter/material.dart';
import 'package:eros_app/features/wallet/presentation/widgets/wallet_copy.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';

/// Wallet Info Screen - Explains how tokens work
class WalletInfoScreen extends StatelessWidget {
  const WalletInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Date tokens, explained')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Tokens Section
            _InfoSection(
              title: 'Date tokens',
              items: [
                _InfoItem(
                  icon: Icons.local_drink_outlined,
                  text: WalletCopy.singleTokenPrice,
                ),
                _InfoItem(
                  icon: Icons.local_bar_outlined,
                  text: 'Going for drinks costs 1 token.',
                ),
                _InfoItem(
                  icon: Icons.refresh,
                  text: WalletCopy.refundRule,
                ),
                _InfoItem(
                  icon: Icons.receipt_outlined,
                  text:
                      'This is our only business model. We don\'t sell your data, show you advertisements nor sell premium subscriptions.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Packages Section
            _InfoSection(
              title: 'Packages',
              items: [
                _InfoItem(
                  icon: Icons.sell_outlined,
                  text: WalletCopy.packSaving,
                ),
                _InfoItem(
                  icon: Icons.autorenew,
                  text: WalletCopy.packageRefundRule,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Sharing is caring Section
            _InfoSection(
              title: 'Sharing is caring',
              items: [
                _InfoItem(
                  icon: Icons.card_giftcard_outlined,
                  text:
                      'You can earn free tokens by sharing your Muse link with friends.',
                ),
                _InfoItem(
                  icon: Icons.send_outlined,
                  text:
                      'You can transfer your purchased tokens to friends through the helpdesk.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Cancel policy Section
            _InfoSection(
              title: 'Cancel policy',
              items: [
                _InfoItem(
                  icon: Icons.warning_outlined,
                  text:
                      'Canceling a date may impact your badges and could result in your account being frozen.',
                ),
                _InfoItem(
                  icon: Icons.event_outlined,
                  text:
                      'You can reschedule up to 24 hours before the date to receive a refund; after that, refunds are not available.',
                ),
                _InfoItem(
                  icon: Icons.local_drink_outlined,
                  text:
                      'Once a date is scheduled, the token used is non-refundable if you cancel. However, if your date cancels, you will receive a refund.',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Learn more button
            Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(
                  children: [
                    Text(
                      'Want to know more about date tokens and packages?',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Learn More',
                      kind: AppButtonKind.outline,
                      expand: false,
                      onPressed: () {
                        // TODO: Link to help center or documentation
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Help center coming soon'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Info section widget with title and items
class _InfoSection extends StatelessWidget {
  final String title;
  final List<_InfoItem> items;

  const _InfoSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: item,
            ),
        ],
      ),
    );
  }
}

/// Info item widget with icon and text
class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.primaryTint,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppColors.primaryDeep,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}
