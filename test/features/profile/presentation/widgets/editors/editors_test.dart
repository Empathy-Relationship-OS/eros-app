import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/displayable_choice_editor.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/single_choice_editor.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/text_field_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts [child] in a Column, as the screens do, with room for every option.
Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [child]))));
}

/// The radio icon on the card labelled [label].
Icon _radioOf(WidgetTester tester, String label) => tester.widget<Icon>(find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(ChoiceOptionCard)),
      matching: find.byType(Icon),
    ));

void main() {
  group('SingleChoiceEditor', () {
    testWidgets('highlights the selected value and reports a tap on another', (tester) async {
      EducationLevel? tapped;
      await _pump(
        tester,
        SingleChoiceEditor<EducationLevel>(
          values: EducationLevel.values,
          selected: EducationLevel.university,
          labelOf: (level) => level.displayName,
          onSelected: (level) => tapped = level,
        ),
      );

      expect(_radioOf(tester, EducationLevel.university.displayName).icon, Icons.radio_button_checked);
      expect(_radioOf(tester, EducationLevel.university.displayName).color, AppColors.primary);
      expect(_radioOf(tester, EducationLevel.college.displayName).icon, Icons.radio_button_unchecked);

      await tester.tap(find.text(EducationLevel.college.displayName));

      expect(tapped, EducationLevel.college);
    });
  });

  group('DisplayableChoiceEditor', () {
    Widget editor({
      required AlcoholConsumption? selected,
      bool visible = true,
      AlcoholConsumption? preferNotToSay = AlcoholConsumption.preferNotToSay,
      ValueChanged<AlcoholConsumption>? onSelected,
      ValueChanged<bool>? onVisibleChanged,
    }) =>
        DisplayableChoiceEditor<AlcoholConsumption>(
          values: AlcoholConsumption.values,
          selected: selected,
          visible: visible,
          labelOf: (value) => value.displayName,
          onSelected: onSelected ?? (_) {},
          onVisibleChanged: onVisibleChanged ?? (_) {},
          preferNotToSay: preferNotToSay,
        );

    testWidgets('highlights the selected value and reports a tap on another', (tester) async {
      AlcoholConsumption? tapped;
      await _pump(tester, editor(selected: AlcoholConsumption.never, onSelected: (v) => tapped = v));

      expect(_radioOf(tester, AlcoholConsumption.never.displayName).icon, Icons.radio_button_checked);
      expect(_radioOf(tester, AlcoholConsumption.values[1].displayName).icon, Icons.radio_button_unchecked);

      await tester.tap(find.text(AlcoholConsumption.values[1].displayName));

      expect(tapped, AlcoholConsumption.values[1]);
    });

    testWidgets('the checkbox shows the visibility and reports a change', (tester) async {
      bool? changed;
      await _pump(
        tester,
        editor(selected: AlcoholConsumption.never, visible: true, onVisibleChanged: (v) => changed = v),
      );

      expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isTrue);

      await tester.tap(find.text('Show on my profile'));

      expect(changed, isFalse);
    });

    testWidgets('hides the checkbox when "prefer not to say" is selected', (tester) async {
      await _pump(tester, editor(selected: AlcoholConsumption.preferNotToSay));

      expect(find.byType(CheckboxListTile), findsNothing);
    });

    testWidgets('shows the checkbox before anything is selected', (tester) async {
      await _pump(tester, editor(selected: null));

      expect(find.byType(CheckboxListTile), findsOneWidget);
    });

    testWidgets('without a "prefer not to say" value, always shows the checkbox', (tester) async {
      await _pump(
        tester,
        DisplayableChoiceEditor<RelationshipType>(
          values: RelationshipType.values,
          selected: RelationshipType.values.last,
          visible: false,
          labelOf: (value) => value.displayName,
          onSelected: (_) {},
          onVisibleChanged: (_) {},
        ),
      );

      expect(find.byType(CheckboxListTile), findsOneWidget);
    });

    test('effectiveVisible is false only when "prefer not to say" is selected', () {
      const pnts = AlcoholConsumption.preferNotToSay;

      expect(DisplayableChoiceEditor.effectiveVisible(pnts, true, pnts), isFalse);
      expect(DisplayableChoiceEditor.effectiveVisible(AlcoholConsumption.never, true, pnts), isTrue);
      expect(DisplayableChoiceEditor.effectiveVisible(AlcoholConsumption.never, false, pnts), isFalse);
      expect(DisplayableChoiceEditor.effectiveVisible(RelationshipType.values.first, true, null), isTrue);
    });
  });

  group('TextFieldEditor', () {
    testWidgets('shows a live counter and enforces maxLength', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await _pump(tester, TextFieldEditor(controller: controller, maxLength: 10, hintText: 'Hint'));

      expect(find.text('Hint'), findsOneWidget);
      expect(find.text('0/10'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'abc');
      await tester.pump();
      expect(find.text('3/10'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'a' * 15);
      await tester.pump();
      expect(controller.text, 'a' * 10);
      expect(find.text('10/10'), findsOneWidget);
    });

    testWidgets('shows the label and runs the validator in a Form', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController(text: 'bad');
      addTearDown(controller.dispose);
      await _pump(
        tester,
        Form(
          key: formKey,
          child: TextFieldEditor(
            controller: controller,
            maxLength: 100,
            labelText: 'Label',
            validator: (value) => value == 'bad' ? 'Not allowed' : null,
          ),
        ),
      );

      expect(find.text('Label'), findsOneWidget);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Not allowed'), findsOneWidget);
    });
  });
}
