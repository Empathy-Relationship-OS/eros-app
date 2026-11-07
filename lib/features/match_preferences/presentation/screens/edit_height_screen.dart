import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_patch.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_filter.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preference_options.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preferences.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preferences_provider.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/edit_value_filter_screen.dart';
import 'package:eros_app/features/match_preferences/presentation/widgets/dealbreaker_switch.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_section_scaffold.dart';

/// Every string this screen shows.
abstract final class _Copy {
  static const openToAll = 'Open to all';
  static const feet = 'Feet';
  static const cm = 'CM';
  static const shortest = 'Shortest';
  static const tallest = 'Tallest';
  static String orLess(String height) => '$height or less';
  static String orMore(String height) => '$height or more';
}

/// The units the height can be shown in, as the profile's height editor offers them.
enum HeightUnit { feet, cm }

/// One position on the height slider: the height it saves and its label.
@immutable
class HeightStop {
  final int cm;
  final String label;

  const HeightStop(this.cm, this.label);
}

/// Inches in [cm], rounded up to the next whole inch.
int _inchesAtLeast(int cm) => (cm / 2.54 - 1e-9).ceil();

String _feetAndInches(int inches) => '${inches ~/ 12}\'${inches % 12}"';

/// The slider's stops in [unit], from [bounds]' bottom to its top. The ends mean "or less" and
/// "or more" (RFC-007 §4.1): in cm "120 cm or less" and "220 cm or more"; in feet, each end rounds
/// up to the next inch, "4'0\" or less" and "7'3\" or more", with every whole inch in between.
List<HeightStop> heightStops(HeightOptions bounds, HeightUnit unit) {
  switch (unit) {
    case HeightUnit.cm:
      return [
        HeightStop(bounds.minCm, _Copy.orLess('${bounds.minCm} cm')),
        for (var cm = bounds.minCm + 1; cm < bounds.maxCm; cm++) HeightStop(cm, '$cm cm'),
        HeightStop(bounds.maxCm, _Copy.orMore('${bounds.maxCm} cm')),
      ];
    case HeightUnit.feet:
      final bottom = _inchesAtLeast(bounds.minCm);
      final top = _inchesAtLeast(bounds.maxCm);
      return [
        HeightStop(bounds.minCm, _Copy.orLess(_feetAndInches(bottom))),
        for (var inches = bottom + 1; inches < top; inches++)
          HeightStop((inches * 2.54).round(), _feetAndInches(inches)),
        HeightStop(bounds.maxCm, _Copy.orMore(_feetAndInches(top))),
      ];
  }
}

/// The Height editor (RFC-007 §6.3): a range over options' bounds (120 to 220 cm), shown in cm or
/// in feet and inches with the same Feet / CM choice as the profile's height editor. "Open to all"
/// moves both ends out, and both ends out saves as open to all. Then the Dealbreaker switch.
///
/// Saves only [HeightPatch]; the hub then shows the server's response. A saved height that isn't
/// one of the shown stops shows as the nearest, and is sent unchanged unless the slider moves.
class EditHeightScreen extends ConsumerStatefulWidget {
  /// The filter as the server last returned it.
  final HeightFilter initial;
  final HeightOptions bounds;

  /// The unit the screen opens in. The Edit profile screen shows height in cm.
  final HeightUnit initialUnit;

  const EditHeightScreen({
    super.key,
    required this.initial,
    required this.bounds,
    this.initialUnit = HeightUnit.cm,
  });

  @override
  ConsumerState<EditHeightScreen> createState() => _EditHeightScreenState();
}

class _EditHeightScreenState extends ConsumerState<EditHeightScreen> {
  late HeightUnit _unit = widget.initialUnit;
  late int _minCm = widget.initial.minCm ?? widget.bounds.minCm;
  late int _maxCm = widget.initial.maxCm ?? widget.bounds.maxCm;
  late bool _dealbreaker = widget.initial.dealbreaker;

  bool _isOpen(int? minCm, int? maxCm) =>
      minCm == null ||
      maxCm == null ||
      (minCm <= widget.bounds.minCm && maxCm >= widget.bounds.maxCm);

  bool get _isOpenToAll => _isOpen(_minCm, _maxCm);

