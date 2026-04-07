import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/language_selector_button.dart';
import 'auth_method_selection_screen.dart';

/// Welcome Screen - Opening page of the app
/// Shows logo, "Start Dating" button, and language selector
/// Reference: screenshots/login/create-user/8BA764E5-5619-47B6-BB51-C270658D3C33_1_105_c.jpeg
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Language Selector Button (top right)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: LanguageSelectorButton(),
                ),
              ),

              // Spacer to center logo
              const Spacer(flex: 2),

              // Logo
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/logo.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // App Name
              Text(
                'Eros',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: AppColors.primaryOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // Tagline
              Text(
                'Skip the small talk,\ngo straight to the date',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),

              // Spacer to push button to bottom
              const Spacer(flex: 3),

              // Start Dating Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AuthMethodSelectionScreen(),
                      ),
                    );
                  },
                  child: const Text('Start Dating'),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
