import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/deposit_provider.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:eros_app/features/dates/presentation/widgets/token_amount.dart';
import 'package:eros_app/features/dates/presentation/widgets/deadline_countdown.dart';
import 'package:eros_app/features/wallet/presentation/providers/wallet_balance_provider.dart';
import 'package:eros_app/features/wallet/presentation/screens/payment_screen.dart';

/// UI-6: Deposit sheet (modal bottom sheet)
///
/// - Shows token cost and agreed time range
/// - Checks balance, prompts top-up if insufficient
/// - Shows partner deposit status
/// - Deadline countdown
/// - Commit button with loading state
/// - On success: both paid → push venue ranking; waiting → toast
class DepositSheet extends ConsumerStatefulWidget {
  final DateDetail dateDetail;
  final String currentUid;
  final String agreedTimeRange; // e.g. "Sat 20 Sep, 19:00 - 21:00"

  const DepositSheet({
    super.key,
    required this.dateDetail,
    required this.currentUid,
    required this.agreedTimeRange,
  });

  @override
  ConsumerState<DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends ConsumerState<DepositSheet> {
  bool _isSubmitting = false;
  bool _needsTopUp = false;

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletBalanceProvider);
    final balance = walletState.balance?.availableBalance ?? '0.00';
    final balanceNum = double.tryParse(balance) ?? 0.0;
    final costNum = double.tryParse(widget.dateDetail.tokenCost) ?? 0.0;
    final hasSufficientBalance = balanceNum >= costNum;

    final partnerDeposit = widget.dateDetail.myDeposit(widget.currentUid) ==
            ParticipantDepositStatus.paid
        ? widget.dateDetail.partnerDeposit(widget.currentUid)
        : ParticipantDepositStatus.notApplicable;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                DatesCopy.depositHeading,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Agreed time range
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppColors.primaryOrange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.agreedTimeRange,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Amount block
              Center(
                child: Column(
                  children: [
                    TokenAmount(
                      amount: widget.dateDetail.tokenCost,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      DatesCopy.depositRefundCaption,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Balance row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasSufficientBalance || _needsTopUp
                      ? AppColors.background
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasSufficientBalance || _needsTopUp
                        ? Colors.transparent
                        : AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DatesCopy.depositBalanceLabel(balance),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: hasSufficientBalance || _needsTopUp
                            ? AppColors.textPrimary
                            : AppColors.error,
                      ),
                    ),
                    if (!hasSufficientBalance && !_needsTopUp)
                      const Icon(
                        Icons.warning_rounded,
                        size: 20,
                        color: AppColors.error,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Partner row
              if (partnerDeposit != ParticipantDepositStatus.notApplicable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DatesCopy.depositPartnerStatus(
                          widget.dateDetail.partnerName(widget.currentUid),
                          partnerDeposit == ParticipantDepositStatus.paid,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (partnerDeposit == ParticipantDepositStatus.paid)
                        const Icon(
                          Icons.check_circle,
                          size: 20,
                          color: AppColors.success,
                        ),
                    ],
                  ),
                ),

              // Deadline countdown
              if (widget.dateDetail.depositDeadline != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DeadlineCountdown(
                    deadline: widget.dateDetail.depositDeadline!,
                    onExpired: () {
                      // Trigger refetch in parent
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              const SizedBox(height: 4),
              const Text(
                DatesCopy.depositDeadlineCaption,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Primary button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : (hasSufficientBalance && !_needsTopUp
                          ? _handleCommit
                          : _handleTopUp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasSufficientBalance && !_needsTopUp
                        ? AppColors.primaryOrange
                        : AppColors.textPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.disabled,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          hasSufficientBalance && !_needsTopUp
                              ? 'Commit ${widget.dateDetail.tokenCost}'
                              : DatesCopy.depositTopUpButton,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCommit() async {
    setState(() => _isSubmitting = true);

    try {
      final response = await ref
          .read(depositProvider(widget.dateDetail.dateId.toString()).notifier)
          .payDeposit();

      if (!mounted) return;

      // Update wallet balance
      ref
          .read(walletBalanceProvider.notifier)
          .updateBalance(response.newBalance);

      if (response.transitionedToRanking) {
        // Both paid! Show success and push to venue ranking
        Navigator.of(context).pop(); // Close sheet
        _showSuccessOverlay(DatesCopy.depositSuccessBothPaid, () {
          // TODO: Push to venue ranking screen (UI-7)
          // For now, just close - parent will refetch and show ranking CTA
        });
      } else {
        // You paid, waiting for partner
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(DatesCopy.depositSuccessWaiting(
              widget.dateDetail.partnerName(widget.currentUid),
            )),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on ConflictException catch (e) {
      if (!mounted) return;

      if (e.message.contains('insufficient_balance')) {
        // Switch to top-up mode
        setState(() {
          _isSubmitting = false;
          _needsTopUp = true;
        });
      } else {
        // Conflict: already paid, deadline passed, or state changed
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(DatesCopy.cancelSomethingChanged),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _handleTopUp() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PaymentScreen(),
      ),
    ).then((_) {
      // On return, refetch balance and reset top-up flag
      ref.refresh(walletBalanceProvider);
      setState(() => _needsTopUp = false);
    });
  }

  void _showSuccessOverlay(String message, VoidCallback onDismiss) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Auto-dismiss after 1.2s
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        onDismiss();
      }
    });
  }
}
