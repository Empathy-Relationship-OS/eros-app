import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';

/// The frame around every profile-editor screen (RFC-004 §6.2): the section title, a Save
/// button, an error banner and a discard-changes guard.
///
/// - **Save** is enabled when [canSave] (the value is valid and has changed) and calls
///   [onSave]. On success the screen pops. A failure stays on the screen and shows in the banner:
///   the server's validation message, a repository error, or a local `ArgumentError` from
///   `UpdateUserRequest`. Any other error is reported through `FlutterError.reportError` and
///   shown as a generic message, so Save is always usable again.
/// - **Back** with [isDirty] asks before throwing the change away.
///
/// [body] fills the space under the banner. Editors that return an `Expanded` (the choice and
/// multi-choice editors) must sit in a `Column` inside it.
class EditSectionScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final bool canSave;
  final bool isDirty;
  final Future<void> Function() onSave;
  final PreferredSizeWidget? appBarBottom;

  const EditSectionScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.canSave,
    required this.isDirty,
    required this.onSave,
    this.appBarBottom,
  });

  @override
  State<EditSectionScaffold> createState() => _EditSectionScaffoldState();
}

class _EditSectionScaffoldState extends State<EditSectionScaffold> {
  bool _saving = false;
  bool _saved = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave();
      if (!mounted) return;
      setState(() => _saved = true);
      Navigator.of(context).pop();
    } on ProfileValidationException catch (e) {
      _fail(e.getUserMessage());
    } on ProfileRepositoryException catch (e) {
      _fail(e.message);
    } on ArgumentError catch (e) {
      _fail(e.message?.toString() ?? 'Please check your changes and try again.');
    } catch (e, stack) {
      // Anything else is a bug. Report it, and never leave Save disabled and back blocked.
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stack,
        library: 'profile editor',
        context: ErrorDescription('while saving "${widget.title}"'),
      ));
      _fail('We couldn\'t save your changes. Please try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = message;
    });
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your changes to this section haven\'t been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _saved = true); // lets this pop through
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _saved || !widget.isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(widget.title, style: const TextStyle(color: Colors.black)),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else
              TextButton(
                onPressed: widget.canSave ? _save : null,
                child: Text(
                  'Save',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.canSave ? AppColors.primary : Colors.grey[400],
                  ),
                ),
              ),
          ],
          bottom: widget.appBarBottom,
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Container(
                  key: const Key('edit-error-banner'),
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_error!, style: TextStyle(color: Colors.red[900])),
                      ),
                    ],
                  ),
                ),
              Expanded(child: widget.body),
            ],
          ),
        ),
      ),
    );
  }
}

/// The heading at the top of an editor screen's body.
class EditQuestion extends StatelessWidget {
  final String text;

  const EditQuestion(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
    );
  }
}
