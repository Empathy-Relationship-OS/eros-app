import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';

/// Wallet Info Screen - Explains how tokens work
class WalletInfoScreen extends StatelessWidget {
  const WalletInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Date tokens, explained',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
                  text:
                      'In Muse, you use date tokens to pay for your dates. A single token costs £7.00.',
                ),
                _InfoItem(
                  icon: Icons.local_bar_outlined,
                  text: 'Going for drinks costs 1 token.',
                ),
                _InfoItem(
                  icon: Icons.refresh,
                  text:
                      'Bought tokens are refundable for 14 days, unless you cancel the date yourself.',
                ),
                _InfoItem(
                  icon: Icons.receipt_outlined,
                  text:
                      'This is our only business model. We don\'t sell your data, show you advertisements nor sell premium subscriptions.',
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Packages Section
            _InfoSection(
              title: 'Packages',
              items: [
                _InfoItem(
                  icon: Icons.sell_outlined,
                  text: 'You can save up to 32% by buying tokens in a pack.',
                ),
                _InfoItem(
                  icon: Icons.autorenew,
                  text:
                      'A package is refundable for 14 days, as long as it\'s complete.',
                ),
              ],
            ),

            const SizedBox(height: 32),

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

            const SizedBox(height: 32),

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

            const SizedBox(height: 48),

            // Learn more button
            Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Want to know more about date tokens and packages?',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Link to help center or documentation
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Help center coming soon'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Learn More',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: item,
              )),
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
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
