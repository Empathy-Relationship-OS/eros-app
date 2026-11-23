import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_theme.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/features/safety/data/models/safety_models.dart';
import 'package:eros_app/features/safety/presentation/providers/report_provider.dart';
import 'package:eros_app/features/safety/presentation/widgets/safety_copy.dart';

/// What the block sheet ended with.
enum BlockSheetResult {
  /// Blocked (now or before), or not a match any more: they should leave the screen.
  blocked,

  /// A date is in progress, and the person chose to cancel it.
  cancelDate,
}

/// "Block" on a match (RFC-009 §5.8, D-3, CF-F4). Confirms, then `POST /safety/blocks`.
///
/// On the 409 `ACTIVE_DATE` it says to cancel the date first; with [canCancelDate] it offers a
/// "Cancel date" button, which pops [BlockSheetResult.cancelDate] so the caller opens its cancel
/// flow. Pops null if the person backed out. Open it with `openBlockFlow`.
class BlockSheet extends ConsumerStatefulWidget {
  final String userId;
  final String name;
  final bool canCancelDate;

  const BlockSheet({
    super.key,
    required this.userId,
    required this.name,
    required this.canCancelDate,
  });

  @override
  ConsumerState<BlockSheet> createState() => _BlockSheetState();
}

class _BlockSheetState extends ConsumerState<BlockSheet> {
  bool _submitting = false;
  bool _activeDate = false;
  String? _error;

  Future<void> _block() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    String? error;
    var outcome = BlockOutcome.blocked;
    try {
      outcome = await ref.read(safetyRepositoryProvider).block(widget.userId);
    } on NotFoundException {
      // Not a match any more (they may have blocked first): nothing left to block.
      outcome = BlockOutcome.blocked;
    } on NetworkException {
      error = SafetyCopy.networkError;
    } catch (_) {
      error = SafetyCopy.blockFailed;
    }
    if (!mounted) return;
    if (error == null && outcome == BlockOutcome.blocked) {
      Navigator.of(context).pop(BlockSheetResult.blocked);
      return;
    }
    setState(() {
      _submitting = false;
      _error = error;
      _activeDate = error == null && outcome == BlockOutcome.activeDate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _activeDate
              ? [
                  Text(SafetyCopy.blockActiveDateTitle, style: textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(SafetyCopy.blockActiveDate, style: textTheme.bodyLarge),
                  const SizedBox(height: 24),
                  if (widget.canCancelDate) ...[
                    AppButton(
                      label: SafetyCopy.cancelDate,
                      onPressed: () => Navigator.of(context).pop(BlockSheetResult.cancelDate),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: AppTheme.quietLink,
                      child: const Text(SafetyCopy.notNow),
                    ),
                  ] else
                    AppButton(
                      label: SafetyCopy.ok,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ]
              : [
                  Text(SafetyCopy.blockTitle(widget.name), style: textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(SafetyCopy.blockBody, style: textTheme.bodyLarge),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: textTheme.bodyMedium?.copyWith(color: AppColors.error)),
                  ],
                  const SizedBox(height: 24),
                  AppButton(
                    label: SafetyCopy.blockConfirm,
                    kind: AppButtonKind.destructive,
                    loading: _submitting,
                    onPressed: _block,
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                    style: AppTheme.quietLink,
                    child: const Text(SafetyCopy.notNow),
                  ),
                ],
        ),
      ),
    );
  }
}
