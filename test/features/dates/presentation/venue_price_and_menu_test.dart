import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/data/repositories/dates_repository.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_repository_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/venue_ranking_provider.dart';
import 'package:eros_app/features/dates/presentation/screens/date_detail_screen.dart';
import 'package:eros_app/features/dates/presentation/screens/venue_ranking_screen.dart';
import 'package:eros_app/features/dates/presentation/widgets/booking_card.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import 'package:eros_app/features/dates/presentation/widgets/venue_detail_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _menuUrl = 'https://theivy.example/menu';

// The channel url_launcher falls back to when no platform plugin is registered, as in tests.
const _launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

/// Stubs url_launcher and records what was launched. canLaunch answers false, as it does on
/// Android 11+ with no `<queries>` entry for https: the link must not depend on it.
class _FakeLauncher {
  bool launchResult = true;
  PlatformException? launchError;
  final List<Map<Object?, Object?>> launches = [];

  void install(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_launcherChannel, (call) async {
      if (call.method == 'canLaunch') return false;
      if (call.method != 'launch') return null;
      if (launchError != null) throw launchError!;
      launches.add(call.arguments as Map<Object?, Object?>);
      return launchResult;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_launcherChannel, null));
  }
}

class _FakeUser implements User {
  @override
  String get uid => 'user1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthService implements AuthService {
  @override
  User? get currentUser => _FakeUser();

  @override
  Future<String> getIdToken({bool forceRefresh = false}) async => 'token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDatesRepository implements DatesRepository {
  _FakeDatesRepository({this.dateDetail, this.venueDetails});

  final DateDetail? dateDetail;
  final VenuePublicInfo? venueDetails;

  @override
  Future<DateDetail?> getDateById(String dateId) async => dateDetail;

