import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/notifications/push_host.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/verification/data/selfie_camera.dart';
import 'package:eros_app/features/verification/data/selfie_processor.dart';
import 'package:eros_app/features/verification/presentation/verification_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_selfie_capture.dart';
import '../fake_verification_http.dart';

/// The overrides VF-F3's widgets need: a signed-in [uid], the real repository over [http], local
/// storage and the flow's fakes, so a Verify now tap can open the flow without a camera.
List<Override> verificationOverrides({
  required StubHttp http,
  required SharedPreferences prefs,
  FakeVerificationLinks? links,
  String uid = 'dev_alice',
}) =>
    [
      signedInUidProvider.overrideWith((ref) => uid),
      apiClientProvider.overrideWith((ref) => apiClientOver(http)),
      sharedPreferencesProvider.overrideWithValue(prefs),
      selfieCameraFactoryProvider.overrideWithValue(FakeCameraRig().create),
      selfieProcessorProvider.overrideWithValue(FakeSelfieProcessor()),
      verificationLinksProvider.overrideWithValue(links ?? FakeVerificationLinks()),
    ];

/// Pumps [home] in a freshly started app with [verificationOverrides].
Future<void> pumpVerificationApp(
  WidgetTester tester, {
  required StubHttp http,
  required SharedPreferences prefs,
  required Widget home,
  FakeVerificationLinks? links,
  String uid = 'dev_alice',
}) async {
  tester.view.physicalSize = const Size(600, 1300);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      // Each pump is a fresh start of the app: new providers, the same device storage.
      key: UniqueKey(),
      overrides: verificationOverrides(http: http, prefs: prefs, links: links, uid: uid),
      child: MaterialApp(home: home),
    ),
  );
  await settle(tester);
}

/// Lets the stubbed requests and the screens' futures finish. Never `pumpAndSettle`: the
/// progress indicators never settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// `GET /users/me/verification` requests sent so far.
int statusFetches(StubHttp http) => http.sent('GET', statusPath).length;
