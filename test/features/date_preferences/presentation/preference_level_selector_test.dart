import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/presentation/widgets/preference_level_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PreferenceLevelSelector', () {
    Future<List<PreferenceLevel>> pump(WidgetTester tester, PreferenceLevel value) async {
      final changes = <PreferenceLevel>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PreferenceLevelSelector(value: value, onChanged: changes.add),
        ),
      ));
      return changes;
    }

    testWidgets('offers "Love it", "Happy to" and "Not for me", in that order', (tester) async {
      await pump(tester, PreferenceLevel.ok);

      final labels = ['Love it', 'Happy to', 'Not for me'];
      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
      }
      final xs = [for (final label in labels) tester.getCenter(find.text(label)).dx];
      expect(xs, orderedEquals([...xs]..sort()));
    });

    testWidgets('shows the current level as selected', (tester) async {
      await pump(tester, PreferenceLevel.no);

      final button = tester.widget<SegmentedButton<PreferenceLevel>>(
          find.byType(SegmentedButton<PreferenceLevel>));
      expect(button.selected, {PreferenceLevel.no});
    });

    testWidgets('reports the level tapped', (tester) async {
      final changes = await pump(tester, PreferenceLevel.ok);

      await tester.tap(find.text('Love it'));
      await tester.tap(find.text('Not for me'));

      expect(changes, [PreferenceLevel.love, PreferenceLevel.no]);
    });

    testWidgets('fits a small phone without overflowing', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // The editor's row padding leaves about 256 points on a 320-point phone.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: PreferenceLevelSelector(value: PreferenceLevel.ok, onChanged: (_) {}),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(SegmentedButton<PreferenceLevel>)).height,
          greaterThanOrEqualTo(44));
    });

    test('labels every level', () {
      expect(PreferenceLevel.values.map(PreferenceLevelSelector.labelOf),
          ['Love it', 'Happy to', 'Not for me']);
    });
  });
}
