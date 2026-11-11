import 'dart:async';

import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/notifications/push_host.dart';
import 'package:eros_app/features/match_preferences/data/match_preferences_repository.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preferences_banner_providers.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/match_preferences_screen.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:eros_app/features/verification/presentation/screens/verification_status_screen.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../match_preferences/fake_match_preferences_api.dart';
import '../../../verification/fake_verification_http.dart';

/// Never answers, so the profile stays whatever the notifier below sets.
class _PendingProfileRepository implements ProfileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Completer<Never>().future;
}

/// A loaded Profile tab with no profile photo or name.
class _LoadedProfileNotifier extends UserProfileNotifier {
  _LoadedProfileNotifier() : super(profileRepository: _PendingProfileRepository(), userId: 'alice') {
    state = const UserProfileState();
  }
}

/// The Profile tab with a loaded profile, its verification status from [http].
Future<void> _pumpProfile(WidgetTester tester, StubHttp http) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final api = FakeMatchPreferencesApi(responses: {
    'GET /users/me/match-preferences': mpFixture('get_users_me_match_preferences') as Object,
    'GET /match-preferences/options': mpFixture('get_match_preferences_options') as Object,
  });

  await tester.pumpWidget(ProviderScope(
    overrides: [
      userProfileProvider.overrideWith((ref) => _LoadedProfileNotifier()),
      sharedPreferencesProvider.overrideWithValue(prefs),
      matchPreferencesBannerUidProvider.overrideWithValue('alice'),
      matchPreferencesRepositoryProvider.overrideWithValue(
        MatchPreferencesRepository(apiClient: api, logger: Logger(level: Level.off)),
      ),
      // The Verify your profile row (RFC-008 VF-F3).
      signedInUidProvider.overrideWith((ref) => 'alice'),
      apiClientProvider.overrideWith((ref) => apiClientOver(http)),
    ],
    child: const MaterialApp(home: ProfileScreen()),
  ));
  await tester.pump();
}

void main() {
  testWidgets('opens Match preferences from the row above Date preferences', (tester) async {
    final http = StubHttp()..responses['GET $statusPath'] = reply(200, statusJson('NOT_VERIFIED'));
    await _pumpProfile(tester, http);

    final match = tester.getTopLeft(find.text('Match preferences'));
    final date = tester.getTopLeft(find.text('Date preferences'));
    expect(match.dy, lessThan(date.dy));

    await tester.tap(find.text('Match preferences'));
    await tester.pumpAndSettle();

    expect(find.byType(MatchPreferencesScreen), findsOneWidget);
    expect(find.text('Interested in'), findsOneWidget);
  });

  testWidgets('Verify your profile sits first, with its hint, and opens the status screen',
      (tester) async {
    final http = StubHttp()
      ..responses['GET $statusPath'] = reply(200, statusJson('RETRY', reason: 'UNCLEAR'));
    await _pumpProfile(tester, http);
    await tester.pump(const Duration(milliseconds: 100));

    final verify = tester.getTopLeft(find.text(VerificationCopy.verifyYourProfile));
    final edit = tester.getTopLeft(find.text('Edit profile'));
    expect(verify.dy, lessThan(edit.dy));
    expect(find.text('Action needed'), findsOneWidget);

    await tester.tap(find.text(VerificationCopy.verifyYourProfile));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(VerificationStatusScreen), findsOneWidget);
  });
}