  @override
  Future<VenuePublicInfo> getVenueDetails(String dateId) async => venueDetails!;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DateDetail _date({
  DateState state = DateState.booked,
  String? venueName = 'The Ivy',
  PriceRange? priceRange = const PriceRange(value: 'PREMIUM', symbol: '£££'),
  String? menuUrl = _menuUrl,
}) {
  return DateDetail(
    dateId: 7,
    matchId: 1007,
    user1Id: 'user1',
    user2Id: 'user2',
    partnerName: 'Sam',
    activityId: 1,
    activityName: 'Dinner',
    tokenCost: '1.00',
    cityId: 1,
    cityName: 'London',
    state: state,
    availabilityRound: 1,
    venueName: venueName,
    venueAddress: '1 West St',
    venuePriceRange: priceRange,
    venueMenuUrl: menuUrl,
    depositStatus: const DepositStatus(
      user1: ParticipantDepositStatus.paid,
      user2: ParticipantDepositStatus.paid,
    ),
    cancellable: false,
    timeline: const [],
    createdAt: DateTime.utc(2026, 10, 23),
    updatedAt: DateTime.utc(2026, 10, 23),
  );
}

VenueOptions _venueOptions(List<VenueOption> options) =>
    VenueOptions(dateId: 7, options: options, myRankings: const []);

const _ivy = VenueOption(
  venueId: 1,
  name: 'The Ivy',
  address: '1 West St',
  optionOrder: 1,
  priceRange: PriceRange(value: 'PREMIUM', symbol: '£££'),
  menuUrl: _menuUrl,
);

const _bao = VenueOption(
  venueId: 2,
  name: 'Bao',
  address: '2 Lexington St',
  optionOrder: 2,
  priceRange: PriceRange(value: 'BUDGET', symbol: '£'),
);

Future<void> _pumpRanking(WidgetTester tester, List<VenueOption> options) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(_FakeAuthService()),
      venueOptionsProvider('7').overrideWith((ref) async => _venueOptions(options)),
    ],
    child: const MaterialApp(home: VenueRankingScreen(dateId: '7')),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pumpBookingCard(WidgetTester tester, DateDetail date) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: BookingCard(dateDetail: date, currentUid: 'user1')),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pumpDateDetail(WidgetTester tester, DateDetail date) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(_FakeAuthService()),
      datesRepositoryProvider.overrideWithValue(_FakeDatesRepository(dateDetail: date)),
    ],
    child: const MaterialApp(home: DateDetailScreen(dateId: '7')),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pumpVenueSheet(WidgetTester tester, VenuePublicInfo venue) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(_FakeAuthService()),
      datesRepositoryProvider.overrideWithValue(_FakeDatesRepository(venueDetails: venue)),
    ],
    child: const MaterialApp(home: Scaffold(body: VenueDetailSheet(dateId: '7'))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  late _FakeLauncher launcher;

  Finder seeMenu() => find.text(DatesCopy.venueSeeMenu);

  Future<void> tapSeeMenu(WidgetTester tester) async {
    await tester.tap(seeMenu());
    await tester.pumpAndSettle();
  }

  group('venue ranking screen', () {
    setUp(() => launcher = _FakeLauncher());

    testWidgets('shows each option\'s symbol as sent', (tester) async {
      // Tall enough that the list builds all three cards.
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpRanking(tester, const [
        _ivy,
        _bao,
        VenueOption(
          venueId: 3,
          name: 'Franklin',
          address: '900 E 11th St',
          optionOrder: 3,
          priceRange: PriceRange(value: 'MID_RANGE', symbol: r'$$'),
        ),
      ]);

      expect(find.text('£££'), findsOneWidget);
      expect(find.text('£'), findsOneWidget);
      expect(find.text(r'$$'), findsOneWidget);
    });

    testWidgets('shows the band under the venue name', (tester) async {
      await _pumpRanking(tester, const [_ivy, _bao]);

      final name = tester.getRect(find.text('The Ivy'));
      final band = tester.getRect(find.text('£££'));
      final address = tester.getRect(find.text('1 West St'));

      expect(band.top, greaterThanOrEqualTo(name.bottom));
      expect(band.bottom, lessThanOrEqualTo(address.top));
    });

    testWidgets('shows the link only for options with a menu URL', (tester) async {
      await _pumpRanking(tester, const [_ivy, _bao]);

      expect(seeMenu(), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey(1)),
          matching: seeMenu(),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey(2)),
          matching: seeMenu(),
        ),
        findsNothing,
      );
    });

    testWidgets('tapping the link opens that URL in the external browser', (tester) async {
      launcher.install(tester);
      await _pumpRanking(tester, const [_ivy, _bao]);

      await tapSeeMenu(tester);

      expect(launcher.launches, hasLength(1));
      expect(launcher.launches.single['url'], _menuUrl);
      expect(launcher.launches.single['useWebView'], isFalse);
      expect(launcher.launches.single['useSafariVC'], isFalse);
      expect(find.text(DatesCopy.venueMenuOpenFailed), findsNothing);
    });

    testWidgets('keeps a tap target of at least 44 points', (tester) async {
      await _pumpRanking(tester, const [_ivy]);

      final target = tester.getSize(find.widgetWithText(TextButton, DatesCopy.venueSeeMenu));

      expect(target.height, greaterThanOrEqualTo(44));
      expect(target.width, greaterThanOrEqualTo(44));
    });

    testWidgets('fits a long symbol in a narrow card', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpRanking(tester, const [
        VenueOption(
          venueId: 1,
          name: 'Trattoria',
          address: '1 Via Roma',
          optionOrder: 1,
          priceRange: PriceRange(value: 'LUXURY', symbol: 'EUR EUR EUR EUR '),
          menuUrl: _menuUrl,
        ),
      ]);

      expect(tester.takeException(), isNull);
      expect(seeMenu(), findsOneWidget);
    });
  });

  group('when the link can\'t open', () {
    setUp(() => launcher = _FakeLauncher());

    testWidgets('says so when the launch fails', (tester) async {
      launcher
        ..launchResult = false
        ..install(tester);
      await _pumpRanking(tester, const [_ivy]);

      await tapSeeMenu(tester);

      expect(find.text(DatesCopy.venueMenuOpenFailed), findsOneWidget);
    });

    testWidgets('says so when no app can open it', (tester) async {
      launcher
        ..launchError = PlatformException(code: 'ACTIVITY_NOT_FOUND')
        ..install(tester);
      await _pumpRanking(tester, const [_ivy]);

      await tapSeeMenu(tester);

      expect(find.text(DatesCopy.venueMenuOpenFailed), findsOneWidget);
    });

    testWidgets('says so when the URL is malformed', (tester) async {
      launcher.install(tester);
      await _pumpRanking(tester, const [
        VenueOption(
          venueId: 1,
          name: 'The Ivy',
          address: '1 West St',
          optionOrder: 1,
          priceRange: PriceRange(value: 'PREMIUM', symbol: '£££'),
          menuUrl: 'http://[bad',
        ),
      ]);

      await tapSeeMenu(tester);

      expect(launcher.launches, isEmpty);
      expect(find.text(DatesCopy.venueMenuOpenFailed), findsOneWidget);
    });
  });

  group('booked date', () {
    setUp(() => launcher = _FakeLauncher());

    testWidgets('shows the band and link under the venue name', (tester) async {
      launcher.install(tester);
      await _pumpBookingCard(tester, _date());

      final name = tester.getRect(find.text('The Ivy'));
      final address = tester.getRect(find.text('1 West St'));
      final band = tester.getRect(find.text('£££'));
      expect(band.top, greaterThanOrEqualTo(name.bottom));
      expect(band.bottom, lessThanOrEqualTo(address.top));

      await tapSeeMenu(tester);
      expect(launcher.launches.single['url'], _menuUrl);
    });

    testWidgets('has no link when menu URL is null', (tester) async {
      await _pumpBookingCard(tester, _date(menuUrl: null));

      expect(find.text('£££'), findsOneWidget);
      expect(seeMenu(), findsNothing);
    });
  });

  group('date detail', () {
    setUp(() => launcher = _FakeLauncher());

    testWidgets('shows the band and link under the venue name', (tester) async {
      launcher.install(tester);
      await _pumpDateDetail(tester, _date());

      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text('£££')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.text('The Ivy')).dy),
      );

      await tapSeeMenu(tester);
      expect(launcher.launches.single['url'], _menuUrl);
    });

    testWidgets('has no link when menu URL is null', (tester) async {
      await _pumpDateDetail(tester, _date(menuUrl: null));

      expect(find.text('£££'), findsOneWidget);
      expect(seeMenu(), findsNothing);
    });

    testWidgets('shows neither before a venue is assigned', (tester) async {
      await _pumpDateDetail(
        tester,
        _date(
          state: DateState.awaitingAvailability,
          venueName: null,
          priceRange: null,
          menuUrl: null,
        ),
      );

      expect(find.text('£££'), findsNothing);
      expect(seeMenu(), findsNothing);
    });
  });

  group('venue detail sheet', () {
    const venue = VenuePublicInfo(
      venueId: 1,
      name: 'The Ivy',
      address: '1 West St',
      description: 'A classic',
      dressCode: DressCode.smartCasual,
      websiteUrl: 'https://theivy.example',
      priceRange: PriceRange(value: 'PREMIUM', symbol: '£££'),
      menuUrl: _menuUrl,
    );

    setUp(() => launcher = _FakeLauncher());

    testWidgets('shows the band and link under the venue name', (tester) async {
      launcher.install(tester);
      await _pumpVenueSheet(tester, venue);

      expect(
        tester.getTopLeft(find.text('£££')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.text('The Ivy')).dy),
      );

      await tapSeeMenu(tester);
      expect(launcher.launches.single['url'], _menuUrl);
    });

    testWidgets('has no link when menu URL is null', (tester) async {
      await _pumpVenueSheet(
        tester,
        const VenuePublicInfo(
          venueId: 1,
          name: 'The Ivy',
          address: '1 West St',
          description: 'A classic',
          dressCode: DressCode.smartCasual,
          priceRange: PriceRange(value: 'PREMIUM', symbol: '£££'),
        ),
      );

      expect(find.text('£££'), findsOneWidget);
      expect(seeMenu(), findsNothing);
    });
  });
}
