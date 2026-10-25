import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/utils/user_text.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/domain/models/profile_field_limits.dart';
import 'package:eros_app/features/profile/domain/models/update_user_request.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_section_scaffold.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/multi_choice_editor.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/text_field_editor.dart';

/// Edits a "Brain" or "Body" pair: attributes chosen from [values] plus a short description
/// (at most [ProfileFieldLimits.maxDescriptionLength] characters, D-11). Both are optional:
/// no attributes is sent as null, an empty description as null. Each keeps its current
/// visibility; the hub's eye icons change that.
class EditAttributesScreen<T> extends ConsumerStatefulWidget {
  final String title;
  final String question;
  final List<T> values;
  final String Function(T value) labelOf;
  final DisplayableField<List<T>?> initialAttributes;
  final DisplayableField<String?> initialDescription;
  final UpdateUserRequest Function(DisplayableField<List<T>?> attributes, DisplayableField<String?> description)
      buildRequest;

  const EditAttributesScreen({
    super.key,
    required this.title,
    required this.question,
    required this.values,
    required this.labelOf,
    required this.initialAttributes,
    required this.initialDescription,
    required this.buildRequest,
  });

  @override
  ConsumerState<EditAttributesScreen<T>> createState() => _EditAttributesScreenState<T>();
}

class _EditAttributesScreenState<T> extends ConsumerState<EditAttributesScreen<T>> {
  late List<T> _selected = widget.initialAttributes.field ?? [];
  late final TextEditingController _description =
      TextEditingController(text: widget.initialDescription.field ?? '');

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  List<T>? get _attributes => _selected.isEmpty ? null : _selected;

  /// Cleaned by D-16, so nothing the user wrote is removed. Empty is sent as null.
  String? get _descriptionValue => _cleanDescription(_description.text);

  static String? _cleanDescription(String? text) {
    final cleaned = UserText.clean(text ?? '');
    return cleaned.isEmpty ? null : cleaned;
  }

  bool get _isDirty =>
      !listEquals(_attributes, widget.initialAttributes.field) ||
      _descriptionValue != _cleanDescription(widget.initialDescription.field);

  // Optional, so empty is fine.
  String? _validateDescription(String? text) =>
      UserText.validate(text, name: 'Description', maxLength: ProfileFieldLimits.maxDescriptionLength);

  @override
  Widget build(BuildContext context) {
    return EditSectionScaffold(
      title: widget.title,
      isDirty: _isDirty,
      canSave: _isDirty && _validateDescription(_description.text) == null,
      onSave: () => ref.read(myProfileProvider.notifier).saveSection(widget.buildRequest(
            DisplayableField(field: _attributes, visible: widget.initialAttributes.visible),
            DisplayableField(field: _descriptionValue, visible: widget.initialDescription.visible),
          )),
      body: Column(
        children: [
          MultiChoiceEditor<T>(
            options: widget.values,
            selected: _selected,
            labelOf: widget.labelOf,
            onChanged: (selected) => setState(() => _selected = selected),
            header: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: EditQuestion(widget.question),
            ),
            showCounter: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Form(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: TextFieldEditor(
                controller: _description,
                maxLength: ProfileFieldLimits.maxDescriptionLength,
                maxLines: 3,
                labelText: 'Describe it in your own words (optional)',
                validator: _validateDescription,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
