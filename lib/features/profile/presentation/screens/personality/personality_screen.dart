import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/domain/enums/personality.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

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
  final Set<Trait> _selectedTraits = {};
  StarSign? _selectedStarSign;
  bool _showStarSign = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const int minTraits = 3;
  static const int maxTraits = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExistingData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  void _loadExistingData() {
    final draft = ref.read(profileCreationProvider);
    if (draft.traits != null) {
      setState(() {
        _selectedTraits.addAll(draft.traits!);
      });
    }
    if (draft.starSign != null) {
      setState(() {
        _selectedStarSign = draft.starSign!.field;
        _showStarSign = draft.starSign!.visible;
      });
    }
  }

  void _toggleTrait(Trait trait) {
    setState(() {
      if (_selectedTraits.contains(trait)) {
        _selectedTraits.remove(trait);
      } else {
        if (_selectedTraits.length < maxTraits) {
          _selectedTraits.add(trait);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Maximum $maxTraits traits allowed'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
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
      traits: _selectedTraits.toList(),
      starSign: _selectedStarSign != null
          ? DisplayableField(field: _selectedStarSign, visible: _showStarSign)
          : DisplayableField(field: null, visible: false),
    );
    await ref.read(profileCreationProvider.notifier).updateDraft(updatedDraft);

    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/submit');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _selectedTraits.length >= minTraits &&
        _selectedTraits.length <= maxTraits;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Personality Traits'),
            Tab(text: 'Star Sign'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
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

                  // Search bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search traits...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Selection count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedTraits.length}/$maxTraits selected',
                        style: TextStyle(
                          color: canContinue ? AppColors.primary : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_selectedTraits.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedTraits.clear();
                            });
                          },
                          child: const Text('Clear all'),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTraitsGrid(),
                  _buildStarSignSelector(),
                ],
              ),
            ),

            // Bottom bar
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
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
                    SizedBox(
                      height: 60,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _selectedTraits.map((trait) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(trait.displayName),
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () => _toggleTrait(trait),
                              labelStyle: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
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

  Widget _buildTraitsGrid() {
    // Filter by search query
    final filteredTraits = _searchQuery.isEmpty
        ? Trait.values
        : Trait.values
            .where((t) => t.displayName.toLowerCase().contains(_searchQuery))
            .toList();

    if (filteredTraits.isEmpty) {
      return Center(
        child: Text(
          'No traits found',
          style: TextStyle(color: Colors.grey[600]),
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
      itemCount: filteredTraits.length,
      itemBuilder: (context, index) {
        final trait = filteredTraits[index];
        final isSelected = _selectedTraits.contains(trait);
        final isMaxed = _selectedTraits.length >= maxTraits && !isSelected;

        return InkWell(
          onTap: isMaxed ? null : () => _toggleTrait(trait),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : isMaxed
                      ? Colors.grey[200]
                      : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                trait.displayName,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStarSignSelector() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Text(
          'What\'s your star sign?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Optional - skip if you prefer',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2,
          ),
          itemCount: StarSign.values.length,
          itemBuilder: (context, index) {
            final sign = StarSign.values[index];
            final isSelected = _selectedStarSign == sign;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedStarSign = isSelected ? null : sign;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    sign.displayName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
        ),
        if (_selectedStarSign != null) ...[
          const SizedBox(height: 24),
          CheckboxListTile(
            value: _showStarSign,
            onChanged: (value) => setState(() => _showStarSign = value ?? true),
            title: const Text('Show on my profile'),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }
}
