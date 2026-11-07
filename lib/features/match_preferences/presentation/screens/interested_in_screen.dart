import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/match_preferences/data/match_preferences_repository.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_values.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/multi_choice_editor.dart';

/// "Who are you interested in?" (RFC-007 §4.9, §6.5): the [Gender] values with the profile's
/// labels, at least one ticked. Always a dealbreaker (D-4), so there's no switch.
///
/// Shared by the onboarding step and the one-time sheet. It saves nothing itself: Continue hands
/// the choice to [onContinue], which keeps it in the onboarding draft or saves it. If
/// [onContinue] throws, the screen stays and shows the error, so Continue can be tried again.
class InterestedInScreen extends StatefulWidget {
  /// Pre-ticked when the screen opens, such as a suggestion or an earlier answer.
  final List<Gender> initialSelection;

  final Future<void> Function(List<Gender> genders) onContinue;

  /// Shown above the question, such as onboarding's progress bar.
  final Widget? header;

  /// Shows a back button. The sheet has none: it can't be left without answering.
  final bool showBack;

  const InterestedInScreen({
    super.key,
    this.initialSelection = const [],
    required this.onContinue,
    this.header,
    this.showBack = true,
  });

  @override
  State<InterestedInScreen> createState() => _InterestedInScreenState();
}

class _InterestedInScreenState extends State<InterestedInScreen> {
  late List<Gender> _selected = [...widget.initialSelection];
  bool _saving = false;
  String? _error;

  Future<void> _continue() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // In enum order, whatever order they were ticked in.
      await widget.onContinue(FilterValues.gender.choices.where(_selected.contains).toList());
    } on MatchPreferencesValidationException catch (e) {
      _fail(e.message);
      return;
    } on MatchPreferencesRepositoryException catch (e) {
      _fail(e.message);
      return;
    } catch (e, stack) {
      // Anything else is a bug. Report it, and never leave Continue disabled.
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stack,
        library: 'match preferences',
        context: ErrorDescription('while saving Interested in'),
      ));
      _fail('We couldn\'t save who you\'re interested in. Please try again.');
      return;
    }
    if (mounted) setState(() => _saving = false);
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            MultiChoiceEditor<Gender>(
              options: FilterValues.gender.choices,
              selected: _selected,
              labelOf: (gender) => gender.displayName,
              min: 1,
              onChanged: (selected) => setState(() => _selected = selected),
              header: _buildHeader(context),
              listTileBuilder: (context, gender, isSelected, onTap) => _InterestedInTile(
                label: gender.displayName,
                isSelected: isSelected,
                onTap: onTap,
              ),
            ),
            if (_error != null) _buildError(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selected.isNotEmpty && !_saving ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.header != null) ...[
          widget.header!,
          const SizedBox(height: 32),
        ],
        Text(
          'Who are you interested in?',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose all that apply. We\'ll only show you people you\'re interested in.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      key: const Key('interested-in-error'),
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
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
          Expanded(child: Text(_error!, style: TextStyle(color: Colors.red[900]))),
        ],
      ),
    );
  }
}

/// One gender in the list, styled like the onboarding gender step's options, with a checkbox
/// because several can be ticked.
class _InterestedInTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _InterestedInTile({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Semantics(
        checked: isSelected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: isSelected ? AppColors.primary : Colors.grey[400],
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.primary : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
