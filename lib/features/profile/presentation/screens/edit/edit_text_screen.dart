import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/utils/user_text.dart';
import 'package:eros_app/features/profile/domain/models/update_user_request.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_section_scaffold.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/text_field_editor.dart';

/// Edits one optional text field (bio, occupation) with [TextFieldEditor].
///
/// The text is cleaned with [UserText.clean] before it's compared and sent (RFC-004 D-16):
/// apostrophes, quotes and the rest are kept as typed, so the hub shows exactly what was
/// written. [multiline] keeps line breaks (the bio). It may be emptied: the empty string is
/// sent, because the backend treats a missing field as "unchanged".
class EditTextScreen extends ConsumerStatefulWidget {
  final String title;
  final String question;
  final String fieldName;
  final String initial;
  final int maxLength;
  final int maxLines;
  final bool multiline;
  final String? hintText;
  final String? labelText;
  final UpdateUserRequest Function(String text) buildRequest;

  const EditTextScreen({
    super.key,
    required this.title,
    required this.question,
    required this.fieldName,
    required this.initial,
    required this.maxLength,
    required this.buildRequest,
    this.maxLines = 1,
    this.multiline = false,
    this.hintText,
    this.labelText,
  });

  @override
  ConsumerState<EditTextScreen> createState() => _EditTextScreenState();
}

class _EditTextScreenState extends ConsumerState<EditTextScreen> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// What is compared and saved.
  String get _value => UserText.clean(_controller.text, multiline: widget.multiline);

  // Optional, so empty is fine.
  String? _validate(String? text) =>
      UserText.validate(text, name: widget.fieldName, maxLength: widget.maxLength, multiline: widget.multiline);

  @override
  Widget build(BuildContext context) {
    // Against the saved value cleaned the same way, so spaces alone don't enable Save.
    final isDirty = _value != UserText.clean(widget.initial, multiline: widget.multiline);
    return EditSectionScaffold(
      title: widget.title,
      isDirty: isDirty,
      canSave: isDirty && _validate(_controller.text) == null,
      onSave: () => ref.read(myProfileProvider.notifier).saveSection(widget.buildRequest(_value)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EditQuestion(widget.question),
              const SizedBox(height: 24),
              TextFieldEditor(
                controller: _controller,
                maxLength: widget.maxLength,
                maxLines: widget.maxLines,
                hintText: widget.hintText,
                labelText: widget.labelText,
                validator: _validate,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
