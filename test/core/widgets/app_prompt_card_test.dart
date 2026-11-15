import 'package:eros_app/core/theme/app_theme.dart';
import 'package:eros_app/core/widgets/app_prompt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppPromptCard', () {
    late int opens;
    late int dismissals;

    Future<void> pump(WidgetTester tester, {String? subtitle}) {
      opens = 0;
      dismissals = 0;
      return tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: AppPromptCard(
            icon: Icons.auto_awesome_outlined,
            title: 'Tell us what dates you like',
            subtitle: subtitle,
            onTap: () => opens++,
            onDismiss: () => dismissals++,
            dismissTooltip: 'Dismiss',
          ),
        ),
      ));
    }

    testWidgets('tapping the card opens, without dismissing', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Tell us what dates you like'));

      expect(opens, 1);
      expect(dismissals, 0);
    });

    testWidgets('the close button dismisses, without opening', (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Dismiss'));

      expect(dismissals, 1);
      expect(opens, 0);
    });

    testWidgets('shows the second line only when there is one', (tester) async {
      await pump(tester);
      expect(find.text('One selfie, about a minute.'), findsNothing);

      await pump(tester, subtitle: 'One selfie, about a minute.');
      expect(find.text('One selfie, about a minute.'), findsOneWidget);
    });
  });
}
