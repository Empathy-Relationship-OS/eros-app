import 'package:flutter/widgets.dart';

/// Gives [child] the whole height it's offered, so a `Column` with a `Spacer` still pins its
/// action to the bottom, and scrolls instead of overflowing when that height is too small (the
/// keyboard is up on a small phone, or a banner adds lines).
///
/// For short forms only: [IntrinsicHeight] measures the child twice.
class FillOrScroll extends StatelessWidget {
  const FillOrScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}
