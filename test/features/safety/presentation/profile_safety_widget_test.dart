import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/screens/date_detail_screen.dart';
import 'package:eros_app/features/dates/presentation/widgets/cancel_date_dialog.dart';
import 'package:eros_app/features/matching/data/repositories/match_repository.dart';
import 'package:eros_app/features/matching/domain/models/match_models.dart';
import 'package:eros_app/features/matching/presentation/providers/match_provider.dart';
import 'package:eros_app/features/matching/presentation/screens/public_profile_view_screen.dart';
import 'package:eros_app/features/matching/presentation/widgets/match_carousel_v2.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/domain/models/public_profile.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_display_components.dart';
import 'package:eros_app/features/safety/presentation/profile_safety_flow.dart';
import 'package:eros_app/features/safety/presentation/providers/report_provider.dart';
import 'package:eros_app/features/safety/presentation/screens/report_sheet.dart';
import 'package:eros_app/features/safety/presentation/widgets/safety_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_safety_api.dart';

/// Answers `GET /match/` with each batch in turn, then the last one again.
class _FakeMatchRepository implements MatchRepository {
  _FakeMatchRepository(this.batches);

  final List<List<UserMatchProfile>> batches;
  int fetches = 0;

  @override
  Future<DailyBatchResponse?> fetchDailyBatch() async {
    final profiles = batches[fetches < batches.length ? fetches : batches.length - 1];
    fetches++;
    return DailyBatchResponse(profiles: profiles, batchNumber: 1, remainingBatches: 2);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.photos = const [], this.photoIds});

  final List<String> photos;
  final List<int>? photoIds;

  @override
  Future<PublicProfileDTO> getPublicProfile(String userId) async =>
      PublicProfileDTO.fromJson(_profileJson(userId, photos: photos, photoIds: photoIds));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _profileJson(String userId, {List<String> photos = const [], List<int>? photoIds}) => {
      'userId': userId,
      'name': 'Bob',
      'age': 30,
      'height': 180,
      'city': 'London',
      'language': 'English',
      'education': 'University',
      'occupation': 'Engineer',
      'badges': <String>[],
      'profile': {
        'coverPhoto': null,
        'photos': photos,
        'photoIds': ?photoIds,
        'bio': 'Likes long walks.',
        'hobbies': ['Hiking'],
        'traits': ['Curious'],
        'habits': {'alcoholConsumption': null, 'smokingStatus': null, 'diet': null},
        'relationshipGoals': {'intention': null, 'kidsPreference': null, 'relationshipType': null},
        'sharedInterests': <String>[],
        'qas': <Map<String, dynamic>>[],
      },
    };

UserMatchProfile _match(int matchId, String userId, String name) => UserMatchProfile(
      matchId: matchId,
      userId: userId,
      name: name,
      age: 29,
      servedAt: DateTime.utc(2026, 11, 23, 9),
    );

