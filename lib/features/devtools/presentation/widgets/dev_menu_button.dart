import 'package:flutter/material.dart';
import '../dev_menu_navigation.dart';

/// Wraps the whole app (via `MaterialApp.builder`) with a small draggable
/// "DEV" button that opens the dev menu.
///
/// It sits above the app's [Navigator], so it is visible on every screen,
/// including while signed out (when you pick a persona). Only ever built
/// behind `if (DevtoolsConfig.enabled)`.
class DevOverlay extends StatelessWidget {
  final Widget child;

  const DevOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        const DevMenuButton(),
      ],
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
