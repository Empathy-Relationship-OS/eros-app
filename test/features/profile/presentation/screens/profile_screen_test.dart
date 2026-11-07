import 'dart:async';

import 'package:eros_app/features/match_preferences/data/match_preferences_repository.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preferences_banner_providers.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/match_preferences_screen.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/user_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../match_preferences/fake_match_preferences_api.dart';

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

void main() {
  testWidgets('opens Match preferences from the row above Date preferences', (tester) async {
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
      ],
      child: const MaterialApp(home: ProfileScreen()),
    ));
    await tester.pump();

    final match = tester.getTopLeft(find.text('Match preferences'));
    final date = tester.getTopLeft(find.text('Date preferences'));
    expect(match.dy, lessThan(date.dy));

    await tester.tap(find.text('Match preferences'));
    await tester.pumpAndSettle();

    expect(find.byType(MatchPreferencesScreen), findsOneWidget);
    expect(find.text('Interested in'), findsOneWidget);
  });
}