void main() {
  late FakeSafetyApi api;
  late _FakeMatchRepository matches;
  late _FakeProfileRepository profiles;
  late SharedPreferences prefs;

  setUp(() async {
    api = FakeSafetyApi();
    matches = _FakeMatchRepository([
      [_match(11, 'user2', 'Sam'), _match(12, 'user3', 'Alex')],
      [_match(12, 'user3', 'Alex')],
    ]);
    profiles = _FakeProfileRepository();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget home) => ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(FakeAuthService()),
          apiClientProvider.overrideWithValue(api),
          evidenceImagePickerProvider.overrideWithValue(FakeImagePicker()),
          sharedPreferencesProvider.overrideWithValue(prefs),
          matchRepositoryProvider.overrideWithValue(matches),
          profileRepositoryProvider.overrideWithValue(profiles),
        ],
        child: MaterialApp(home: home),
      );

  /// A home screen with a button that pushes [screen], so a test can see it pop.
  Widget launcher(Widget screen) => Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
              child: const Text('open'),
            ),
          ),
        ),
      );

  Future<void> openMenu(WidgetTester tester, String item) async {
    await tester.tap(find.byKey(const Key('profile-safety-menu')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  Future<void> fileReport(WidgetTester tester, String category) async {
    await tester.tap(find.text(category));
    await tester.pump();
    await tester.tap(find.text(SafetyCopy.sendReport));
    await tester.pumpAndSettle();
  }

  List<dynamic> reports() => api.sent('POST', '/safety/content-reports');
  List<dynamic> blocks() => api.sent('POST', '/safety/blocks');

  group('batch card', () {
    /// The carousel as the match screen shows it, on a batch fetched once.
    Future<void> pumpBatch(WidgetTester tester) async {
      tallScreen(tester);
      await tester.pumpWidget(app(Consumer(builder: (context, ref, _) {
        final state = ref.watch(matchBatchProvider);
        return Scaffold(
          body: state.hasProfiles
              ? MatchCarouselV2(
                  profiles: state.profiles,
                  notifier: ref.read(matchBatchProvider.notifier),
                )
              : TextButton(
                  onPressed: () => ref.read(matchBatchProvider.notifier).fetchDailyBatch(),
                  child: const Text('load'),
                ),
        );
      })));
      await tester.tap(find.text('load'));
      await tester.pumpAndSettle();
    }

    testWidgets('reports the card, thanks them, then takes it off and refetches', (tester) async {
      await pumpBatch(tester);
      expect(find.textContaining('Sam', findRichText: true), findsOneWidget);

      await openMenu(tester, SafetyCopy.report);
      expect(find.text(SafetyCopy.contentReportTitle(photo: false)), findsOneWidget);
      for (final category in ContentReportCategoryLabels.all) {
        expect(find.text(category), findsOneWidget);
      }
      await fileReport(tester, 'Scam or asking for money');

      expect(reports().single, {'targetUserId': 'user2', 'category': 'SCAM'});
      expect(find.text(SafetyCopy.contentReportThanks), findsOneWidget);

      await tester.tap(find.text(SafetyCopy.done));
      await tester.pumpAndSettle();

      expect(matches.fetches, 2);
      expect(find.textContaining('Sam', findRichText: true), findsNothing);
      expect(find.textContaining('Alex', findRichText: true), findsOneWidget);
    });

    testWidgets('a category must be chosen, and nothing is sent until it is', (tester) async {
      await pumpBatch(tester);
      await openMenu(tester, SafetyCopy.report);

      await tester.tap(find.text(SafetyCopy.sendReport));
      await tester.pumpAndSettle();

      expect(find.text(SafetyCopy.chooseCategory), findsOneWidget);
      expect(reports(), isEmpty);
    });

    testWidgets('a batch card can be reported but not blocked', (tester) async {
      await pumpBatch(tester);
      await tester.tap(find.byKey(const Key('profile-safety-menu')).first);
      await tester.pumpAndSettle();

      expect(find.text(SafetyCopy.block), findsNothing);
    });

    testWidgets('backing out sends nothing and keeps the card', (tester) async {
      await pumpBatch(tester);
      await openMenu(tester, SafetyCopy.report);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(reports(), isEmpty);
      expect(find.textContaining('Sam', findRichText: true), findsOneWidget);
      expect(matches.fetches, 1);
    });
  });

  group('public profile', () {
    testWidgets('reports the profile from the menu, closes it and refetches the batch', (tester) async {
      tallScreen(tester);
      await tester.pumpWidget(app(launcher(const PublicProfileViewScreen(userId: 'user3', matchId: 12))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await openMenu(tester, SafetyCopy.report);
      await fileReport(tester, 'Pretending to be someone else');
      await tester.tap(find.text(SafetyCopy.done));
      await tester.pumpAndSettle();

      expect(reports().single, {'targetUserId': 'user3', 'category': 'IMPERSONATION'});
      expect(find.byType(PublicProfileViewScreen), findsNothing);
    });

    testWidgets('a long-press on a photo reports it with its media id', (tester) async {
      profiles = _FakeProfileRepository(
        photos: ['https://cdn.test/a.jpg', 'https://cdn.test/b.jpg'],
        photoIds: [41, 42],
      );
      tallScreen(tester);
      await tester.pumpWidget(app(const PublicProfileViewScreen(userId: 'user3', matchId: 12)));
      await tester.pumpAndSettle();

      // The second photo sits under the profile card.
      await tester.longPress(find.byType(StackedPhoto).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(SafetyCopy.reportPhoto));
      await tester.pumpAndSettle();
      expect(find.text(SafetyCopy.contentReportTitle(photo: true)), findsOneWidget);
      await fileReport(tester, 'Nude or sexual image');

      expect(reports().single, {
        'targetUserId': 'user3',
        'targetMediaId': 42,
        'category': 'INTIMATE_IMAGE',
      });
    });

    testWidgets('without photo ids from the backend, a photo report is on the profile', (tester) async {
      profiles = _FakeProfileRepository(photos: ['https://cdn.test/a.jpg']);
      tallScreen(tester);
      await tester.pumpWidget(app(const PublicProfileViewScreen(userId: 'user3', matchId: 12)));
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(ThumbnailPhoto));
      await tester.pumpAndSettle();
      await tester.tap(find.text(SafetyCopy.reportPhoto));
      await tester.pumpAndSettle();
      await fileReport(tester, 'Uses my photo or work');

      expect(reports().single, {'targetUserId': 'user3', 'category': 'COPYRIGHT'});
    });

    testWidgets('a 404 says the profile is gone, and it still leaves the screen', (tester) async {
      api.responses['POST /safety/content-reports'] = const NotFoundException('Profile not found');
      tallScreen(tester);
      await tester.pumpWidget(app(launcher(const PublicProfileViewScreen(userId: 'user3', matchId: 12))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await openMenu(tester, SafetyCopy.report);
      await fileReport(tester, 'Harassment');

      expect(find.text(SafetyCopy.profileGone), findsOneWidget);
      await tester.tap(find.text(SafetyCopy.done));
      await tester.pumpAndSettle();
      expect(find.byType(PublicProfileViewScreen), findsNothing);
    });

    testWidgets('your own preview has no menu and no photo long-press', (tester) async {
      profiles = _FakeProfileRepository(photos: ['https://cdn.test/a.jpg'], photoIds: [41]);
      tallScreen(tester);
      await tester.pumpWidget(app(const PublicProfileViewScreen.preview(userId: 'user1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile-safety-menu')), findsNothing);
      await tester.longPress(find.byType(ThumbnailPhoto));
      await tester.pumpAndSettle();
      expect(find.text(SafetyCopy.reportPhoto), findsNothing);
    });

    testWidgets('a match opened from a date can be blocked, and pops hidden', (tester) async {
      final date = DateDetail.fromJson(dateDetailJson(state: 'COMPLETED', cancellable: false));
      DatePartnerSafetyExit? exit;
      tallScreen(tester);
      await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              exit = await Navigator.of(context).push<DatePartnerSafetyExit>(MaterialPageRoute(
                builder: (_) => PublicProfileViewScreen(
                  userId: 'user2',
                  matchId: 1007,
                  hideActionButtons: true,
                  date: date,
                ),
              ));
            },
            child: const Text('open'),
          ),
        ),
      )));
      api.responses['GET /dates/7'] = dateDetailJson(state: 'COMPLETED', cancellable: false);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await openMenu(tester, SafetyCopy.block);
      await tester.tap(find.widgetWithText(ElevatedButton, SafetyCopy.blockConfirm));
      await tester.pumpAndSettle();

      expect(blocks().single, {'userId': 'user2'});
      expect(exit, DatePartnerSafetyExit.hidden);
    });
  });

  group('date partner header', () {
    Future<void> pumpDetail(WidgetTester tester, Map<String, dynamic> date) async {
      tallScreen(tester);
      api.responses['GET /dates/7'] = date;
      await tester.pumpWidget(app(launcher(const DateDetailScreen(dateId: '7'))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a block confirms first, then blocks, refetches and closes the date', (tester) async {
      await pumpDetail(tester, dateDetailJson(state: 'COMPLETED', cancellable: false));
      final datesBefore = api.sent('GET', '/dates/7').length;

      await openMenu(tester, SafetyCopy.block);
      expect(find.text(SafetyCopy.blockTitle('Sam')), findsOneWidget);
      expect(find.text(SafetyCopy.blockBody), findsOneWidget);
      expect(blocks(), isEmpty);

      await tester.tap(find.widgetWithText(ElevatedButton, SafetyCopy.blockConfirm));
      await tester.pumpAndSettle();

      expect(blocks().single, {'userId': 'user2'});
      expect(api.sent('GET', '/dates/7').length, greaterThan(datesBefore));
      expect(find.text(SafetyCopy.blocked), findsOneWidget);
      expect(find.byType(DateDetailScreen), findsNothing);
    });

    testWidgets('"Not now" sends nothing', (tester) async {
      await pumpDetail(tester, dateDetailJson(state: 'COMPLETED', cancellable: false));

      await openMenu(tester, SafetyCopy.block);
      await tester.tap(find.text(SafetyCopy.notNow));
      await tester.pumpAndSettle();

      expect(blocks(), isEmpty);
      expect(find.byType(DateDetailScreen), findsOneWidget);
    });

    testWidgets('a 409 ACTIVE_DATE says to cancel first, and opens the cancel flow', (tester) async {
      api.responses['POST /safety/blocks'] = ConflictException(
        'Cancel your date first. Then you can block them.',
        originalError: safetyFixture('block_active_date'),
      );
      await pumpDetail(tester, dateDetailJson());

      await openMenu(tester, SafetyCopy.block);
      await tester.tap(find.widgetWithText(ElevatedButton, SafetyCopy.blockConfirm));
      await tester.pumpAndSettle();

      expect(find.text(SafetyCopy.blockActiveDate), findsOneWidget);
      expect(find.text(SafetyCopy.blocked), findsNothing);

      await tester.tap(find.text(SafetyCopy.cancelDate));
      await tester.pumpAndSettle();

      expect(find.byType(CancelDateDialog), findsOneWidget);
      expect(find.byType(DateDetailScreen), findsOneWidget);
    });

    testWidgets('a 409 on a date that can no longer be cancelled offers no cancel', (tester) async {
      api.responses['POST /safety/blocks'] = ConflictException(
        'Cancel your date first. Then you can block them.',
        originalError: safetyFixture('block_active_date'),
      );
      await pumpDetail(tester, dateDetailJson(cancellable: false));

      await openMenu(tester, SafetyCopy.block);
      await tester.tap(find.widgetWithText(ElevatedButton, SafetyCopy.blockConfirm));
      await tester.pumpAndSettle();

      expect(find.text(SafetyCopy.blockActiveDate), findsOneWidget);
      expect(find.text(SafetyCopy.cancelDate), findsNothing);
    });

    testWidgets('on a finished date, "Report" reports the partner\'s profile', (tester) async {
      await pumpDetail(tester, dateDetailJson(state: 'COMPLETED', cancellable: false));

      await openMenu(tester, SafetyCopy.report);
      await fileReport(tester, 'Looks under 18');

      expect(reports().single, {'targetUserId': 'user2', 'category': 'UNDERAGE'});
      expect(api.sent('POST', '/dates/7/report'), isEmpty);

      await tester.tap(find.text(SafetyCopy.done));
      await tester.pumpAndSettle();
      expect(find.byType(DateDetailScreen), findsNothing);
    });

    testWidgets('on a date in progress, "Report and block" is the date\'s report', (tester) async {
      await pumpDetail(tester, dateDetailJson());

      await openMenu(tester, SafetyCopy.reportAndBlock);

      expect(find.byType(ReportSheet), findsOneWidget);
      expect(reports(), isEmpty);
    });

    testWidgets('once the date is reported, the header has no menu', (tester) async {
      await pumpDetail(tester, dateDetailJson(state: 'COMPLETED', youReported: true));

      expect(find.byKey(const Key('profile-safety-menu')), findsNothing);
    });
  });
}

/// Every category label, in the order the sheet lists them.
class ContentReportCategoryLabels {
  static const all = [
    'Nude or sexual image',
    'Looks under 18',
    'Scam or asking for money',
    'Pretending to be someone else',
    'Harassment',
    'Something illegal',
    'Uses my photo or work',
    'Something else',
  ];
}