  HeightFilter get _filter => _isOpenToAll
      ? HeightFilter(minCm: null, maxCm: null, dealbreaker: _dealbreaker)
      : HeightFilter(
          minCm: _minCm.clamp(widget.bounds.minCm, widget.bounds.maxCm),
          maxCm: _maxCm.clamp(widget.bounds.minCm, widget.bounds.maxCm),
          dealbreaker: _dealbreaker,
        );

  bool get _isDirty {
    final initial = widget.initial;
    final initialOpen = _isOpen(initial.minCm, initial.maxCm);
    final rangeChanged = initialOpen
        ? !_isOpenToAll
        : _isOpenToAll || _minCm != initial.minCm || _maxCm != initial.maxCm;
    return rangeChanged || _dealbreaker != initial.dealbreaker;
  }

  /// The index of the stop nearest [cm] (the lower one on a tie).
  static int _nearest(List<HeightStop> stops, int cm) {
    var best = 0;
    for (var i = 1; i < stops.length; i++) {
      if ((stops[i].cm - cm).abs() < (stops[best].cm - cm).abs()) best = i;
    }
    return best;
  }

  Future<void> _save() async {
    await ref.read(matchPreferencesProvider.notifier).save(HeightPatch(_filter));
  }

  @override
  Widget build(BuildContext context) {
    final stops = heightStops(widget.bounds, _unit);
    final minIndex = _nearest(stops, _minCm);
    final maxIndex = _nearest(stops, _maxCm);

    return EditSectionScaffold(
      title: MatchFilter.height.label,
      canSave: _isDirty && _minCm <= _maxCm,
      isDirty: _isDirty,
      onSave: _save,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: DealbreakerSubtitle(dealbreaker: _dealbreaker),
                ),
                const SizedBox(height: 24),
                _UnitToggle(unit: _unit, onChanged: (unit) => setState(() => _unit = unit)),
                const SizedBox(height: 16),
                FilterChoiceTile(
                  label: _Copy.openToAll,
                  isSelected: _isOpenToAll,
                  onTap: () => setState(() {
                    _minCm = widget.bounds.minCm;
                    _maxCm = widget.bounds.maxCm;
                  }),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: _End(
                          title: _Copy.shortest,
                          value: stops[minIndex].label,
                          valueKey: const Key('height-min-value'),
                        ),
                      ),
                      Expanded(
                        child: _End(
                          title: _Copy.tallest,
                          value: stops[maxIndex].label,
                          valueKey: const Key('height-max-value'),
                          alignEnd: true,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: RangeSlider(
                    values: RangeValues(minIndex.toDouble(), maxIndex.toDouble()),
                    max: (stops.length - 1).toDouble(),
                    divisions: stops.length - 1,
                    semanticFormatterCallback: (value) => stops[value.round()].label,
                    activeColor: AppColors.primary,
                    onChanged: (values) {
                      final start = values.start.round();
                      final end = values.end.round();
                      if (start == minIndex && end == maxIndex) return;
                      setState(() {
                        // Only the end that moved takes its stop, so the other keeps a saved
                        // height that isn't a stop. Ends that meet take the same stop.
                        if (start != minIndex || start == end) _minCm = stops[start].cm;
                        if (end != maxIndex || start == end) _maxCm = stops[end].cm;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          DealbreakerFooter(
            value: _dealbreaker,
            onChanged: (value) => setState(() => _dealbreaker = value),
          ),
        ],
      ),
    );
  }
}

/// The Feet / CM choice, styled like the profile's height editor.
class _UnitToggle extends StatelessWidget {
  final HeightUnit unit;
  final ValueChanged<HeightUnit> onChanged;

  const _UnitToggle({required this.unit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(HeightUnit value, String label) {
      final selected = unit == value;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          if (!selected) onChanged(value);
        },
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        chip(HeightUnit.feet, _Copy.feet),
        const SizedBox(width: 16),
        chip(HeightUnit.cm, _Copy.cm),
      ],
    );
  }
}

/// One end of the range: "Shortest" over its height.
class _End extends StatelessWidget {
  final String title;
  final String value;
  final Key valueKey;
  final bool alignEnd;

  const _End({
    required this.title,
    required this.value,
    required this.valueKey,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(
            value,
            key: valueKey,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
