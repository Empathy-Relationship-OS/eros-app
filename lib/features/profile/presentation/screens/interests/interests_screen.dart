import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/domain/enums/interests.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

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
  final Set<String> _selectedInterests = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const int minSelections = 5;
  static const int maxSelections = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadExistingData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  void _loadExistingData() {
    final draft = ref.read(profileCreationProvider);
    if (draft.interests != null) {
      setState(() {
        _selectedInterests.addAll(draft.interests!);
      });
    }
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        if (_selectedInterests.length < maxSelections) {
          _selectedInterests.add(interest);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Maximum $maxSelections interests allowed'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
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
      interests: _selectedInterests.toList(),
    );
    await ref.read(profileCreationProvider.notifier).updateDraft(updatedDraft);

    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/personality');
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
    final canContinue = _selectedInterests.length >= minSelections &&
        _selectedInterests.length <= maxSelections;

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
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Sports'),
            Tab(text: 'Food & Drink'),
            Tab(text: 'Creative'),
            Tab(text: 'Entertainment'),
            Tab(text: 'Music'),
            Tab(text: 'Activities'),
            Tab(text: 'Interests'),
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
                    'What are you into?',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select $minSelections-$maxSelections interests',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Search bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search interests...',
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
                        '${_selectedInterests.length}/$maxSelections selected',
                        style: TextStyle(
                          color: canContinue ? AppColors.primary : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_selectedInterests.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedInterests.clear();
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
                  _buildInterestGrid(Sport.values.map((e) => e.displayName).toList()),
                  _buildInterestGrid(FoodAndDrink.values.map((e) => e.displayName).toList()),
                  _buildInterestGrid(Creative.values.map((e) => e.displayName).toList()),
                  _buildInterestGrid(Entertainment.values.map((e) => e.displayName).toList()),
                  _buildInterestGrid(MusicGenre.values.map((e) => e.displayName).toList()),
                  _buildInterestGrid(Activity.values.map((e) => e.displayName).toList()),
                  _buildInterestGrid(Interest.values.map((e) => e.displayName).toList()),
                ],
              ),
            ),

            // Bottom bar with selected items and continue button
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
                  // Selected interests chips
                  if (_selectedInterests.isNotEmpty) ...[
                    SizedBox(
                      height: 60,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _selectedInterests.map((interest) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(interest),
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () => _toggleInterest(interest),
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
                            : 'Select ${minSelections - _selectedInterests.length} more',
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

  Widget _buildInterestGrid(List<String> interests) {
    // Filter by search query
    final filteredInterests = _searchQuery.isEmpty
        ? interests
        : interests
            .where((i) => i.toLowerCase().contains(_searchQuery))
            .toList();

    if (filteredInterests.isEmpty) {
      return Center(
        child: Text(
          'No interests found',
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
      itemCount: filteredInterests.length,
      itemBuilder: (context, index) {
        final interest = filteredInterests[index];
        final isSelected = _selectedInterests.contains(interest);
        final isMaxed = _selectedInterests.length >= maxSelections && !isSelected;

        return InkWell(
          onTap: isMaxed ? null : () => _toggleInterest(interest),
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
                color: isSelected
                    ? AppColors.primary
                    : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                interest,
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
}
