import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:eros_app/features/wallet/presentation/screens/wallet_info_screen.dart';
import 'package:eros_app/features/wallet/domain/models/wallet_models.dart';
import 'package:intl/intl.dart';

/// Date Wallet Screen - Displays balance and transaction history
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Fetch balance and transactions on init
    Future.microtask(() {
      ref.read(walletBalanceProvider.notifier).fetchBalance();
      ref.read(transactionHistoryProvider.notifier).fetchTransactions();
    });

    // Setup infinite scroll
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      ref.read(transactionHistoryProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceState = ref.watch(walletBalanceProvider);
    final historyState = ref.watch(transactionHistoryProvider);

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
          'Date wallet',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WalletInfoScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(walletBalanceProvider.notifier).refresh(),
            ref.read(transactionHistoryProvider.notifier).refresh(),
          ]);
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Balance Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _BalanceCard(balance: balanceState.balance),
              ),
            ),

            // History Header
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Text(
                  'History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),

            // Transaction List
            if (historyState.isLoading && !historyState.hasTransactions)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (historyState.hasError && !historyState.hasTransactions)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(
                        historyState.errorMessage ?? 'Failed to load history',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref
                              .read(transactionHistoryProvider.notifier)
                              .refresh();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (!historyState.hasTransactions)
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No transactions yet',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= historyState.transactions.length) {
                      // Show loading indicator at bottom
                      return historyState.hasMore
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child:
                                  Center(child: CircularProgressIndicator()),
                            )
                          : const SizedBox.shrink();
                    }

                    final transaction = historyState.transactions[index];
                    final isFirst = index == 0;
                    final showDateHeader = isFirst ||
                        !_isSameDay(
                          transaction.createdAt,
                          historyState.transactions[index - 1].createdAt,
                        );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDateHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              _formatDate(transaction.createdAt),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        _TransactionTile(transaction: transaction),
                      ],
                    );
                  },
                  childCount: historyState.transactions.length +
                      (historyState.hasMore ? 1 : 0),
                ),
              ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (_isSameDay(now, date)) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat('EEEE').format(date); // Day of week
    } else {
      return DateFormat('d MMMM').format(date); // "31 March"
    }
  }
}

/// Balance card widget
class _BalanceCard extends StatelessWidget {
  final WalletBalance? balance;

  const _BalanceCard({this.balance});

  @override
  Widget build(BuildContext context) {
    final tokenCount = balance?.balance.toInt() ?? 0;
    final tokenText = tokenCount == 1 ? '1 token' : '$tokenCount tokens';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
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
        children: [
          Text(
            tokenText,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          // TODO: Add "Add more tokens" and "Request refund" buttons when purchase/refund flows are implemented
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _OutlinedButton(
                onPressed: () {
                  _showComingSoon(context, 'Purchase tokens');
                },
                child: const Text('Add more tokens'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Transaction tile widget
class _TransactionTile extends StatelessWidget {
  final Transaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // TODO: Handle tap (e.g., show transaction details or navigate to related date)
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getIconColor().withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIcon(),
                    color: _getIconColor(),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Description
                Expanded(
                  child: Text(
                    transaction.displayText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),

                // Amount
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: transaction.isCredit
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    transaction.formattedAmount,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color:
                          transaction.isCredit ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (transaction.type) {
      case TransactionType.purchase:
        return Icons.receipt_outlined;
      case TransactionType.spend:
        return Icons.local_drink_outlined;
      case TransactionType.refund:
        return Icons.refresh;
      case TransactionType.adjustment:
        return Icons.tune;
    }
  }

  Color _getIconColor() {
    if (transaction.isCredit) {
      return AppColors.success;
    } else {
      return AppColors.primary;
    }
  }
}

/// Custom outlined button
class _OutlinedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const _OutlinedButton({
    this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: child,
    );
  }
}
