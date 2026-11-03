import 'dart:async';

import 'package:eros_app/core/auth/sign_out_service.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/notifications/push_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notifications/fake_messaging.dart';

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth(this.log);

  final List<String> log;

  @override
  Future<void> signOut() async => log.add('firebaseSignOut');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingPushService implements PushService {
  @override
  Future<void> removeToken() async => throw StateError('boom');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late List<String> log;
  late FakeMessagingClient messaging;
  late FakeDevicesApi api;
  late PushService push;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    log = [];
    messaging = FakeMessagingClient()..log = log;
    api = FakeDevicesApi(log: log);
    push = PushService(messaging: messaging, apiClient: () => api, platform: 'ANDROID');
    await push.userChanged('alice');
    log.clear();
  });

  SignOutService service(PushService? pushService) => SignOutService(
        firebaseAuth: _FakeFirebaseAuth(log),
        sharedPrefs: prefs,
        pushService: pushService,
      );

  test('removes the push token before Firebase sign-out', () async {
    await service(push).signOut();

    expect(log, ['POST /users/me/devices/remove', 'deleteToken', 'firebaseSignOut']);
  });

  test('a failed removal does not stop sign-out', () async {
    api.error = UnauthorizedException('expired');

    await service(push).signOut();

    expect(log.last, 'firebaseSignOut');
  });

  test('a removal that throws does not stop sign-out', () async {
    await service(_ThrowingPushService()).signOut();

    expect(log, ['firebaseSignOut']);
  });

  testWidgets('a removal that hangs is cut off, then sign-out goes ahead', (tester) async {
    api.gate = Completer<void>();
    var done = false;
    unawaited(service(push).signOut().then((_) => done = true));

    await tester.pump(const Duration(seconds: 4));
    expect(done, isFalse);
    await tester.pump(SignOutService.pushRemovalTimeout);
    expect(done, isTrue);
    expect(log.last, 'firebaseSignOut');
  });

  test('works without a push service', () async {
    await service(null).signOut();

    expect(log, ['firebaseSignOut']);
  });
}
