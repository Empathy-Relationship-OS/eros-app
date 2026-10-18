import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eros_app/features/devtools/devtools_config.dart';
import 'package:eros_app/features/devtools/presentation/dev_menu_navigation.dart';
import 'package:eros_app/features/devtools/presentation/widgets/dev_menu_button.dart';
import 'package:eros_app/main.dart';

/// Checks the dev menu entry points in the real [ErosApp] follow
/// [DevtoolsConfig.enabled].
///
/// A plain `flutter test` has no DEVTOOLS define, so this checks the app
/// with devtools compiled out. The same file covers the other builds:
///
/// ```bash
/// # beta with DEVTOOLS=true: still no DEV button, no /dev route
/// flutter test --dart-define=ENV=beta --dart-define=DEVTOOLS=true test/features/devtools/eros_app_gating_test.dart
/// # local with DEVTOOLS=true: DEV button and /dev route present
/// flutter test --dart-define=ENV=local --dart-define=DEVTOOLS=true test/features/devtools/eros_app_gating_test.dart
/// ```
void main() {
  testWidgets(
      'DEV button and /dev route exist only when devtools are enabled '
      '(enabled=${DevtoolsConfig.enabled})', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ErosApp()));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.routes!.containsKey(devMenuRoute), DevtoolsConfig.enabled);
    expect(app.builder != null, DevtoolsConfig.enabled);
    expect(find.byType(DevMenuButton),
        DevtoolsConfig.enabled ? findsOneWidget : findsNothing);
    expect(find.text('DEV'),
        DevtoolsConfig.enabled ? findsOneWidget : findsNothing);

    // Let AuthLoadingScreen's post-frame routing settle (it fails to reach
    // Firebase in tests and shows its error state, which is fine here).
    await tester.pumpAndSettle();
  });
}
