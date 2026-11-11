import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The bundled drawing of the pose the server picked (RFC-008 D-12).
///
/// A key this build doesn't know gets a generic "copy this pose" drawing: the instruction text
/// beside it still says what to do. Decorative for screen readers, which read the instruction.
class PoseIllustration extends StatelessWidget {
  final String poseKey;
  final double size;

  const PoseIllustration({super.key, required this.poseKey, this.size = 96});

  /// The poses the server can pick today (backend `Pose`, VF-B1).
  static const Map<String, String> assets = {
    'HAND_RAISED': 'assets/images/verification/pose_hand_raised.svg',
    'TWO_FINGERS_BY_CHIN': 'assets/images/verification/pose_two_fingers_by_chin.svg',
    'HAND_ON_HEAD': 'assets/images/verification/pose_hand_on_head.svg',
    'THUMBS_UP': 'assets/images/verification/pose_thumbs_up.svg',
  };
  static const String genericAsset = 'assets/images/verification/pose_generic.svg';

  static String assetFor(String poseKey) => assets[poseKey] ?? genericAsset;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SvgPicture.asset(assetFor(poseKey), width: size, height: size),
      );
}
