import 'package:eros_app/core/notifications/push_host.dart';
import 'package:eros_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:eros_app/features/chat/presentation/widgets/chat_copy.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_repository_provider.dart';
import 'package:eros_app/features/verification/data/verification_repository.dart';
import 'package:eros_app/features/verification/presentation/providers/verification_provider.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../dates/presentation/verification_wall_harness.dart';
import '../../safety/fake_safety_api.dart';
import '../chat_test_harness.dart';
import '../fake_chat_repository.dart';

/// The wall in place of the chat composer (VF-F4 item 4) and a send's 403 (item 5).
void main() {
  late FakeSafetyApi verificationApi;
  late FakeDatesRepository dates;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, FakeChatRepository chat, {required bool walled}) async {
    verificationApi = FakeSafetyApi(responses: {statusRequest: statusJson('NOT_VERIFIED')});
    final overrides = await chatOverrides(
      chat: chat,
      date: chatDate(verificationRequired: walled),
    );
    container = ProviderContainer(overrides: [
      ...overrides,
      signedInUidProvider.overrideWithValue('me'),
      verificationRepositoryProvider.overrideWithValue(VerificationRepository(verificationApi)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ChatScreen(dateId: '42')),
    ));
    await tester.pump();
    await tester.pump();
    dates = container.read(datesRepositoryProvider) as FakeDatesRepository;
  }

  /// Closes the screen, so the chat stops polling before the test ends.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(key: ValueKey('closed'), home: SizedBox.shrink()),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the composer is replaced by the one-line wall; messages stay', (tester) async {
    final chat = FakeChatRepository()..addPartnerMessage('Just parking, 5 minutes');
    await pump(tester, chat, walled: true);

    expect(find.text('Just parking, 5 minutes'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text(VerificationCopy.wallTitle), findsOneWidget);
    expect(find.widgetWithText(TextButton, VerificationCopy.verifyNow), findsOneWidget);

    await close(tester);
  });

  testWidgets('not required: the composer as before', (tester) async {
    await pump(tester, FakeChatRepository(), walled: false);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(VerificationCopy.wallTitle), findsNothing);
    expect(verificationApi.requests, isEmpty);

    await close(tester);
  });

  testWidgets('a send answered 403 shows the wall, not a toast', (tester) async {
    final chat = FakeChatRepository()..sendError = verificationRequiredError;
    await pump(tester, chat, walled: false);
    // The server now says so too.
    dates.date = chatDate(verificationRequired: true);

    await tester.enterText(find.byType(TextField), 'On my way');
    await tester.pump();
    await tester.tap(find.byTooltip(ChatCopy.send));
    await tester.pump();
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.text(VerificationCopy.wallTitle), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(verificationApi.sent('GET', '/users/me/verification'), isNotEmpty);
    // The message stays, as not sent, and can't be retried behind the wall.
    expect(find.text('On my way'), findsOneWidget);
    expect(find.text(ChatCopy.notSent), findsOneWidget);

    await close(tester);
  });
}
