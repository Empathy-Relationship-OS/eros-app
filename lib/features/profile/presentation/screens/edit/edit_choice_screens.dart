import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/domain/models/update_user_request.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_section_scaffold.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/displayable_choice_editor.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/single_choice_editor.dart';

/// Edits one `DisplayableField` enum (habits, relationship goals, identity) with
/// [DisplayableChoiceEditor]. Saves only that field: [buildRequest] wraps it in an
/// `UpdateUserRequest`. With [preferNotToSay] chosen, the field is always saved hidden.
class EditDisplayableChoiceScreen<T extends Enum> extends ConsumerStatefulWidget {
  final String title;
  final String question;
  final List<T> values;
  final String Function(T value) labelOf;
  final DisplayableField<T?> initial;
  final T? preferNotToSay;
  final UpdateUserRequest Function(DisplayableField<T?> field) buildRequest;

  const EditDisplayableChoiceScreen({
    super.key,
    required this.title,
    required this.question,
    required this.values,
    required this.labelOf,
    required this.initial,
    required this.buildRequest,
    this.preferNotToSay,
  });

  @override
  ConsumerState<EditDisplayableChoiceScreen<T>> createState() => _EditDisplayableChoiceScreenState<T>();
}

class _EditDisplayableChoiceScreenState<T extends Enum> extends ConsumerState<EditDisplayableChoiceScreen<T>> {
  late T? _selected = widget.initial.field;
  late bool _visible = widget.initial.visible;

  bool get _effectiveVisible =>
      DisplayableChoiceEditor.effectiveVisible(_selected, _visible, widget.preferNotToSay);

  bool get _isDirty => _selected != widget.initial.field || _effectiveVisible != widget.initial.visible;

  @override
  Widget build(BuildContext context) {
    return EditSectionScaffold(
      title: widget.title,
      isDirty: _isDirty,
      canSave: _isDirty && _selected != null,
      onSave: () => ref
          .read(myProfileProvider.notifier)
          .saveSection(widget.buildRequest(DisplayableField(field: _selected, visible: _effectiveVisible))),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EditQuestion(widget.question),
            const SizedBox(height: 24),
            DisplayableChoiceEditor<T>(
              values: widget.values,
              selected: _selected,
              visible: _visible,
              labelOf: widget.labelOf,
              onSelected: (value) => setState(() => _selected = value),
              onVisibleChanged: (visible) => setState(() => _visible = visible),
              preferNotToSay: widget.preferNotToSay,
            ),
          ],
        ),
      ),
    );
  }
}

/// Edits the education level with [SingleChoiceEditor].
class EditEducationScreen extends ConsumerStatefulWidget {
  final EducationLevel initial;

  const EditEducationScreen({super.key, required this.initial});

  @override
  ConsumerState<EditEducationScreen> createState() => _EditEducationScreenState();
}

class _EditEducationScreenState extends ConsumerState<EditEducationScreen> {
  late EducationLevel _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final isDirty = _selected != widget.initial;
    return EditSectionScaffold(
      title: 'Education',
      isDirty: isDirty,
      canSave: isDirty,
      onSave: () =>
          ref.read(myProfileProvider.notifier).saveSection(UpdateUserRequest(educationLevel: _selected)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EditQuestion('What\'s your education level?'),
            const SizedBox(height: 24),
            SingleChoiceEditor<EducationLevel>(
              values: EducationLevel.values,
              selected: _selected,
              labelOf: (level) => level.displayName,
              onSelected: (level) => setState(() => _selected = level),
            ),
          ],
        ),
      ),
    );
  }
}
