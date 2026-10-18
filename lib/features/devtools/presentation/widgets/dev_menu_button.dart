import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/time/server_clock.dart';
import '../dev_menu_navigation.dart';
import '../time_travel.dart';

/// Wraps the whole app (via `MaterialApp.builder`) with a small draggable
/// "DEV" button that opens the dev menu, and the "time shifted" banner.
///
/// It sits above the app's [Navigator], so it is visible on every screen,
/// including while signed out (when you pick a persona). Only ever built
/// behind `if (DevtoolsConfig.enabled)`.
class DevOverlay extends StatelessWidget {
  final Widget child;

  /// Clock whose [ServerClock.devOffset] drives the banner. Defaults to
  /// [ServerClock.instance].
  final ServerClock? clock;

  const DevOverlay({super.key, required this.child, this.clock});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        TimeShiftedBanner(clock: clock, child: child),
        const DevMenuButton(),
      ],
    );
  }
}

/// While the backend clock is shifted, shows a thin "TIME SHIFTED +1d 1h"
/// banner above [child], on every screen. Tap it to open the dev menu on the
/// Time tab.
///
/// Listens to [ServerClock.devOffset], which every API response updates
/// (including `/dev` responses), so it appears and disappears on its own.
/// The banner takes the status bar inset, and [child] is laid out below it.
class TimeShiftedBanner extends StatelessWidget {
  final Widget child;

  /// Defaults to [ServerClock.instance].
  final ServerClock? clock;

  /// Defaults to opening the dev menu on [DevMenuTab.time].
  final VoidCallback? onTap;

  const TimeShiftedBanner({
    super.key,
    required this.child,
    this.clock,
    this.onTap,
  });

  /// Amber, from [AppColors.warning]: a warning colour distinct from the
  /// brand coral, with black text.
  static const Color color = AppColors.warning;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: (clock ?? ServerClock.instance).devOffset,
      // Keep the app subtree mounted when the banner toggles.
      child: child,
      builder: (context, offset, child) {
        final shifted = offset != Duration.zero;
        final media = MediaQuery.of(context);
        return Column(
          children: [
            if (shifted) _bar(media, offset),
            Expanded(
              key: const ValueKey('devOverlayApp'),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: shifted,
                child: child!,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _bar(MediaQueryData media, Duration offset) {
    final text = 'TIME SHIFTED ${formatShortOffset(offset)}';
    return Semantics(
      button: true,
      label: '$text. Open the time travel panel',
      excludeSemantics: true,
      child: Material(
        key: const Key('timeShiftedBanner'),
        color: color,
        child: InkWell(
          onTap: onTap ?? () => openDevMenu(tab: DevMenuTab.time),
          child: Padding(
            padding: EdgeInsets.only(
              top: media.padding.top + 2,
              bottom: 2,
              left: 8 + media.padding.left,
              right: 8 + media.padding.right,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.schedule, size: 14, color: AppColors.black),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The draggable "DEV" button. Tap to open the dev menu.
class DevMenuButton extends StatefulWidget {
  /// Opens the dev menu. Defaults to [openDevMenu] through
  /// [devtoolsNavigatorKey].
  final VoidCallback? onPressed;

  const DevMenuButton({super.key, this.onPressed});

  static const Size size = Size(52, 32);

  @override
  State<DevMenuButton> createState() => _DevMenuButtonState();
}

class _DevMenuButtonState extends State<DevMenuButton> {
  /// Top-left of the button. Null until first laid out, then defaults to the
  /// right edge, a third of the way down.
  Offset? _position;

  Offset _clamp(Offset p, Size screen, EdgeInsets padding) {
    final maxX = screen.width - DevMenuButton.size.width - padding.right;
    final maxY = screen.height - DevMenuButton.size.height - padding.bottom;
    return Offset(
      p.dx.clamp(padding.left, maxX < padding.left ? padding.left : maxX),
      p.dy.clamp(padding.top, maxY < padding.top ? padding.top : maxY),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    final padding = media.padding;
    final position = _clamp(
      _position ??
          Offset(screen.width - DevMenuButton.size.width - 8, screen.height / 3),
      screen,
      padding,
    );

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Semantics(
        button: true,
        label: 'Open developer tools',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed ?? () => openDevMenu(),
          onPanUpdate: (details) => setState(() {
            _position = _clamp(position + details.delta, screen, padding);
          }),
          child: Material(
            color: Colors.black.withValues(alpha: 0.75),
            elevation: 4,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox.fromSize(
              size: DevMenuButton.size,
              child: const Center(
                child: Text(
                  'DEV',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1,
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
