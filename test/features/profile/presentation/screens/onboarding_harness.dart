import 'dart:convert';

import 'package:eros_app/features/profile/domain/models/profile_creation_draft.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps an onboarding screen against a draft (empty unless [pump] is given one), recording the
/// routes it pushes. A tall viewport means every option is built without scrolling.
class OnboardingHarness {
  late final ProviderContainer container;
  final pushed = <String?>[];

  ProfileCreationDraft get draft => container.read(profileCreationProvider);

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    ProfileCreationDraft? initialDraft,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      if (initialDraft != null) 'profile_creation_draft': jsonEncode(initialDraft.toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs), ...overrides],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: screen,
        onGenerateRoute: (settings) {
          pushed.add(settings.name);
          return MaterialPageRoute(builder: (_) => const Scaffold());
        },
      ),
    ));
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }
}
