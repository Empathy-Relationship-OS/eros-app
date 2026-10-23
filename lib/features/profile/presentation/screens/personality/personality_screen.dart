import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/domain/enums/personality.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/multi_choice_editor.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/star_sign_editor.dart';

/// Personality traits and star sign selector
/// Matches screenshot: @screenshots/users/create-profile/F385FEFE-708E-434A-9D6F-DCC3B230A2E2.png
/// Requires 3-10 trait selections, optional star sign
class PersonalityScreen extends ConsumerStatefulWidget {
  const PersonalityScreen({super.key});

  @override
  ConsumerState<PersonalityScreen> createState() => _PersonalityScreenState();
}

class _PersonalityScreenState extends ConsumerState<PersonalityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Trait> _selectedTraits = [];
  StarSign? _selectedStarSign;
  bool _showStarSign = true;

  static const int minTraits = 3;
  static const int maxTraits = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExistingData();
  }

  void _loadExistingData() {
    final draft = ref.read(profileCreationProvider);
    if (draft.traits != null) {
      setState(() {
        // A set first, as before: duplicates in an old draft are dropped, order is kept.
        _selectedTraits = draft.traits!.toSet().toList();
      });
    }
    if (draft.starSign != null) {
      setState(() {
        _selectedStarSign = draft.starSign!.field;
        _showStarSign = draft.starSign!.visible;
      });
    }
  }

  Future<void> _continue() async {
    if (_selectedTraits.length < minTraits) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least $minTraits traits'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final currentDraft = ref.read(profileCreationProvider);
    final updatedDraft = currentDraft.copyWith(
      traits: _selectedTraits,
      starSign: _selectedStarSign != null
          ? DisplayableField(field: _selectedStarSign, visible: _showStarSign)
          : DisplayableField(field: null, visible: false),
    );
    await ref.read(profileCreationProvider.notifier).updateDraft(updatedDraft);

    if (mounted) {
      // Check if user already exists in backend
      try {
        final repository = ref.read(profileRepositoryProvider);
        final existsResponse = await repository.checkUserExists();

        if (existsResponse.exists) {
          // User already created - skip directly to Q&A
          debugPrint('✅ User already exists, skipping submission screen');
          Navigator.pushReplacementNamed(context, '/profile-creation/qa');
        } else {
          // User not created yet - proceed to submission
          debugPrint('ℹ️  User does not exist, proceeding to submission');
          Navigator.pushNamed(context, '/profile-creation/submit');
        }
      } on ProfileRepositoryException catch (e) {
        // Error checking user exists - show error and don't navigate
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = MultiChoiceEditor.isValidCount(_selectedTraits.length, minTraits, maxTraits);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: multiChoiceTabBar(
          controller: _tabController,
          labels: const ['Personality Traits', 'Star Sign'],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            MultiChoiceEditor<Trait>(
              groups: const [MultiChoiceGroup('Personality Traits', Trait.values)],
              tabController: _tabController,
              extraTabViews: [
                StarSignEditor(
                  selected: _selectedStarSign,
                  visible: _showStarSign,
                  onSelected: (sign) => setState(() => _selectedStarSign = sign),
                  onVisibleChanged: (visible) => setState(() => _showStarSign = visible),
                ),
              ],
              selected: _selectedTraits,
              labelOf: (trait) => trait.displayName,
              min: minTraits,
              max: maxTraits,
              onChanged: (selected) => setState(() => _selectedTraits = selected),
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How would you describe yourself?',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select $minTraits-$maxTraits traits',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
              searchHint: 'Search traits...',
              showCounter: true,
              emptyText: 'No traits found',
            ),

            // Bottom bar
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selected traits chips
                  if (_selectedTraits.isNotEmpty) ...[
                    SelectedChipsBar<Trait>(
                      selected: _selectedTraits,
                      labelOf: (trait) => trait.displayName,
                      onRemove: (trait) => setState(
                        () => _selectedTraits = [..._selectedTraits]..remove(trait),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: canContinue ? _continue : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(
                        canContinue
                            ? 'Continue'
                            : 'Select ${minTraits - _selectedTraits.length} more',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
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
