import 'package:flutter_test/flutter_test.dart';
import 'package:eros_app/features/devtools/devtools_config.dart';

void main() {
  group('isEnabled', () {
    test('is true for DEVTOOLS=true on local', () {
      expect(isEnabled(true, 'local'), isTrue);
    });

    test('is true for DEVTOOLS=true on develop', () {
      expect(isEnabled(true, 'develop'), isTrue);
    });

    test('is false for DEVTOOLS=true on beta', () {
      expect(isEnabled(true, 'beta'), isFalse);
    });

    test('is false for DEVTOOLS=true on production', () {
      expect(isEnabled(true, 'production'), isFalse);
    });

    test('is false without the DEVTOOLS flag, even on local', () {
      expect(isEnabled(false, 'local'), isFalse);
      expect(isEnabled(false, 'develop'), isFalse);
    });

    test('is false for an unknown environment', () {
      expect(isEnabled(true, 'staging'), isFalse);
      expect(isEnabled(true, ''), isFalse);
    });
  });

  group('DevtoolsConfig.enabled', () {
    test('matches isEnabled for the defines this test run was built with', () {
      const flag = bool.fromEnvironment('DEVTOOLS');
      const env = String.fromEnvironment('ENV', defaultValue: 'local');
      expect(DevtoolsConfig.enabled, isEnabled(flag, env));
    });
  });
}
