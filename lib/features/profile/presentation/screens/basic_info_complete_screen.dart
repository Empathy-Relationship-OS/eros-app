import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

/// Screen shown after basic info is complete
/// Shows progress and next steps (preferences, interests, Q&A, photos)
class BasicInfoCompleteScreen extends ConsumerWidget {
  const BasicInfoCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(profileCreationProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                size: 100,
                color: AppColors.primary,
              ),
              const SizedBox(height: 32),
              Text(
                'Great start, ${draft.firstName}!',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'You\'ve completed the basic information.\nNext, we\'ll help you create your full profile.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _buildProgressItem(
                Icons.check_circle,
                'Basic Info',
                'Complete',
                true,
              ),
              const SizedBox(height: 16),
              _buildProgressItem(
                Icons.favorite_border,
                'Preferences',
                'Next',
                false,
              ),
              const SizedBox(height: 16),
              _buildProgressItem(
                Icons.interests,
                'Interests & Personality',
                'Coming up',
                false,
              ),
              const SizedBox(height: 16),
              _buildProgressItem(
                Icons.question_answer,
                'Q&A',
                'Coming up',
                false,
              ),
              const SizedBox(height: 16),
              _buildProgressItem(
                Icons.photo_camera,
                'Photos',
                'Final step',
                false,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/profile-creation/preferences/date-intentions');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Continue to Preferences',
                    style: TextStyle(
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
      ),
    );
  }

  Widget _buildProgressItem(IconData icon, String title, String status, bool isComplete) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isComplete ? AppColors.primary.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComplete ? AppColors.primary : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isComplete ? AppColors.primary : Colors.grey[400],
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isComplete ? AppColors.primary : Colors.black,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (isComplete)
            Icon(
              Icons.check,
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }
}
