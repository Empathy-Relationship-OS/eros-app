import 'package:flutter/material.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/interest_groups.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/multi_choice_editor.dart';

/// Interests selector screen with multi-tab UI
/// Matches screenshot: @screenshots/users/create-profile/E73ABF64-E138-4BC1-9A2B-8575B6FC21EC.png
/// Requires 5-10 total selections across all categories
class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<String> _selectedInterests = [];

  static const int minSelections = 5;
  static const int maxSelections = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _groups.length, vsync: this);
    _loadExistingData();
  }

  static final List<MultiChoiceGroup<String>> _groups = interestGroups;

  void _loadExistingData() {
    final draft = ref.read(profileCreationProvider);
    if (draft.interests != null) {
      setState(() {
        // A set first, as before: duplicates in an old draft are dropped, order is kept.
        _selectedInterests = draft.interests!.toSet().toList();
      });
    }
  }

  Future<void> _continue() async {
    if (_selectedInterests.length < minSelections) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least $minSelections interests'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final currentDraft = ref.read(profileCreationProvider);
    final updatedDraft = currentDraft.copyWith(
      interests: _selectedInterests,
    );
    await ref.read(profileCreationProvider.notifier).updateDraft(updatedDraft);

    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/personality');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canContinue =
        MultiChoiceEditor.isValidCount(_selectedInterests.length, minSelections, maxSelections);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: multiChoiceTabBar(
          controller: _tabController,
          labels: [for (final group in _groups) group.label],
          isScrollable: true,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            MultiChoiceEditor<String>(
              groups: _groups,
              tabController: _tabController,
              selected: _selectedInterests,
              labelOf: (interest) => interest,
              min: minSelections,
              max: maxSelections,
              onChanged: (selected) => setState(() => _selectedInterests = selected),
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What are you into?',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select $minSelections-$maxSelections interests',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
              searchHint: 'Search interests...',
              showCounter: true,
              emptyText: 'No interests found',
            ),

            // Bottom bar with selected items and continue button
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selected interests chips
                  if (_selectedInterests.isNotEmpty) ...[
                    SelectedChipsBar<String>(
                      selected: _selectedInterests,
                      labelOf: (interest) => interest,
                      onRemove: (interest) => setState(
                        () => _selectedInterests = [..._selectedInterests]..remove(interest),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Continue button
                  AppButton(
                    label: canContinue ? 'Continue' : 'Select ${minSelections - _selectedInterests.length} more',
                    onPressed: canContinue ? _continue : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
