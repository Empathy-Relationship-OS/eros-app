import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/core/time/server_clock.dart';
import 'package:eros_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:eros_app/features/wallet/presentation/screens/wallet_info_screen.dart';
import 'package:eros_app/features/wallet/presentation/screens/purchase_tokens_screen.dart';
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Date wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'How the wallet works',
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
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Balance Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _BalanceCard(balance: balanceState.balance),
              ),
            ),

            // History Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text('History', style: textTheme.headlineMedium),
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
                        style: textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Retry',
                        kind: AppButtonKind.secondary,
                        expand: false,
                        onPressed: () {
                          ref
                              .read(transactionHistoryProvider.notifier)
                              .refresh();
                        },
                      ),
                    ],
                  ),
                ),
              )
            else if (!historyState.hasTransactions)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No transactions yet',
                    style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
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
                              style: textTheme.labelLarge
                                  ?.copyWith(color: AppColors.textSecondary),
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

  /// Same calendar day in the device's timezone.
  bool _isSameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  /// Buckets a server timestamp ("Today", "Yesterday", ...). Uses ServerClock
  /// so the buckets agree with the backend's clock; converts to local only for
  /// the calendar-day display.
  String _formatDate(DateTime serverTimestamp) {
    final now = ServerClock.instance.now().toLocal();
    final date = serverTimestamp.toLocal();
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

    // The wallet's one loud block: the balance on a tint, with the way to add more
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Text(
            tokenText,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 44,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Add more tokens',
            icon: Icons.add_circle_outline,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PurchaseTokensScreen(),
                ),
              );
            },
          ),
        ],
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
    final textTheme = Theme.of(context).textTheme;
    final amountColor = transaction.isCredit ? AppColors.success : AppColors.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          side: const BorderSide(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
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
                    color: transaction.isCredit
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.primaryTint,
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
                    style: textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Amount
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: amountColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    transaction.formattedAmount,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: amountColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
      return AppColors.primaryDeep;
    }
  }
}

