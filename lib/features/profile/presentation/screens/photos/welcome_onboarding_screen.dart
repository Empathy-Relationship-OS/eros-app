import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';

/// Welcome/Onboarding screen shown after profile is complete
/// Based on Screenshot_Catalogue.md line 659-663
/// Final screen before user enters the main app (Match tab)
class WelcomeOnboardingScreen extends StatelessWidget {
  const WelcomeOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Success icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 70,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 40),

              // Welcome message
              const Text(
                'You\'re all set!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                'Your profile is live and we\'re finding your perfect matches.',
                style: const TextStyle(
                  fontSize: 18,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Features list
              _FeatureItem(
                icon: Icons.favorite_border,
                title: 'Quality Matches',
                description: 'Receive up to 21 curated matches per day',
              ),
              const SizedBox(height: 24),
              _FeatureItem(
                icon: Icons.schedule,
                title: 'Daily Batches',
                description: 'New matches delivered 3 times daily',
              ),
              const SizedBox(height: 24),
              _FeatureItem(
                icon: Icons.local_cafe,
                title: 'Real Dates',
                description: 'Skip the small talk, meet in person',
              ),

              const Spacer(),

              // Start dating button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _handleStartDating(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Start dating',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Helpful tip
              Text(
                'Your first batch will be ready soon!',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleStartDating(BuildContext context) {
    // Navigate to main app - Match tab
    // TODO: Replace with actual main app route/navigation
    // For now, we'll use a placeholder route
    // In production, this would likely use Navigator.pushAndRemoveUntil
    // to clear the entire profile creation stack
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/match', // Main app route
      (route) => false, // Remove all previous routes
    );
  }
}

/// Feature item widget
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 28,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
