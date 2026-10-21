import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/domain/models/update_user_request.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_section_scaffold.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/multi_choice_editor.dart';

/// Edits a list field with [MultiChoiceEditor]: interests (tabs, via [groups]), traits, spoken
/// languages (list rows, via [listTileBuilder]), ethnicity.
///
/// For a `DisplayableField` list, pass [initialVisible] to show a "Show on my profile" checkbox;
/// [buildRequest] then receives the visibility too. Save needs [min]–[max] choices and a change.
class EditMultiChoiceScreen<T> extends ConsumerStatefulWidget {
  final String title;
  final String question;
  final List<T>? options;
  final List<MultiChoiceGroup<T>>? groups;
  final String Function(T option) labelOf;
  final int min;
  final int? max;
  final List<T> initial;
  final bool? initialVisible;
  final String? searchHint;
  final String emptyText;
  final MultiChoiceTileBuilder<T>? listTileBuilder;
  final UpdateUserRequest Function(List<T> selected, bool visible) buildRequest;

  const EditMultiChoiceScreen({
    super.key,
    required this.title,
    required this.question,
    required this.labelOf,
    required this.initial,
    required this.buildRequest,
    this.options,
    this.groups,
    this.min = 0,
    this.max,
    this.initialVisible,
    this.searchHint,
    this.emptyText = 'Nothing found',
    this.listTileBuilder,
  });

  @override
  ConsumerState<EditMultiChoiceScreen<T>> createState() => _EditMultiChoiceScreenState<T>();
}

class _EditMultiChoiceScreenState<T> extends ConsumerState<EditMultiChoiceScreen<T>>
    with SingleTickerProviderStateMixin {
  late List<T> _selected = widget.initial;
  late bool _visible = widget.initialVisible ?? true;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    final groups = widget.groups;
    if (groups != null) _tabController = TabController(length: groups.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  bool get _isDirty =>
      !listEquals(_selected, widget.initial) ||
      (widget.initialVisible != null && _visible != widget.initialVisible);

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups;
    final isValid = MultiChoiceEditor.isValidCount(_selected.length, widget.min, widget.max);

    return EditSectionScaffold(
      title: widget.title,
      isDirty: _isDirty,
      canSave: _isDirty && isValid,
      onSave: () => ref.read(myProfileProvider.notifier).saveSection(widget.buildRequest(_selected, _visible)),
      appBarBottom: groups == null
          ? null
          : multiChoiceTabBar(
              controller: _tabController!,
              labels: [for (final group in groups) group.label],
              isScrollable: true,
            ),
      body: Column(
        children: [
          MultiChoiceEditor<T>(
            options: widget.options,
            groups: groups,
            tabController: _tabController,
            selected: _selected,
            labelOf: widget.labelOf,
            min: widget.min,
            max: widget.max,
            onChanged: (selected) => setState(() => _selected = selected),
            header: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: EditQuestion(widget.question),
            ),
            searchHint: widget.searchHint,
            showCounter: true,
            emptyText: widget.emptyText,
            listTileBuilder: widget.listTileBuilder == null
                ? null
                : (context, option, isSelected, onTap) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: widget.listTileBuilder!(context, option, isSelected, onTap),
                    ),
          ),
          if (_selected.isNotEmpty && widget.listTileBuilder == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: SelectedChipsBar<T>(
                selected: _selected,
                labelOf: widget.labelOf,
                onRemove: (option) => setState(() => _selected = [..._selected]..remove(option)),
              ),
            ),
          if (widget.initialVisible != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CheckboxListTile(
                value: _visible,
                onChanged: (value) => setState(() => _visible = value ?? true),
                title: const Text('Show on my profile'),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primary,
              ),
            ),
          if (!isValid && widget.min > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                widget.max == null
                    ? 'Choose at least ${widget.min}'
                    : 'Choose ${widget.min} to ${widget.max}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
  }
}
