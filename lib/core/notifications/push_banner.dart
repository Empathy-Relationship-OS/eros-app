import 'dart:async';

import 'package:flutter/material.dart';
import 'package:eros_app/core/notifications/messaging_client.dart';
import 'package:eros_app/core/theme/app_colors.dart';

/// The in-app banner for a push that arrives in the foreground, where the OS shows nothing
/// (RFC-006 §6.4). Shows the push's own title and body, which are generic (D-19).
///
/// Slides in from the top, hides itself after [visibleFor], and can be swiped up to dismiss.
class PushBanner extends StatefulWidget {
  const PushBanner({
    super.key,
    required this.message,
    required this.onTap,
    required this.onDismissed,
    this.visibleFor = const Duration(seconds: 5),
  });

  final PushMessage message;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  final Duration visibleFor;

  @override
  State<PushBanner> createState() => _PushBannerState();
}

class _PushBannerState extends State<PushBanner> {
  Timer? _timer;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.visibleFor, widget.onDismissed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.message.title ?? '';
    final body = widget.message.body ?? '';
    return SafeArea(
      bottom: false,
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : const Offset(0, -1.5),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: Dismissible(
          key: const ValueKey('pushBanner'),
          direction: DismissDirection.up,
          onDismissed: (_) => widget.onDismissed(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Semantics(
              button: true,
              liveRegion: true,
              label: [title, body].where((s) => s.isNotEmpty).join('. '),
              excludeSemantics: true,
              child: Material(
                color: AppColors.cardBackground,
                elevation: 6,
                shadowColor: AppColors.shadow,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: widget.onTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (title.isNotEmpty)
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                if (body.isNotEmpty)
                                  Text(
                                    body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
