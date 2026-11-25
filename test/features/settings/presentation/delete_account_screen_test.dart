import 'dart:async';

import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/theme/app_theme.dart';
import 'package:eros_app/features/auth/data/repositories/auth_repository.dart';
import 'package:eros_app/features/auth/domain/models/delete_account_result.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/data/repositories/dates_repository.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_repository_provider.dart';
import 'package:eros_app/features/legal/data/support_email.dart';
import 'package:eros_app/features/profile/domain/models/my_profile.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';
import 'package:eros_app/features/settings/domain/models/app_settings.dart';
import 'package:eros_app/features/settings/presentation/providers/app_settings_provider.dart';
import 'package:eros_app/features/settings/presentation/screens/app_settings_screen.dart';
import 'package:eros_app/features/settings/presentation/screens/delete_account_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUser implements User {
  @override
  String get uid => 'uid-123';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Signed in; [deleteAccount] answers [result] and never touches Firebase.
class _FakeAuthRepository implements AuthRepository {
  DeleteAccountResult result =
      const DeleteAccountResult.deleted(appleRevoked: true, signedOut: true);
  int deletions = 0;

  @override
  User? get currentUser => _FakeUser();

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<DeleteAccountResult> deleteAccount() async {
    deletions++;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDate implements DateSummary {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `GET /dates?filter=...`: answers [answer] and records each filter asked for.
class _FakeDatesRepository implements DatesRepository {
  Future<List<DateSummary>> Function() answer = () async => [];
  final filters = <DateListFilter?>[];

  @override
  Future<List<DateSummary>> fetchDates({DateListFilter? filter}) {
    filters.add(filter);
    return answer();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLinks implements LegalLinks {
  final documents = <Uri>[];

  @override
  Future<bool> openDocument(Uri url) async {
    documents.add(url);
    return true;
  }

  @override
  Future<bool> openEmail(Uri email) async => true;
}

class _FakeAppSettings extends AppSettingsNotifier {
  @override
  Future<AppSettingsState> build() async =>
      AppSettingsState(settings: AppSettings.defaultSettings());
}

/// The phone number tile's profile, which never arrives: not what these tests are about.
class _PendingProfile extends MyProfileNotifier {
  @override
  Future<MyProfile> build() => Completer<MyProfile>().future;
}

const _welcome = 'WELCOME SCREEN';
const _start = 'START';

class _Harness {
  final auth = _FakeAuthRepository();
  final dates = _FakeDatesRepository();
  final links = _FakeLinks();

  /// Opens [screen] from a plain screen, so popping has somewhere to go.
  Future<void> pump(WidgetTester tester, {Widget screen = const DeleteAccountScreen()}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => AuthStateNotifier(auth)),
        datesRepositoryProvider.overrideWithValue(dates),
        legalLinksProvider.overrideWithValue(links),
        appSettingsProvider.overrideWith(_FakeAppSettings.new),
        myProfileProvider.overrideWith(_PendingProfile.new),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => screen),
              ),
              child: const Text(_start),
            ),
          ),
        ),
        routes: {'/welcome': (_) => const Scaffold(body: Text(_welcome))},
      ),
    ));
    await tester.tap(find.text(_start));
    await settle(tester);
  }
}

/// Never `pumpAndSettle`: spinners never settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

final _deleteButton = find.byKey(const ValueKey('delete-account-confirm'));

void main() {
  group('App Settings', () {
    testWidgets('has Delete account in an Account section, opening the Delete account screen',
        (tester) async {
      final h = _Harness();
      await h.pump(tester, screen: const AppSettingsScreen());

      final entry = find.byKey(const ValueKey('settings-delete-account'));
      await tester.scrollUntilVisible(entry, 200);
      expect(entry, findsOneWidget);

      await tester.tap(entry);
      await settle(tester);

      expect(find.byType(DeleteAccountScreen), findsOneWidget);
      expect(h.auth.deletions, 0);
    });
  });

  group('before deleting', () {
    testWidgets('checks for active dates, then asks to confirm', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      expect(h.dates.filters, [DateListFilter.active]);
      expect(find.text(DeleteAccountCopy.confirmTitle), findsOneWidget);
      expect(find.text(DeleteAccountCopy.confirmBody), findsOneWidget);
      expect(_deleteButton, findsOneWidget);
    });

    testWidgets('Cancel goes back and deletes nothing', (tester) async {
      final h = _Harness();
      await h.pump(tester);

      await tester.tap(find.byKey(const ValueKey('delete-account-cancel')));
      await settle(tester);

      expect(find.byType(DeleteAccountScreen), findsNothing);
      expect(find.text(_start), findsOneWidget);
      expect(h.auth.deletions, 0);
    });

    testWidgets('an active date shows the message and the dates link instead of the button',
        (tester) async {
      final h = _Harness()..dates.answer = () async => [_FakeDate()];
      await h.pump(tester);

      expect(find.text(DeleteAccountCopy.activeDate), findsOneWidget);
      expect(find.text(DeleteAccountCopy.goToDates), findsOneWidget);
      expect(_deleteButton, findsNothing);
    });

    testWidgets('a failed dates check says so, offers no deletion, and can try again',
        (tester) async {
      final h = _Harness()..dates.answer = () async => throw const NetworkException('offline');
      await h.pump(tester);

      expect(find.text(DeleteAccountCopy.datesCheckFailed), findsOneWidget);
      expect(_deleteButton, findsNothing);

      h.dates.answer = () async => [];
      await tester.tap(find.text(DeleteAccountCopy.tryAgain));
      await settle(tester);

      expect(h.dates.filters, [DateListFilter.active, DateListFilter.active]);
      expect(_deleteButton, findsOneWidget);
    });
  });

  group('deleting', () {
    testWidgets('ends on the welcome screen with "Your account has been deleted."',
        (tester) async {
      final h = _Harness();
      await h.pump(tester);

      await tester.tap(_deleteButton);
      await settle(tester);

      expect(h.auth.deletions, 1);
      expect(find.text(_welcome), findsOneWidget);
      expect(find.text(DeleteAccountCopy.deleted), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-account-apple-step')), findsNothing);
    });

    testWidgets('without Apple revocation, the welcome screen shows the Apple step instead',
        (tester) async {
      final h = _Harness()
        ..auth.result = const DeleteAccountResult.deleted(appleRevoked: false, signedOut: true);
      await h.pump(tester);

      await tester.tap(_deleteButton);
      await settle(tester);

      expect(find.text(_welcome), findsOneWidget);
      expect(find.text(DeleteAccountCopy.appleStepBody), findsOneWidget);
      expect(find.text(DeleteAccountCopy.deleted), findsNothing);

      await tester.tap(find.text(DeleteAccountCopy.appleStepLink));
      await settle(tester);
      expect(h.links.documents, [Uri.parse('https://support.apple.com/en-us/102571')]);

      await tester.tap(find.text(DeleteAccountCopy.ok));
      await settle(tester);
      expect(find.text(DeleteAccountCopy.appleStepBody), findsNothing);
    });

    testWidgets('a failed delete stays on the screen, says so, and can be tried again',
        (tester) async {
      final h = _Harness()
        ..auth.result = const DeleteAccountResult.failure(deleteAccountFailedMessage);
      await h.pump(tester);

      await tester.tap(_deleteButton);
      await settle(tester);

      expect(find.text(deleteAccountFailedMessage), findsOneWidget);
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
      expect(find.text(_welcome), findsNothing);
      expect(tester.widget<ElevatedButton>(
        find.descendant(of: _deleteButton, matching: find.byType(ElevatedButton)),
      ).onPressed, isNotNull);
    });
  });
}
