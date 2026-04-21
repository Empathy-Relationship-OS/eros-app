import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';

/// Screen for selecting a caption for a photo
/// Based on: screenshots/users/create-profile/80DC933A-0EDC-479E-BEE5-443A0174135A.png
/// Note: For now using dummy data, will be replaced with backend enum values later
class CaptionSelectionScreen extends StatefulWidget {
  final String? currentCaption;

  const CaptionSelectionScreen({
    super.key,
    this.currentCaption,
  });

  @override
  State<CaptionSelectionScreen> createState() => _CaptionSelectionScreenState();
}

class _CaptionSelectionScreenState extends State<CaptionSelectionScreen> {
  String? _selectedCaption;

  // Dummy captions for now - will be replaced with backend enum
  static const List<String> _availableCaptions = [
    'Living my best life',
    'Adventure time',
    'Feeling good',
    'Weekend vibes',
    'Making memories',
    'Happy moments',
    'Chasing dreams',
    'Summer days',
    'Good times',
    'Life is beautiful',
    'Explore more',
    'Stay positive',
    'Smile always',
    'Be yourself',
    'Love life',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCaption = widget.currentCaption;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Select caption',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Save button
          TextButton(
            onPressed: _selectedCaption != null
                ? () => Navigator.of(context).pop(_selectedCaption)
                : null,
            child: Text(
              'Save',
              style: TextStyle(
                color: _selectedCaption != null
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: _availableCaptions.length,
          itemBuilder: (context, index) {
            final caption = _availableCaptions[index];
            final isSelected = _selectedCaption == caption;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCaption = caption;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          caption,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
