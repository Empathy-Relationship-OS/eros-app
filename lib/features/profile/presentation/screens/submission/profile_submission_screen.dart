import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/domain/models/create_user_request.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_repository_provider.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';

/// Profile submission screen - final step before creating user
class ProfileSubmissionScreen extends ConsumerStatefulWidget {
  const ProfileSubmissionScreen({super.key});

  @override
  ConsumerState<ProfileSubmissionScreen> createState() =>
      _ProfileSubmissionScreenState();
}

class _ProfileSubmissionScreenState
    extends ConsumerState<ProfileSubmissionScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Auto-submit when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _submit();
    });
  }

  /// Convert draft to CreateUserRequest with all required defaults
  CreateUserRequest _buildCreateUserRequest(String userId) {
    final draft = ref.read(profileCreationProvider);

    // Validate required fields
    if (draft.firstName == null ||
        draft.lastName == null ||
        draft.email == null ||
        draft.heightCm == null ||
        draft.dateOfBirth == null ||
        draft.city == null ||
        draft.coordinatesLatitude == null ||
        draft.coordinatesLongitude == null ||
        draft.gender == null ||
        draft.educationLevel == null ||
        draft.preferredLanguage == null ||
        draft.spokenLanguages == null ||
        draft.interests == null ||
        draft.traits == null) {
      throw StateError('Profile draft is incomplete. Missing required fields.');
    }

    return CreateUserRequest(
      userId: userId,
      firstName: draft.firstName!,
      lastName: draft.lastName!,
      email: draft.email!,
      heightCm: draft.heightCm!,
      dateOfBirth: draft.dateOfBirth!,
      city: draft.city!,
      educationLevel: draft.educationLevel!,
      gender: draft.gender!,
      preferredLanguage: draft.preferredLanguage!,
      coordinatesLatitude: draft.coordinatesLatitude!,
      coordinatesLongitude: draft.coordinatesLongitude!,
      interests: draft.interests!,
      traits: draft.traits!,
      occupation: draft.occupation,
      bio: draft.bio ?? '',

      // Collected DisplayableFields
      spokenLanguages: draft.spokenLanguages!,
      dateIntentions: draft.dateIntentions ?? _defaultDateIntentions(),
      kidsPreference: draft.kidsPreference ?? _defaultKidsPreference(),
      alcoholConsumption: draft.alcoholConsumption ?? _defaultAlcoholConsumption(),
      smokingStatus: draft.smokingStatus ?? _defaultSmokingStatus(),
      relationshipType: draft.relationshipType ?? _defaultRelationshipType(),
      sexualOrientation: draft.sexualOrientation ?? _defaultSexualOrientation(),

      // Optional DisplayableFields with defaults
      religion: draft.religion ?? DisplayableField(field: null, visible: false),
      politicalView: draft.politicalView ?? DisplayableField(field: null, visible: false),
      diet: draft.diet ?? DisplayableField(field: null, visible: false),
      pronouns: draft.pronouns ?? DisplayableField(field: null, visible: false),
      starSign: draft.starSign ?? DisplayableField(field: null, visible: false),
      ethnicity: draft.ethnicity ?? DisplayableField(field: [], visible: false),
      brainAttributes: draft.brainAttributes ?? DisplayableField(field: null, visible: false),
      brainDescription: draft.brainDescription ?? DisplayableField(field: null, visible: false),
      bodyAttributes: draft.bodyAttributes ?? DisplayableField(field: null, visible: false),
      bodyDescription: draft.bodyDescription ?? DisplayableField(field: null, visible: false),
    );
  }

  // Default values for missing preferences
  DisplayableField<DateIntentions> _defaultDateIntentions() {
    return DisplayableField(
      field: DateIntentions.notSure,
      visible: false,
    );
  }

  DisplayableField<KidsPreference> _defaultKidsPreference() {
    return DisplayableField(
      field: KidsPreference.preferNotToSay,
      visible: false,
    );
  }

  DisplayableField<AlcoholConsumption?> _defaultAlcoholConsumption() {
    return DisplayableField(
      field: AlcoholConsumption.preferNotToSay,
      visible: false,
    );
  }

  DisplayableField<SmokingStatus?> _defaultSmokingStatus() {
    return DisplayableField(
      field: SmokingStatus.preferNotToSay,
      visible: false,
    );
  }

  DisplayableField<RelationshipType> _defaultRelationshipType() {
    return DisplayableField(
      field: RelationshipType.preferNotToSay,
      visible: false,
    );
  }

  DisplayableField<SexualOrientation> _defaultSexualOrientation() {
    return DisplayableField(
      field: SexualOrientation.preferNotToSay,
      visible: false,
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Get Firebase user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Build request
      final request = _buildCreateUserRequest(user.uid);

      // Submit to backend
      final repository = ref.read(profileRepositoryProvider);
      await repository.createUser(request);

      // Clear draft on success
      await ref.read(profileCreationProvider.notifier).clearDraft();

      // Navigate to main app
      if (mounted) {
        // TODO: Navigate to main app home screen
        // For now, show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile created successfully! 🎉'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Pop back to welcome or show success screen
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ProfileValidationException catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.getUserMessage();
      });
    } on ProfileRepositoryException catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'An unexpected error occurred: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSubmitting) ...[
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Creating your profile...',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This will only take a moment',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ] else if (_errorMessage != null) ...[
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Oops! Something went wrong',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[900]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        'Try Again',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
