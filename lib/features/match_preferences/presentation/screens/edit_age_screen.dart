import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_patch.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_filter.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preference_options.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preferences.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preferences_provider.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/match_filter_summary.dart';
import 'package:eros_app/features/match_preferences/presentation/widgets/dealbreaker_switch.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_section_scaffold.dart';

/// The Age range editor (RFC-007 §6.3): a range slider over options' bounds, 18 to 99, where the
/// top reads "99+", then the Dealbreaker switch. The switch is on for a new user, because the
/// server's default age filter is a dealbreaker (D-5).
///
/// Saves only [AgePatch]; the hub then shows the server's response.
class EditAgeScreen extends ConsumerStatefulWidget {
  /// The filter as the server last returned it.
  final RangeFilter initial;
  final AgeOptions bounds;

  const EditAgeScreen({super.key, required this.initial, required this.bounds});

  @override
  ConsumerState<EditAgeScreen> createState() => _EditAgeScreenState();
}

class _EditAgeScreenState extends ConsumerState<EditAgeScreen> {
  late int _min = _clamp(widget.initial.min);
  late int _max = _clamp(widget.initial.max);
  late bool _dealbreaker = widget.initial.dealbreaker;

  int _clamp(int age) => age.clamp(widget.bounds.min, widget.bounds.max);

  bool get _isDirty =>
      _min != widget.initial.min ||
      _max != widget.initial.max ||
      _dealbreaker != widget.initial.dealbreaker;

  Future<void> _save() async {
    final age = RangeFilter(min: _min, max: _max, dealbreaker: _dealbreaker);
    await ref.read(matchPreferencesProvider.notifier).save(AgePatch(age));
  }

  @override
  Widget build(BuildContext context) {
    final bounds = widget.bounds;
    return EditSectionScaffold(
      title: MatchFilter.age.label,
      canSave: _isDirty && _min <= _max,
      isDirty: _isDirty,
      onSave: _save,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                DealbreakerSubtitle(dealbreaker: _dealbreaker),
                const SizedBox(height: 32),
                Text(
                  formatAgeRange(_min, _max, bounds),
                  key: const Key('age-range-value'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                RangeSlider(
                  values: RangeValues(_min.toDouble(), _max.toDouble()),
                  min: bounds.min.toDouble(),
                  max: bounds.max.toDouble(),
                  divisions: bounds.max - bounds.min,
                  semanticFormatterCallback: (value) => formatAge(value.round(), bounds),
                  activeColor: AppColors.primary,
                  onChanged: (values) => setState(() {
                    _min = values.start.round();
                    _max = values.end.round();
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ExcludeSemantics(
                        child: Text('${bounds.min}', style: TextStyle(color: Colors.grey[600])),
                      ),
                      ExcludeSemantics(
                        child: Text(
                          formatAge(bounds.max, bounds),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ],
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
