import 'dart:io';

import 'package:eros_app/features/verification/presentation/widgets/pose_illustration.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every pose the server can pick has its own drawing', () {
    // Backend `Pose` (VF-B1).
    for (final key in ['HAND_RAISED', 'TWO_FINGERS_BY_CHIN', 'HAND_ON_HEAD', 'THUMBS_UP']) {
      final asset = PoseIllustration.assetFor(key);
      expect(asset, isNot(PoseIllustration.genericAsset), reason: key);
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });

  test('a pose this build doesn\'t know gets the generic "copy this pose" drawing', () {
    expect(PoseIllustration.assetFor('BOTH_HANDS_UP'), PoseIllustration.genericAsset);
    expect(PoseIllustration.assetFor(''), PoseIllustration.genericAsset);
    expect(File(PoseIllustration.genericAsset).existsSync(), isTrue);
  });

  test('the wait after a limit is said in words, rounded up', () {
    expect(VerificationCopy.limitReached(null), contains('Try again tomorrow.'));
    expect(VerificationCopy.limitReached(const Duration(minutes: 20)), contains('under an hour'));
    expect(VerificationCopy.limitReached(const Duration(minutes: 60)), contains('about an hour'));
    expect(VerificationCopy.limitReached(const Duration(minutes: 61)), contains('about 2 hours'));
  });
}
