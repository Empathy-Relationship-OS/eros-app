import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/notifications/push_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../safety/fake_safety_api.dart';

/// Test support for the verification wall on a date (VF-F4): real repositories over
/// [FakeSafetyApi], which answers `'METHOD path'` and throws a stubbed [ApiException].

const String statusRequest = 'GET /users/me/verification';
const String dateRequest = 'GET /dates/7';

/// The 403 body every gated action answers with (RFC-008 §5.3).
const verificationRequiredError =
    VerificationRequiredFailure('Verify it\'s you to continue with this date');

/// `GET /users/me/verification` in [state].
Map<String, dynamic> statusJson(String state, {String? reason}) => {
      'state': state,
      'reason': ?reason,
      'attemptsLeftToday': 3,
      'canStart': state == 'NOT_VERIFIED' || state == 'RETRY',
      'consentVersion': '2026-11-01',
    };

/// `GET /dates/7` in [state], with the viewer (user1) still to act on it.
///
/// [verificationRequired] null leaves the field out, as a backend without VF-B5 does.
Map<String, dynamic> wallDateJson(
  String state, {
  bool? verificationRequired = true,
  String? depositDeadline,
  String? rankingDeadline,
}) =>
    {
      ...dateDetailJson(state: state),
      'depositStatus': {'user1': 'PENDING', 'user2': 'PENDING'},
      'depositDeadline': depositDeadline,
      'rankingDeadline': rankingDeadline,
      'verificationRequired': ?verificationRequired,
    };

/// A [FakeSafetyApi] with the date in [date] and the viewer's verification [status].
FakeSafetyApi wallApi({
  required Map<String, dynamic> date,
  Map<String, dynamic>? status,
}) =>
    FakeSafetyApi()
      ..responses[dateRequest] = date
      ..responses[statusRequest] = status ?? statusJson('NOT_VERIFIED')
      ..responses['GET /wallet/balance'] = {
        'balance': 20,
        'pendingBalance': 0,
        'lifetimeSpent': 0,
        'lifetimePurchased': 20,
        'currency': 'TOKEN',
      }
      ..responses['GET /dates/7/presence-status'] = {
        'dateId': 7,
        'user1': {'userId': 'user1', 'confirmed': false},
        'user2': {'userId': 'user2', 'confirmed': false},
      }
      ..responses['GET /dates/7/venue-options'] = {
        'dateId': 7,
        'options': [
          {
            'venueId': 1,
            'name': 'The Ivy',
            'address': '1 West St',
            'optionOrder': 1,
            'priceRange': {'value': 'PREMIUM', 'symbol': '£££'},
          },
          {
            'venueId': 2,
            'name': 'Bao',
            'address': '2 Lexington St',
            'optionOrder': 2,
            'priceRange': {'value': 'BUDGET', 'symbol': '£'},
          },
        ],
        'myRankings': <Object>[],
      };

List<Override> wallOverrides(FakeSafetyApi api) => [
      authServiceProvider.overrideWithValue(FakeAuthService()),
      apiClientProvider.overrideWithValue(api),
      signedInUidProvider.overrideWithValue('user1'),
    ];

/// Tall enough for the date screen's bottom panel, the sheets and the dialogs.
void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> pumpWall(WidgetTester tester, FakeSafetyApi api, Widget home) async {
  tallScreen(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: wallOverrides(api),
    child: MaterialApp(home: home),
  ));
  await tester.pumpAndSettle();
}

/// The provider container behind the screen [finder] finds.
ProviderContainer containerOf(WidgetTester tester, Finder finder) =>
    ProviderScope.containerOf(tester.element(finder));

int count(FakeSafetyApi api, String request) =>
    api.requests.where((r) => '${r.method} ${r.path}' == request).length;
