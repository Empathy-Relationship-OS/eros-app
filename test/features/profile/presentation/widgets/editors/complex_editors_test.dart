import 'package:eros_app/core/constants/languages.dart';
import 'package:eros_app/features/profile/domain/enums/personality.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/city_editor.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/height_editor.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/languages_editor.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/multi_choice_editor.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/star_sign_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

/// Hosts a [MultiChoiceEditor] and owns its selection, as a screen would.
class _Host<T> extends StatefulWidget {
  const _Host({required this.build, required this.initial});

  final Widget Function(List<T> selected, ValueChanged<List<T>> onChanged) build;
  final List<T> initial;

  @override
  State<_Host<T>> createState() => _HostState<T>();
}

class _HostState<T> extends State<_Host<T>> {
  late List<T> selected = widget.initial;
  final changes = <List<T>>[];

  @override
  Widget build(BuildContext context) => Column(
        children: [
          widget.build(selected, (next) {
            changes.add(next);
            setState(() => selected = next);
          }),
        ],
      );
}

void main() {
  group('MultiChoiceEditor', () {
    const options = ['Apple', 'Banana', 'Cherry', 'Date', 'Elderberry'];

    Future<_HostState<String>> pumpEditor(
      WidgetTester tester, {
      List<String> initial = const [],
      int? max = 3,
      String? searchHint,
    }) async {
      await _pump(
        tester,
        _Host<String>(
          initial: initial,
          build: (selected, onChanged) => MultiChoiceEditor<String>(
            options: options,
            selected: selected,
            labelOf: (o) => o,
            min: 2,
            max: max,
            onChanged: onChanged,
            searchHint: searchHint,
            showCounter: true,
            emptyText: 'No fruit found',
          ),
        ),
      );
      return tester.state<_HostState<String>>(find.byType(_Host<String>));
    }

    testWidgets('onChanged receives the new selection, in the order chosen', (tester) async {
      final host = await pumpEditor(tester);

      await tester.tap(find.text('Cherry'));
      await tester.pump();
      await tester.tap(find.text('Apple'));
      await tester.pump();
      await tester.tap(find.text('Cherry'));
      await tester.pump();

      expect(host.changes, [
        ['Cherry'],
        ['Cherry', 'Apple'],
        ['Apple'],
      ]);
    });

    testWidgets('enforces the maximum: other options stop responding', (tester) async {
      final host = await pumpEditor(tester, initial: ['Apple', 'Banana', 'Cherry']);

      expect(find.text('3/3 selected'), findsOneWidget);
      await tester.tap(find.text('Date'));
      await tester.pump();

      expect(host.changes, isEmpty);
      expect(tester.widget<MultiChoiceTile>(find.widgetWithText(MultiChoiceTile, 'Date')).isMaxed, isTrue);
    });

    testWidgets('the counter turns valid between min and max', (tester) async {
      await pumpEditor(tester, initial: ['Apple']);

      Color? counterColor() => tester.widget<Text>(find.textContaining('/3 selected')).style?.color;
      final below = counterColor();
      await tester.tap(find.text('Banana'));
      await tester.pump();

      expect(counterColor(), isNot(below));
      expect(MultiChoiceEditor.isValidCount(1, 2, 3), isFalse);
      expect(MultiChoiceEditor.isValidCount(2, 2, 3), isTrue);
      expect(MultiChoiceEditor.isValidCount(4, 2, 3), isFalse);
      expect(MultiChoiceEditor.isValidCount(40, 1, null), isTrue);
    });

    testWidgets('Clear all empties the selection', (tester) async {
      final host = await pumpEditor(tester, initial: ['Apple', 'Banana']);

      await tester.tap(find.text('Clear all'));
      await tester.pump();

      expect(host.changes.single, isEmpty);
      expect(find.text('Clear all'), findsNothing);
    });

    testWidgets('search filters, case-insensitively', (tester) async {
      await pumpEditor(tester, searchHint: 'Search fruit...');

      await tester.enterText(find.byType(TextField), 'AN');
      await tester.pump();

      Finder inGrid(String text) => find.descendant(of: find.byType(GridView), matching: find.text(text));
      expect(inGrid('Banana'), findsOneWidget);
      expect(inGrid('Apple'), findsNothing);

      await tester.enterText(find.byType(TextField), 'kiwi');
      await tester.pump();
      expect(find.text('No fruit found'), findsOneWidget);
    });

    testWidgets('keeps and shows a selected value that isn\'t an option', (tester) async {
      final host = await pumpEditor(tester, initial: ['Fig']);

      expect(find.text('Fig'), findsOneWidget);
      await tester.tap(find.text('Apple'));
      await tester.pump();

      expect(host.changes.single, ['Fig', 'Apple']);
    });

    testWidgets('tabs switch between groups and extra views', (tester) async {
      await _pump(tester, const _TabbedHost());

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Carrot'), findsNothing);

      await tester.tap(find.text('Veg'));
      await tester.pumpAndSettle();
      expect(find.text('Carrot'), findsOneWidget);

      await tester.tap(find.text('Extra'));
      await tester.pumpAndSettle();
      expect(find.text('Extra view'), findsOneWidget);
    });

    test('toggle adds at the end, removes, and refuses past the maximum', () {
      expect(MultiChoiceEditor.toggle(['a'], 'b', 2), ['a', 'b']);
      expect(MultiChoiceEditor.toggle(['a', 'b'], 'a', 2), ['b']);
      expect(MultiChoiceEditor.toggle(['a', 'b'], 'c', 2), isNull);
      expect(MultiChoiceEditor.toggle(['a', 'b'], 'c', null), ['a', 'b', 'c']);
    });
  });

  group('SelectedChipsBar', () {
    testWidgets('shows each selection and removes one', (tester) async {
      String? removed;
      await _pump(
        tester,
        SelectedChipsBar<String>(selected: const ['Golf', 'Yoga'], labelOf: (s) => s, onRemove: (s) => removed = s),
      );

      expect(find.byType(Chip), findsNWidgets(2));
      await tester.tap(find.byIcon(Icons.close).last);

      expect(removed, 'Yoga');
    });
  });

  group('LanguagesEditor', () {
    testWidgets('lists every language and reports a selection', (tester) async {
      final host = await _pumpLanguages(tester, const []);

      expect(find.byType(LanguageOptionTile), findsNWidgets(Languages.all.length));
      await tester.tap(find.text(Languages.all[1].name));
      await tester.pump();

      expect(host.changes.single, [Languages.all[1]]);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('shows and keeps a language the app doesn\'t list yet', (tester) async {
      final arabic = Language.unsupported('Arabic');
      final host = await _pumpLanguages(tester, [arabic]);

      expect(find.byType(LanguageOptionTile), findsNWidgets(Languages.all.length + 1));
      await tester.tap(find.text(Languages.all[1].name));
      await tester.pump();

      expect(host.changes.single.map((l) => l.toBackend()), ['Arabic', Languages.all[1].name]);
    });
  });

  group('StarSignEditor', () {
    testWidgets('selects, clears on a second tap, and shows the checkbox only when set', (tester) async {
      final reported = <StarSign?>[];
      bool? visibility;
      Future<void> pumpWith(StarSign? selected) => _pump(
            tester,
            StarSignEditor(
              selected: selected,
              visible: true,
              onSelected: reported.add,
              onVisibleChanged: (v) => visibility = v,
            ),
          );

      await pumpWith(null);
      expect(find.text('Show on my profile'), findsNothing);
      await tester.tap(find.text(StarSign.values.first.displayName));
      expect(reported, [StarSign.values.first]);

      await pumpWith(StarSign.values.first);
      expect(find.text('Show on my profile'), findsOneWidget);
      await tester.tap(find.text(StarSign.values.first.displayName));
      expect(reported.last, isNull);

      await tester.tap(find.text('Show on my profile'));
      expect(visibility, isFalse);
    });
  });

  group('HeightEditor', () {
    Finder field(String label) => find.widgetWithText(TextFormField, label);

    testWidgets('reports cm for a valid height and null otherwise', (tester) async {
      final reported = <int?>[];
      int? submitted;
      await _pump(
        tester,
        Column(children: [
          HeightEditor(onChanged: reported.add, onSubmitted: (cm) => submitted = cm),
        ]),
      );

      await tester.enterText(field('Feet'), '5');
      expect(reported.last, isNull, reason: 'inches still empty');
      await tester.enterText(field('Inches'), '9');
      expect(reported.last, 175);
      await tester.enterText(field('Inches'), '12');
      expect(reported.last, isNull);

      await tester.enterText(field('Inches'), '9');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, 175);
    });

    testWidgets('reports nothing for the initial height, and converts between units', (tester) async {
      final reported = <int?>[];
      await _pump(tester, Column(children: [HeightEditor(initialHeightCm: 180, onChanged: reported.add)]));

      expect(reported, isEmpty);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);

      await tester.tap(find.text('CM'));
      await tester.pump();
      // 5'11" is 180.34, so the cm field shows 180 and that is reported.
      expect(find.text('180'), findsOneWidget);
      expect(reported.last, 180);

      await tester.enterText(field('Height (cm)'), '300');
      expect(reported.last, isNull);
    });
  });

  group('CityEditor', () {
    testWidgets('reports the picked suggestion with its coordinates', (tester) async {
      HomeCity? picked;
      var cleared = 0;
      await _pump(
        tester,
        Column(children: [
          CityEditor(onCitySelected: (c) => picked = c, onQueryCleared: () => cleared++),
        ]),
      );

      await tester.tap(find.text('Enter location manually'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'glas');
      await tester.pump();
      await tester.tap(find.text('Glasgow'));
      await tester.pump();

      expect(picked, const HomeCity('Glasgow', 55.8642, -4.2518));
      expect(find.byType(ListTile), findsNothing, reason: 'suggestions close');

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(cleared, isPositive);
    });

    testWidgets('starts from the initial city', (tester) async {
      await _pump(
        tester,
        Column(children: [CityEditor(initialCity: 'Bristol', onCitySelected: (_) {}, onQueryCleared: () {})]),
      );

      await tester.tap(find.text('Enter location manually'));
      await tester.pump();

      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Bristol');
    });
  });
}

Future<_HostState<Language>> _pumpLanguages(WidgetTester tester, List<Language> initial) async {
  await _pump(
    tester,
    _Host<Language>(
      initial: initial,
      build: (selected, onChanged) => LanguagesEditor(selected: selected, onChanged: onChanged),
    ),
  );
  return tester.state<_HostState<Language>>(find.byType(_Host<Language>));
}

/// A grouped editor with one extra tab, as the personality screen uses it.
class _TabbedHost extends StatefulWidget {
  const _TabbedHost();

  @override
  State<_TabbedHost> createState() => _TabbedHostState();
}

class _TabbedHostState extends State<_TabbedHost> with SingleTickerProviderStateMixin {
  late final TabController controller = TabController(length: 3, vsync: this);
  List<String> selected = [];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          multiChoiceTabBar(controller: controller, labels: const ['Fruit', 'Veg', 'Extra']),
          MultiChoiceEditor<String>(
            groups: const [
              MultiChoiceGroup('Fruit', ['Apple']),
              MultiChoiceGroup('Veg', ['Carrot']),
            ],
            tabController: controller,
            extraTabViews: const [Center(child: Text('Extra view'))],
            selected: selected,
            labelOf: (o) => o,
            onChanged: (next) => setState(() => selected = next),
          ),
        ],
      );
}
