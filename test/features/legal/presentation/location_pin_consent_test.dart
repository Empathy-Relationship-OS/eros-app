import 'dart:convert';
import 'dart:io';

import 'package:eros_app/features/legal/presentation/widgets/legal_copy.dart';
import 'package:eros_app/features/legal/presentation/widgets/location_pin_consent_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../legal_test_support.dart';

Map<String, dynamic> _consents({bool? pinGranted}) => {
      'consents': [
        if (pinGranted != null)
          {'kind': 'LOCATION_PIN', 'version': 'uk-1', 'granted': pinGranted, 'at': '2026-11-02T10:00:00Z'},
      ],
      'outstanding': [],
    };

StubHttp _http({bool? pinGranted}) => StubHttp()
  ..responses['GET /users/me'] = reply(
      200, jsonDecode(File('test/fixtures/users/get_users_me.json').readAsStringSync()))
  ..responses['GET $citiesPath'] = reply(200, cities)
  ..responses['GET $documentsPath'] = reply(200, londonDocuments)
  ..responses['GET $consentsPath'] = reply(200, _consents(pinGranted: pinGranted))
  ..responses['POST $consentsPath'] = reply(200, _consents(pinGranted: true));

/// Pumps a button that runs [ensureLocationPinConsent] and keeps what it answered.
Future<List<bool>> _pump(WidgetTester tester, StubHttp http) async {
  final answers = <bool>[];
  await tester.pumpWidget(ProviderScope(
    overrides: legalOverrides(http),
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) => Scaffold(
          body: TextButton(
            onPressed: () async => answers.add(await ensureLocationPinConsent(context, ref)),
            child: const Text('Set pin'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Set pin'));
  await tester.pumpAndSettle();
  return answers;
}

void main() {
  testWidgets('asks nothing when the pin consent is already granted', (tester) async {
    final answers = await _pump(tester, _http(pinGranted: true));

    expect(find.text(LegalCopy.pinTitle), findsNothing);
    expect(answers, [true]);
  });

  testWidgets('asks the first time; Allow records LOCATION_PIN on the region\'s version',
      (tester) async {
    final http = _http();
    final answers = await _pump(tester, http);

    expect(find.text(LegalCopy.pinTitle), findsOneWidget);
    await tester.tap(find.byKey(const Key('pin-allow')));
    await tester.pumpAndSettle();

    expect(answers, [true]);
    expect(http.sent('POST', consentsPath).single.data, {
      'consents': [
        {'kind': 'LOCATION_PIN', 'version': 'uk-1', 'granted': true},
      ],
      'source': 'SETTINGS',
    });
  });

  testWidgets('Not now records nothing and keeps the pin off', (tester) async {
    final http = _http(pinGranted: false);
    final answers = await _pump(tester, http);

    await tester.tap(find.byKey(const Key('pin-not-now')));
    await tester.pumpAndSettle();

    expect(answers, [false]);
    expect(http.sent('POST', consentsPath), isEmpty);
  });
}
