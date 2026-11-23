import 'dart:convert';
import 'dart:io';

import 'package:eros_app/features/legal/presentation/screens/reconsent_screen.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_copy.dart';
import 'package:eros_app/features/legal/presentation/widgets/reconsent_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../legal_test_support.dart';

const _mePath = '/users/me';

Map<String, dynamic> _me({List<String>? outstanding}) {
  final json = jsonDecode(File('test/fixtures/users/get_users_me.json').readAsStringSync())
      as Map<String, dynamic>;
  if (outstanding != null) json['outstandingConsents'] = outstanding;
  return json;
}

Map<String, dynamic> _consentState() => {'consents': [], 'outstanding': []};

StubHttp _http({required List<String> outstanding}) => StubHttp()
  ..responses['GET $_mePath'] = reply(200, _me(outstanding: outstanding))
  ..responses['GET $citiesPath'] = reply(200, cities)
  ..responses['GET $documentsPath'] = reply(200, londonDocuments)
  ..responses['POST $consentsPath'] = reply(200, _consentState());

Future<void> _pump(WidgetTester tester, StubHttp http) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: legalOverrides(http),
    child: const MaterialApp(home: ReconsentGate(child: Scaffold(body: Text('Home')))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows nothing when nothing is outstanding', (tester) async {
    await _pump(tester, _http(outstanding: const []));

    expect(find.byType(ReconsentScreen), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('lists what changed for the user\'s region, and back can\'t dismiss it',
      (tester) async {
    final http = _http(outstanding: const ['TERMS', 'PRIVACY_NOTICE']);
    await _pump(tester, http);

    expect(find.byType(ReconsentScreen), findsOneWidget);
    expect(find.text('Terms of use'), findsOneWidget);
    expect(find.text('Privacy notice'), findsOneWidget);
    expect(documentCityIds(http), ['$londonId']);
    expect(find.byType(BackButton), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ReconsentScreen), findsOneWidget);
    expect(find.text(LegalCopy.signOut), findsOneWidget);
  });

  testWidgets('accepting posts the versions shown as REPROMPT, refetches, and clears',
      (tester) async {
    final http = _http(outstanding: const ['TERMS', 'PRIVACY_NOTICE']);
    await _pump(tester, http);

    http.responses['GET $_mePath'] = reply(200, _me(outstanding: const []));
    await tester.tap(find.text(LegalCopy.acceptAndContinue));
    await tester.pumpAndSettle();

    final posted = http.sent('POST', consentsPath);
    expect(posted, hasLength(1));
    expect(posted.single.data, {
      'consents': [
        {'kind': 'TERMS', 'version': 'uk-3', 'granted': true},
        {'kind': 'PRIVACY_NOTICE', 'version': 'uk-2', 'granted': true},
      ],
      'source': 'REPROMPT',
    });
    expect(http.sent('GET', _mePath), hasLength(2));
    expect(find.byType(ReconsentScreen), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('stays up when the server still has something outstanding', (tester) async {
    final http = _http(outstanding: const ['TERMS']);
    await _pump(tester, http);

    http.responses['GET $_mePath'] = reply(200, _me(outstanding: const ['SAFETY_NOTICE']));
    await tester.tap(find.text(LegalCopy.acceptAndContinue));
    await tester.pumpAndSettle();

    expect(find.byType(ReconsentScreen), findsOneWidget);
    expect(find.text('Safety notice'), findsOneWidget);
  });

  testWidgets('a stale version reloads the documents and says so', (tester) async {
    final http = _http(outstanding: const ['TERMS']);
    await _pump(tester, http);

    http.responses['POST $consentsPath'] = reply(400, {
      'error': 'CONSENT_VERSION_STALE',
      'message': 'Newer',
      'kinds': ['TERMS'],
    });
    await tester.tap(find.text(LegalCopy.acceptAndContinue));
    await tester.pumpAndSettle();

    expect(find.byType(ReconsentScreen), findsOneWidget);
    expect(find.text(LegalCopy.reconsentStale), findsOneWidget);
    expect(http.sent('GET', documentsPath), hasLength(2));
  });
}
