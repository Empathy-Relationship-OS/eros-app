import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/devtools/data/devtools_api.dart';
import 'package:eros_app/features/devtools/data/devtools_exceptions.dart';
import 'package:eros_app/features/devtools/data/models/devtools_models.dart';
import 'package:eros_app/features/devtools/presentation/dev_menu_navigation.dart';
import 'package:eros_app/features/devtools/presentation/dev_menu_screen.dart';
import 'package:eros_app/features/devtools/presentation/providers/devtools_providers.dart';
import 'package:eros_app/features/devtools/presentation/providers/personas_providers.dart';
import 'package:eros_app/features/devtools/presentation/providers/scenarios_providers.dart';
import 'package:eros_app/features/devtools/presentation/tabs/personas_tab.dart';
import 'package:eros_app/features/devtools/presentation/tabs/scenarios_tab.dart';
import 'package:eros_app/features/devtools/presentation/tabs/time_tab.dart';
import 'package:eros_app/features/devtools/presentation/widgets/dev_menu_button.dart';

final _healthOn = DevtoolsHealth(
  enabled: true,
  serverTime: DateTime.utc(2026, 10, 17, 13),
  offsetSeconds: 90000,
);

List<Override> _overrides({
  String key = 'test-dev-key-123456',
  String? uid,
  Future<DevtoolsHealth> Function()? health,
}) =>
    [
      devtoolsKeyProvider.overrideWithValue(key),
      devtoolsSignedInUidProvider.overrideWithValue(uid),
      devtoolsHealthProvider.overrideWith((ref) => (health ?? () async => _healthOn)()),
      // PersonasTab (DT-F3): no backend, no SharedPreferences.
      devtoolsPersonasProvider.overrideWith((ref) async => const <Persona>[]),
      recentPersonaUidsProvider.overrideWith((ref) => const <String>[]),
      // ScenariosTab (DT-F5): no backend.
      devtoolsScenariosProvider.overrideWith(
        (ref) async => const <ScenarioInfo>[],
      ),
    ];

Widget _app({required List<Override> overrides, Widget home = const DevMenuScreen()}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      navigatorKey: devtoolsNavigatorKey,
      builder: (context, child) => DevOverlay(child: child!),
      home: home,
      routes: {devMenuRoute: (context) => DevMenuScreen.fromRoute(context)},
    ),
  );
}

