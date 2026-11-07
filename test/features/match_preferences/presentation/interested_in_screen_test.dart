import 'package:eros_app/features/match_preferences/data/match_preferences_repository.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/interested_in_screen.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  List<Gender> initialSelection = const [],
  required Future<void> Function(List<Gender>) onContinue,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: InterestedInScreen(initialSelection: initialSelection, onContinue: onContinue),
  ));
}

bool _continueEnabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed != null;

/// True when [label]'s row shows a ticked box.
bool _ticked(WidgetTester tester, String label) => tester.any(find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
      matching: find.byIcon(Icons.check_box),
    ));

void main() {
  group('InterestedInScreen', () {
    testWidgets('lists every gender with the profile\'s labels', (tester) async {
      await _pump(tester, onContinue: (_) async {});

      expect(find.text('Who are you interested in?'), findsOneWidget);
      for (final label in ['Male', 'Female', 'Non-Binary', 'Other']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('Continue is disabled with nothing ticked', (tester) async {
      await _pump(tester, onContinue: (_) async {});
      expect(_continueEnabled(tester), isFalse);

      await tester.tap(find.text('Female'));
      await tester.pump();
      expect(_continueEnabled(tester), isTrue);

      await tester.tap(find.text('Female'));
      await tester.pump();
      expect(_continueEnabled(tester), isFalse);
    });

    testWidgets('pre-ticks the initial selection, and saves nothing until Continue',
        (tester) async {
      var calls = 0;
      await _pump(
        tester,
        initialSelection: const [Gender.female],
        onContinue: (_) async => calls++,
      );

      expect(_ticked(tester, 'Female'), isTrue);
      expect(_ticked(tester, 'Male'), isFalse);
      expect(_continueEnabled(tester), isTrue);
      expect(calls, 0);
    });

    testWidgets('hands Continue the choice in enum order', (tester) async {
      List<Gender>? sent;
      await _pump(tester, onContinue: (genders) async => sent = genders);

      await tester.tap(find.text('Other'));
      await tester.pump();
      await tester.tap(find.text('Male'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(sent, [Gender.male, Gender.other]);
    });

    testWidgets('shows the server\'s message when the save fails, and lets Continue retry',
        (tester) async {
      var calls = 0;
      await _pump(
        tester,
        initialSelection: const [Gender.male],
        onContinue: (_) async {
          calls++;
          throw MatchPreferencesValidationException('Choose who you\'re interested in first');
        },
      );

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Choose who you\'re interested in first'), findsOneWidget);
      expect(_continueEnabled(tester), isTrue);

      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(calls, 2);
    });
  });
}
