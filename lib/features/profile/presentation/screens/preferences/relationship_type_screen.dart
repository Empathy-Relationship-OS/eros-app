import 'package:flutter/material.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/legal/presentation/legal_routes.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/displayable_choice_editor.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';

/// Relationship type preference screen
class RelationshipTypeScreen extends ConsumerStatefulWidget {
  const RelationshipTypeScreen({super.key});

  @override
  ConsumerState<RelationshipTypeScreen> createState() =>
      _RelationshipTypeScreenState();
}

class _RelationshipTypeScreenState
    extends ConsumerState<RelationshipTypeScreen> {
  RelationshipType? _selected;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(profileCreationProvider);
    if (draft.relationshipType != null) {
      setState(() {
        _selected = draft.relationshipType!.field;
        _isVisible = draft.relationshipType!.visible;
      });
    }
  }

  Future<void> _continue() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your relationship type')),
      );
      return;
    }

    final currentDraft = ref.read(profileCreationProvider);
    final updatedDraft = currentDraft.copyWith(
      relationshipType: DisplayableField(field: _selected!, visible: _isVisible),
    );
    await ref.read(profileCreationProvider.notifier).updateDraft(updatedDraft);

    if (mounted) {
      // The sensitive data consent comes before the first special category question (CF-F1).
      Navigator.pushNamed(context, LegalRoutes.sensitiveData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileProgressBar(
                currentStep: ProfileCreationConstants.preferencesStepRelationshipType,
                totalSteps: ProfileCreationConstants.preferencesTotalSteps,
                sectionLabel: 'Preferences',
              ),
              const SizedBox(height: 32),
              Text(
                'Relationship type',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'What best describes you?',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),
              DisplayableChoiceEditor<RelationshipType>(
                values: RelationshipType.values,
                selected: _selected,
                visible: _isVisible,
                labelOf: (value) => value.displayName,
                onSelected: (value) => setState(() => _selected = value),
                onVisibleChanged: (value) => setState(() => _isVisible = value),
              ),
              AppButton(label: 'Continue', onPressed: _selected != null ? _continue : null),
            ],
          ),
        ),
      ),
    );
  }

}
