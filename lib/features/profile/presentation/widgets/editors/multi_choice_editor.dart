import 'package:flutter/material.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/single_choice_editor.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/theme/app_colors.dart';

/// One tab of a grouped [MultiChoiceEditor], such as an interest category.
class MultiChoiceGroup<T> {
  final String label;
  final List<T> options;

  const MultiChoiceGroup(this.label, this.options);
}

/// Builds one option of a [MultiChoiceEditor] in list layout. [onTap] is null when the option
/// can't be chosen because the maximum is reached.
typedef MultiChoiceTileBuilder<T> = Widget Function(
  BuildContext context,
  T option,
  bool isSelected,
  VoidCallback? onTap,
);

/// Choose between [min] and [max] options (RFC-004 §6.2).
///
/// Controlled: the wrapping screen owns [selected] and replaces it from [onChanged]. Order is
/// kept: a newly chosen option goes on the end, as the onboarding screens always did. The only
/// state held here is the search text.
///
/// Pieces, each optional:
/// - **top area** (padded 24): [header], then a search field ([searchHint]), then the
///   "n/max selected" counter with Clear all ([showCounter]);
/// - **options**: a 2-column grid of tiles, or a list built by [listTileBuilder];
/// - **groups**: with [groups], one grid per group in a `TabBarView` driven by [tabController],
///   followed by any [extraTabViews]. Put [multiChoiceTabBar] with the same controller in the
///   screen's `AppBar.bottom`.
///
/// The selected-chips footer is [SelectedChipsBar], which the screen places next to its own
/// buttons. Options the user has selected but that aren't in [options] (for example a language
/// this build doesn't list) are still shown and kept, never silently dropped.
///
/// This returns an `Expanded`, so it must be a direct child of a `Column`.
class MultiChoiceEditor<T> extends StatefulWidget {
  final List<T>? options;
  final List<MultiChoiceGroup<T>>? groups;
  final TabController? tabController;
  final List<Widget> extraTabViews;
  final List<T> selected;
  final String Function(T option) labelOf;
  final int min;
  final int? max;
  final ValueChanged<List<T>> onChanged;
  final Widget? header;
  final String? searchHint;
  final bool showCounter;
  final String emptyText;
  final MultiChoiceTileBuilder<T>? listTileBuilder;

  const MultiChoiceEditor({
    super.key,
    this.options,
    this.groups,
    this.tabController,
    this.extraTabViews = const [],
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.min = 0,
    this.max,
    this.header,
    this.searchHint,
    this.showCounter = false,
    this.emptyText = 'Nothing found',
    this.listTileBuilder,
  }) : assert((options == null) != (groups == null), 'Give exactly one of options or groups'),
       assert(groups == null || tabController != null, 'groups need a tabController');

  /// True when [count] choices are within [min] and [max].
  static bool isValidCount(int count, int min, int? max) =>
      count >= min && (max == null || count <= max);

  /// [selected] with [option] added or removed, or null when it can't be added because [max]
  /// is reached.
  static List<T>? toggle<T>(List<T> selected, T option, int? max) {
    if (selected.contains(option)) return [...selected]..remove(option);
    if (max != null && selected.length >= max) return null;
    return [...selected, option];
  }

  @override
  State<MultiChoiceEditor<T>> createState() => _MultiChoiceEditorState<T>();
}

class _MultiChoiceEditorState<T> extends State<MultiChoiceEditor<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isMaxed => widget.max != null && widget.selected.length >= widget.max!;

  void _toggle(T option) {
    final next = MultiChoiceEditor.toggle(widget.selected, option, widget.max);
    if (next != null) widget.onChanged(next);
  }

  List<T> _filtered(List<T> options) => _searchQuery.isEmpty
      ? options
      : options.where((o) => widget.labelOf(o).toLowerCase().contains(_searchQuery)).toList();

  @override
  Widget build(BuildContext context) {
    final hasTop = widget.header != null || widget.searchHint != null || widget.showCounter;
    final body = _buildBody();

    if (!hasTop) return Expanded(child: body);

    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.header != null) widget.header!,
                if (widget.searchHint != null) ...[
                  _buildSearchField(),
                  const SizedBox(height: 16),
                ],
                if (widget.showCounter) _buildCounter(),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final groups = widget.groups;
    if (groups != null) {
      return TabBarView(
        controller: widget.tabController,
        children: [
          for (final group in groups) _buildGrid(_filtered(group.options)),
          ...widget.extraTabViews,
        ],
      );
    }

    final options = [
      ...widget.options!,
      ...widget.selected.where((s) => !widget.options!.contains(s)),
    ];
    final tileBuilder = widget.listTileBuilder;
    if (tileBuilder != null) {
      final filtered = _filtered(options);
      return ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final option = filtered[index];
          final isSelected = widget.selected.contains(option);
          final canTap = isSelected || !_isMaxed;
          return tileBuilder(context, option, isSelected, canTap ? () => _toggle(option) : null);
        },
      );
    }
    return _buildGrid(_filtered(options));
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: widget.searchHint,
        prefixIcon: const Icon(Icons.search),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildCounter() {
    final count = widget.selected.length;
    final isValid = MultiChoiceEditor.isValidCount(count, widget.min, widget.max);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.max != null ? '$count/${widget.max} selected' : '$count selected',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isValid ? AppColors.primaryDeep : AppColors.textSecondary,
              ),
        ),
        if (widget.selected.isNotEmpty)
          TextButton(
            onPressed: () => widget.onChanged(const []),
            child: const Text('Clear all'),
          ),
      ],
    );
  }

  Widget _buildGrid(List<T> options) {
    if (options.isEmpty) {
      return Center(
        child: Text(
          widget.emptyText,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        final isSelected = widget.selected.contains(option);
        final isMaxed = _isMaxed && !isSelected;
        return MultiChoiceTile(
          label: widget.labelOf(option),
          isSelected: isSelected,
          isMaxed: isMaxed,
          onTap: isMaxed ? null : () => _toggle(option),
        );
      },
    );
  }
}

/// One grid option of a [MultiChoiceEditor]: filled when selected, greyed when the maximum is
/// reached and it isn't selected.
class MultiChoiceTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isMaxed;
  final VoidCallback? onTap;

  const MultiChoiceTile({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isMaxed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: choiceTileDecoration(isSelected: isSelected, isDisabled: isMaxed),
        child: Center(
          child: Text(
            label,
            style: choiceTileTextStyle(context, isSelected: isSelected, isDisabled: isMaxed),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// The tab bar for a grouped [MultiChoiceEditor], styled to match, for `AppBar.bottom`.
TabBar multiChoiceTabBar({
  required TabController controller,
  required List<String> labels,
  bool isScrollable = false,
}) {
  return TabBar(
    controller: controller,
    isScrollable: isScrollable,
    tabs: [for (final label in labels) Tab(text: label)],
  );
}

/// A horizontal row of the selected options as removable chips, 60 high. Screens show it above
/// their main button when something is selected.
class SelectedChipsBar<T> extends StatelessWidget {
  final List<T> selected;
  final String Function(T option) labelOf;
  final ValueChanged<T> onRemove;

  const SelectedChipsBar({
    super.key,
    required this.selected,
    required this.labelOf,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final option in selected)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(labelOf(option)),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => onRemove(option),
              ),
            ),
        ],
      ),
    );
  }
}
