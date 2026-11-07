import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_patch.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_values.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preferences.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preferences_provider.dart';
import 'package:eros_app/features/match_preferences/presentation/widgets/dealbreaker_switch.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_section_scaffold.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/multi_choice_editor.dart';

/// Every string this screen shows that isn't a value's label.
abstract final class _Copy {
  static const openToAll = 'Open to all';
}

/// The editor for one value filter, such as Religion or Smoking (RFC-007 §6.3): the profile
/// enum's values with the Edit profile screen's labels, without "Prefer not to say", plus "Open to
/// all", then the Dealbreaker switch.
///
/// "Open to all" clears the other values, and is ticked when nothing else is. Ticking every value
/// saves as open to all (null), so the two can't drift apart (§4.1). Saves only this filter
/// ([patchOf]) with [MatchPreferencesNotifier.save]; the hub then shows the server's response.
class EditValueFilterScreen<T extends Enum> extends ConsumerStatefulWidget {
  final String title;

  /// The filter as the server last returned it.
  final ValueFilter<T> initial;

  final FilterChoices<T> choices;
  final String Function(T value) labelOf;

  /// The patch that replaces this filter, and nothing else.
  final FilterPatch Function(ValueFilter<T> filter) patchOf;

  const EditValueFilterScreen({
    super.key,
    required this.title,
    required this.initial,
    required this.choices,
    required this.labelOf,
    required this.patchOf,
  });

  @override
  ConsumerState<EditValueFilterScreen<T>> createState() => _EditValueFilterScreenState<T>();
}

class _EditValueFilterScreenState<T extends Enum> extends ConsumerState<EditValueFilterScreen<T>> {
  /// The ticked values, in the enum's order. Empty is open to all.
  late List<T> _values = _inOrder(widget.initial.values ?? const []);
  late bool _dealbreaker = widget.initial.dealbreaker;

  List<T> _inOrder(Iterable<T> values) => widget.choices.choices.where(values.contains).toList();

  /// The values to save: null for open to all, which every value ticked is too.
  List<T>? _toSave(List<T>? values) =>
      values == null || values.isEmpty || values.length == widget.choices.choices.length
          ? null
          : _inOrder(values);

  bool get _isDirty =>
      !_sameValues(_toSave(_values), _toSave(widget.initial.values)) ||
      _dealbreaker != widget.initial.dealbreaker;

  static bool _sameValues<E>(List<E>? a, List<E>? b) =>
      a == null || b == null ? a == b : a.length == b.length && a.toSet().containsAll(b);

  /// The editor's options are `null` (Open to all) and then the values, so it can be ticked like
  /// any other option.
  List<T?> get _ticked => _values.isEmpty ? <T?>[null] : _values;

  void _onChanged(List<T?> ticked) {
    final values = ticked.whereType<T>();
    setState(() {
      if (ticked.contains(null) && !_ticked.contains(null)) {
        // Open to all was just ticked: it clears the rest.
        _values = const [];
      } else {
        _values = _inOrder(values);
      }
    });
  }

  Future<void> _save() async {
    final filter = ValueFilter<T>(values: _toSave(_values), dealbreaker: _dealbreaker);
    await ref.read(matchPreferencesProvider.notifier).save(widget.patchOf(filter));
  }

  @override
  Widget build(BuildContext context) {
    return EditSectionScaffold(
      title: widget.title,
      canSave: _isDirty,
      isDirty: _isDirty,
      onSave: _save,
      body: Column(
        children: [
          MultiChoiceEditor<T?>(
            options: [null, ...widget.choices.choices],
            selected: _ticked,
            labelOf: (value) => value == null ? _Copy.openToAll : widget.labelOf(value),
            onChanged: _onChanged,
            // Full width, so it lines up with the options rather than centring.
            header: SizedBox(
              width: double.infinity,
              child: DealbreakerSubtitle(dealbreaker: _dealbreaker),
            ),
            listTileBuilder: (context, value, isSelected, onTap) => FilterChoiceTile(
              label: value == null ? _Copy.openToAll : widget.labelOf(value),
              isSelected: isSelected,
              onTap: onTap,
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

/// One option in a value filter's list: a checkbox and its label.
class FilterChoiceTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const FilterChoiceTile({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: isSelected,
      onChanged: onTap == null ? null : (_) => onTap!(),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: Colors.black,
        ),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
