import 'package:eros_app/features/matching/presentation/screens/public_profile_view_screen.dart';
import 'package:eros_app/features/matching/presentation/widgets/match_card_components.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/domain/models/public_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves one public profile and counts the reads.
class _FakeProfileRepository implements ProfileRepository {
  final requestedIds = <String>[];

  @override
  Future<PublicProfileDTO> getPublicProfile(String userId) async {
    requestedIds.add(userId);
    return PublicProfileDTO.fromJson(_profileJson(userId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _profileJson(String userId) => {
      'userId': userId,
      'name': 'Alice',
      'age': 30,
      'height': 168,
      'city': 'London',
      'language': 'English',
      'education': 'University',
      'occupation': 'Engineer',
      'badges': <String>[],
      'profile': {
        'coverPhoto': null,
        'photos': <String>[],
        'bio': 'Likes long walks.',
        'hobbies': ['Hiking'],
        'traits': ['Curious'],
        'habits': {'alcoholConsumption': null, 'smokingStatus': null, 'diet': null},
        'relationshipGoals': {'intention': null, 'kidsPreference': null, 'relationshipType': null},
        'sharedInterests': <String>[],
        'qas': <Map<String, dynamic>>[],
      },
    };

Future<_FakeProfileRepository> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = _FakeProfileRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [profileRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(home: screen),
  ));
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('preview mode shows the banner and no actions', (tester) async {
    final repository = await _pump(tester, const PublicProfileViewScreen.preview(userId: 'dev_alice'));

    expect(find.text('This is how others see you'), findsOneWidget);
    expect(find.byType(MatchActionButtons), findsNothing);
    expect(find.byType(SingleActionButton), findsNothing);
    expect(find.text('Likes long walks.'), findsOneWidget);
    expect(repository.requestedIds, ['dev_alice']);
  });

  testWidgets('without preview mode the actions show and the banner does not', (tester) async {
    await _pump(tester, const PublicProfileViewScreen(userId: 'dev_bob', matchId: 12));

    expect(find.byType(MatchActionButtons), findsOneWidget);
    expect(find.text('This is how others see you'), findsNothing);
  });

  testWidgets('Last 24 Hours still shows its single action', (tester) async {
    await _pump(tester, const PublicProfileViewScreen(userId: 'dev_bob', matchId: 12, isFromLast24Hours: true));

    expect(find.byType(SingleActionButton), findsOneWidget);
    expect(find.text('This is how others see you'), findsNothing);
  });

  testWidgets('every preview reads the profile again', (tester) async {
    final repository = await _pump(
      tester,
      Builder(builder: (context) {
        return TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PublicProfileViewScreen.preview(userId: 'dev_alice')),
          ),
          child: const Text('open'),
        );
      }),
    );

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
    }

    expect(repository.requestedIds, ['dev_alice', 'dev_alice']);
  });
}
