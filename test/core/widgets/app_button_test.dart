import 'package:eros_app/core/theme/app_theme.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget button) {
  return tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: Center(child: button)),
  ));
}

void main() {
  group('AppButton', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await _pump(tester, AppButton(label: 'Pay deposit', onPressed: () => taps++));

      await tester.tap(find.text('Pay deposit'));

      expect(taps, 1);
    });

    testWidgets('each kind is the themed Material button for it', (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            AppButton(label: 'Primary', onPressed: () {}),
            AppButton(label: 'Secondary', kind: AppButtonKind.secondary, onPressed: () {}),
            AppButton(label: 'Outline', kind: AppButtonKind.outline, onPressed: () {}),
          ],
        ),
      );

      expect(find.widgetWithText(ElevatedButton, 'Primary'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Secondary'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Outline'), findsOneWidget);
    });

    testWidgets('while loading it shows a spinner, hides the label and ignores taps',
        (tester) async {
      var taps = 0;
      await _pump(tester, AppButton(label: 'Pay deposit', loading: true, onPressed: () => taps++));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Pay deposit'), findsNothing);

      await tester.tap(find.byType(ElevatedButton));

      expect(taps, 0);
    });

    testWidgets('is off without an onPressed', (tester) async {
      await _pump(tester, const AppButton(label: 'Pay deposit', onPressed: null));

      expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).enabled, isFalse);
    });

    testWidgets('fills the width it is given, and hugs its label when expand is off',
        (tester) async {
      await _pump(tester, AppButton(label: 'Wide', onPressed: () {}));
      expect(tester.getSize(find.byType(ElevatedButton)).width, 800);

      await _pump(tester, AppButton(label: 'Narrow', expand: false, onPressed: () {}));
      expect(tester.getSize(find.byType(ElevatedButton)).width, lessThan(200));
    });

    testWidgets('a label too long for the button shrinks instead of overflowing',
        (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 120,
          child: AppButton(label: 'A label far too long for this button', onPressed: () {}),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ElevatedButton)).width, 120);
    });

    testWidgets('shows its icons either side of the label', (tester) async {
      await _pump(
        tester,
        AppButton(
          label: 'How Muse works',
          icon: Icons.info_outline,
          trailingIcon: Icons.arrow_forward,
          onPressed: () {},
        ),
      );

      final label = tester.getCenter(find.text('How Muse works')).dx;
      expect(tester.getCenter(find.byIcon(Icons.info_outline)).dx, lessThan(label));
      expect(tester.getCenter(find.byIcon(Icons.arrow_forward)).dx, greaterThan(label));
    });
  });
}
