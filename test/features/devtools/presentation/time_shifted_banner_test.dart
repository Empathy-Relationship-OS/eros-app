import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eros_app/core/time/server_clock.dart';
import 'package:eros_app/features/devtools/data/devtools_api.dart';
import 'package:eros_app/features/devtools/data/models/devtools_models.dart';
import 'package:eros_app/features/devtools/presentation/dev_menu_navigation.dart';
import 'package:eros_app/features/devtools/presentation/dev_menu_screen.dart';
import 'package:eros_app/features/devtools/presentation/providers/devtools_providers.dart';
import 'package:eros_app/features/devtools/presentation/tabs/personas_tab.dart';
import 'package:eros_app/features/devtools/presentation/tabs/time_tab.dart';
import 'package:eros_app/features/devtools/presentation/widgets/dev_menu_button.dart';

/// Answers the Time tab's `GET /dev/clock` without a network.
class _FakeDevtoolsApi extends DevtoolsApi {
  _FakeDevtoolsApi() : super(devKey: 'test-dev-key-123456');

  @override
  Future<ClockInfo> getClock() async => ClockInfo(
    realTime: DateTime.utc(2026, 10, 16, 12),
    serverTime: DateTime.utc(2026, 10, 17, 13),
    offsetSeconds: 90000,
  );
}

/// Feeds [clock] the headers of a response with [offsetSeconds], or of an
/// unshifted response when null (RFC-003 §5.6).
void _respond(ServerClock clock, {int? offsetSeconds}) {
  clock.updateFromHeaders(
    serverTime: '2026-10-17T13:00:00.000Z',
    offsetSeconds: offsetSeconds?.toString(),
    receivedAt: DateTime.utc(2026, 10, 17, 13),
  );
}

Widget _app(ServerClock clock, {Widget? home}) {
  return ProviderScope(
    overrides: [
      devtoolsKeyProvider.overrideWithValue('test-dev-key-123456'),
      devtoolsApiProvider.overrideWithValue(_FakeDevtoolsApi()),
      devtoolsSignedInUidProvider.overrideWithValue(null),
      devtoolsHealthProvider.overrideWith(
        (ref) async => DevtoolsHealth(
          enabled: true,
          serverTime: DateTime.utc(2026, 10, 17, 13),
          offsetSeconds: 90000,
        ),
      ),
    ],
    child: MaterialApp(
      navigatorKey: devtoolsNavigatorKey,
      builder: (context, child) => DevOverlay(clock: clock, child: child!),
      home: home ?? const Scaffold(body: Text('home')),
      routes: {devMenuRoute: (context) => DevMenuScreen.fromRoute(context)},
    ),
  );
}

void main() {
  late ServerClock clock;

  setUp(() => clock = ServerClock());

  testWidgets('is hidden at zero offset', (tester) async {
    await tester.pumpWidget(_app(clock));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeShiftedBanner')), findsNothing);
    expect(find.textContaining('TIME SHIFTED'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('shows +1d 1h at 90000 seconds', (tester) async {
    _respond(clock, offsetSeconds: 90000);
    await tester.pumpWidget(_app(clock));
    await tester.pumpAndSettle();

    expect(find.text('TIME SHIFTED +1d 1h'), findsOneWidget);
  });

  testWidgets('appears and disappears as responses change the offset, '
      'keeping the current screen', (tester) async {
    await tester.pumpWidget(_app(clock));
    await tester.pumpAndSettle();
    devtoolsNavigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('second screen')),
      ),
    );
    await tester.pumpAndSettle();

    _respond(clock, offsetSeconds: 6 * 3600);
    await tester.pump();
    expect(find.text('TIME SHIFTED +6h'), findsOneWidget);
    expect(find.text('second screen'), findsOneWidget);

    _respond(clock);
    await tester.pump();
    expect(find.textContaining('TIME SHIFTED'), findsNothing);
    expect(find.text('second screen'), findsOneWidget);
  });

  testWidgets('tap opens the dev menu on the Time tab', (tester) async {
    _respond(clock, offsetSeconds: 90000);
    await tester.pumpWidget(_app(clock));
    await tester.pumpAndSettle();

    await tester.tap(find.text('TIME SHIFTED +1d 1h'));
    await tester.pumpAndSettle();

    expect(find.byType(DevMenuScreen), findsOneWidget);
    expect(find.byType(TimeTab), findsOneWidget);
    expect(find.byType(PersonasTab), findsNothing);
    // Still visible over the dev menu.
    expect(find.text('TIME SHIFTED +1d 1h'), findsOneWidget);
  });

  testWidgets('takes the status bar inset so the app is laid out below it', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 60);
    addTearDown(tester.view.resetPadding);
    _respond(clock, offsetSeconds: 3600);

    late EdgeInsets appPadding;
    await tester.pumpWidget(
      _app(
        clock,
        home: Builder(
          builder: (context) {
            appPadding = MediaQuery.paddingOf(context);
            return const Scaffold(body: Text('home'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bannerBottom = tester
        .getBottomLeft(find.byKey(const Key('timeShiftedBanner')))
        .dy;
    expect(bannerBottom, greaterThan(60 / tester.view.devicePixelRatio));
    expect(appPadding.top, 0);
    expect(
      tester.getTopLeft(find.text('home')).dy,
      greaterThanOrEqualTo(bannerBottom),
    );
  });
}
