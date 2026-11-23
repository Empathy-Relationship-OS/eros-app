import 'package:eros_app/core/auth/sign_out_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth(this.log);

  final List<String> log;

  @override
  Future<void> signOut() async => log.add('firebaseSignOut');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGoogleSignIn implements GoogleSignIn {
  _FakeGoogleSignIn(this.log, {this.fails = false});

  final List<String> log;
  final bool fails;

  @override
  Future<void> signOut() async {
    log.add('googleSignOut');
    if (fails) throw StateError('not initialized');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late List<String> log;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    log = [];
  });

  test('signs out of Google too, so the next Google sign-in shows the account picker', () async {
    await SignOutService(
      firebaseAuth: _FakeFirebaseAuth(log),
      sharedPrefs: prefs,
      googleSignIn: _FakeGoogleSignIn(log),
    ).signOut();

    expect(log, ['googleSignOut', 'firebaseSignOut']);
  });

  test('a failed Google sign-out still signs out of Firebase', () async {
    await SignOutService(
      firebaseAuth: _FakeFirebaseAuth(log),
      sharedPrefs: prefs,
      googleSignIn: _FakeGoogleSignIn(log, fails: true),
    ).signOut();

    expect(log, ['googleSignOut', 'firebaseSignOut']);
  });
}