void main() {
  group('DevMenuScreen header', () {
    testWidgets('shows devtools on, server time, offset and the signed-in uid',
        (tester) async {
      await tester.pumpWidget(_app(overrides: _overrides(uid: 'dev_alice')));
      await tester.pumpAndSettle();

      expect(find.text('Devtools on'), findsOneWidget);
      expect(find.text('Server time: Sat 17 Oct 13:00:00 UTC'), findsOneWidget);
      expect(find.text('Clock offset: +1d 1h 0m'), findsOneWidget);
      expect(find.text('Signed in as dev_alice'), findsOneWidget);
    });

    testWidgets('shows signed out when nobody is signed in', (tester) async {
      await tester.pumpWidget(_app(overrides: _overrides()));
      await tester.pumpAndSettle();

      expect(find.text('Signed out'), findsOneWidget);
    });

    testWidgets('shows devtools off when the backend has them disabled',
        (tester) async {
      await tester.pumpWidget(_app(
        overrides: _overrides(
          health: () async => throw const DevtoolsDisabledException(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Devtools off'), findsOneWidget);
    });

    testWidgets('shows backend unreachable on a network error', (tester) async {
      await tester.pumpWidget(_app(
        overrides: _overrides(
          health: () async => throw const NetworkException('Cannot reach the backend'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Backend unreachable'), findsOneWidget);
      expect(find.text('Cannot reach the backend'), findsOneWidget);
    });
  });

  group('DevMenuScreen tabs', () {
    testWidgets('has Personas, Time and Scenarios tabs, Personas first',
        (tester) async {
      await tester.pumpWidget(_app(overrides: _overrides()));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Tab, 'Personas'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Time'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Scenarios'), findsOneWidget);
      expect(find.byType(PersonasTab), findsOneWidget);

      await tester.tap(find.widgetWithText(Tab, 'Scenarios'));
      await tester.pumpAndSettle();
      expect(find.byType(ScenariosTab), findsOneWidget);
    });

    testWidgets('openDevMenu opens on the requested tab', (tester) async {
      await tester.pumpWidget(
        _app(overrides: _overrides(), home: const Scaffold(body: Text('home'))),
      );
      await tester.pumpAndSettle();

      openDevMenu(tab: DevMenuTab.time);
      await tester.pumpAndSettle();

      expect(find.byType(DevMenuScreen), findsOneWidget);
      expect(find.byType(TimeTab), findsOneWidget);
      expect(find.byType(PersonasTab), findsNothing);
    });

    testWidgets('openDevMenu while the menu is open replaces it, not stacks',
        (tester) async {
      await tester.pumpWidget(
        _app(overrides: _overrides(), home: const Scaffold(body: Text('home'))),
      );
      await tester.pumpAndSettle();

      openDevMenu(tab: DevMenuTab.scenarios);
      await tester.pumpAndSettle();
      expect(find.byType(ScenariosTab), findsOneWidget);

      // For example the "time shifted" banner tapped over the open menu.
      openDevMenu(tab: DevMenuTab.time);
      await tester.pumpAndSettle();

      expect(find.byType(DevMenuScreen), findsOneWidget);
      expect(find.byType(TimeTab), findsOneWidget);

      // One pop closes the menu: there was only one copy.
      devtoolsNavigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(DevMenuScreen), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('DevMenuScreen without DEVTOOLS_KEY', () {
    testWidgets('shows the missing key message instead of the tabs',
        (tester) async {
      var healthCalls = 0;
      await tester.pumpWidget(_app(
        overrides: _overrides(
          key: '',
          health: () async {
            healthCalls++;
            return _healthOn;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('DEVTOOLS_KEY not set'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      expect(healthCalls, 0);
    });
  });

  group('DEV button overlay', () {
    testWidgets('opens the dev menu while signed out', (tester) async {
      await tester.pumpWidget(
        _app(overrides: _overrides(), home: const Scaffold(body: Text('home'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('DEV'), findsOneWidget);

      await tester.tap(find.text('DEV'));
      await tester.pumpAndSettle();

      expect(find.byType(DevMenuScreen), findsOneWidget);
      expect(find.byType(PersonasTab), findsOneWidget);
      expect(find.text('Signed out'), findsOneWidget);
      // Still overlaid on the dev menu itself.
      expect(find.text('DEV'), findsOneWidget);
    });

    testWidgets('can be dragged', (tester) async {
      await tester.pumpWidget(
        _app(overrides: _overrides(), home: const Scaffold(body: Text('home'))),
      );
      await tester.pumpAndSettle();

      final before = tester.getTopLeft(find.text('DEV'));
      await tester.drag(find.text('DEV'), const Offset(-100, 120));
      await tester.pumpAndSettle();
      final after = tester.getTopLeft(find.text('DEV'));

      expect(after.dx, lessThan(before.dx));
      expect(after.dy, greaterThan(before.dy));
      expect(find.byType(DevMenuScreen), findsNothing);
    });
  });

  group('formatOffset', () {
    test('formats zero, hours and days', () {
      expect(formatOffset(Duration.zero), 'none');
      expect(formatOffset(const Duration(hours: 2, minutes: 30)), '+2h 30m');
      expect(formatOffset(const Duration(seconds: 90000)), '+1d 1h 0m');
    });
  });

  test('ApiException types still apply to devtools errors', () {
    expect(const DevtoolsDisabledException(), isA<ApiException>());
    expect(const DevtoolsKeyMissingException(), isA<UnauthorizedException>());
  });
}
