import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/main.dart';

void main() {
  testWidgets('App loads welcome screen', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const ProviderScope(child: ErosApp()));

    // Verify that the welcome screen loads with the "Start Dating" button
    expect(find.text('Muse'), findsOneWidget);
    expect(find.text('Start Dating'), findsOneWidget);
    expect(
      find.text('Skip the small talk,\ngo straight to the date'),
      findsOneWidget,
    );
  });

  testWidgets('Navigate to auth method selection', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(const ProviderScope(child: ErosApp()));

    // Tap the "Start Dating" button
    await tester.tap(find.text('Start Dating'));
    await tester.pumpAndSettle();

    // Verify that we navigate to auth method selection screen
    expect(find.text('How would you like to\nsign up?'), findsOneWidget);
    expect(find.text('Continue with Email'), findsOneWidget);
  });
}
