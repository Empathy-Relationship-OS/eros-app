import 'package:eros_app/core/navigation/app_navigator.dart';
import 'package:eros_app/features/dates/presentation/screens/date_detail_screen.dart';
import 'package:eros_app/features/dates/presentation/screens/venue_ranking_screen.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../safety/fake_safety_api.dart';
import 'verification_wall_harness.dart';

/// The date screen refetches whenever something shown on top of it closes, so a step the user
/// just finished (the deposit, then the venue ranking the deposit sheet opened) is never offered
/// again from a stale screen.
void main() {
  Future<void> pumpDetail(WidgetTester tester, FakeSafetyApi api) async {
    tallScreen(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: wallOverrides(api),
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        navigatorObservers: [appPageRouteObserver],
        home: const DateDetailScreen(dateId: '7'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  NavigatorState navigator() => appNavigatorKey.currentState!;

  testWidgets('refetches the date when a screen pushed on top of it closes', (tester) async {
    final api = wallApi(
      date: wallDateJson('AWAITING_DEPOSIT', verificationRequired: false),
      status: statusJson('VERIFIED'),
    );
    await pumpDetail(tester, api);
    expect(find.text('Commit with 5 tokens'), findsOneWidget);
    final reads = count(api, dateRequest);

    // The deposit went through and the sheet opened the venue ranking screen. Meanwhile both
    // deposits landed, so the server has moved on.
    api.responses[dateRequest] = wallDateJson('AWAITING_VENUE_RANKING', verificationRequired: false);
    navigator().push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('on top'))));
    await tester.pumpAndSettle();
    navigator().pop();
    await tester.pumpAndSettle();

    expect(count(api, dateRequest), reads + 1);
    expect(find.text('Commit with 5 tokens'), findsNothing);
  });

  testWidgets('refetches the date when a bottom sheet over it closes', (tester) async {
    final api = wallApi(
      date: wallDateJson('AWAITING_DEPOSIT', verificationRequired: false),
      status: statusJson('VERIFIED'),
    );
    await pumpDetail(tester, api);
    final reads = count(api, dateRequest);

    showModalBottomSheet<void>(
      context: navigator().context,
      builder: (_) => const SizedBox(height: 200, child: Text('sheet')),
    );
    await tester.pumpAndSettle();
    navigator().pop();
    await tester.pumpAndSettle();

    expect(count(api, dateRequest), reads + 1);
  });

  testWidgets('"Back to your date" after a venue is assigned goes back to the date', (tester) async {
    final api = wallApi(
      date: wallDateJson('AWAITING_VENUE_RANKING', verificationRequired: false),
      status: statusJson('VERIFIED'),
    )..responses['POST /dates/7/venue-rankings'] = {
        'bothSubmitted': true,
        'venueAssigned': true,
        'assignedVenueId': 1,
      };
    await pumpDetail(tester, api);

    navigator().push(MaterialPageRoute<void>(
      builder: (_) => const VenueRankingScreen(dateId: '7'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DatesCopy.venueRankingSendButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DatesCopy.venueAssignedButton));
    await tester.pumpAndSettle();

    expect(find.byType(DateDetailScreen), findsOneWidget);
    expect(find.byType(VenueRankingScreen), findsNothing);
  });
}
