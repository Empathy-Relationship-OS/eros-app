import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/update_user_request.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_multi_choice_screen.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/displayable_choice_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the rows under the options fit a short screen, scrolling if they must',
      (tester) async {
    // As short as an iPhone SE's body with large text: the old layout overflowed here.
    tester.view.physicalSize = const Size(375, 380);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: EditMultiChoiceScreen<Ethnicity>(
          title: 'Ethnicity',
          question: 'What is your ethnicity?',
          options: Ethnicity.values,
          labelOf: (e) => e.displayName,
          min: 1,
          initial: Ethnicity.values.take(4).toList(),
          initialVisible: true,
          usedForMatching: true,
          buildRequest: (selected, visible) => UpdateUserRequest(),
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text(HiddenAnswersNote.text), 50,
        scrollable: find.byType(Scrollable).last);
    expect(find.text(HiddenAnswersNote.text), findsOneWidget);
  });
}
