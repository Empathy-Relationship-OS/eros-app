import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/domain/models/create_user_request.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/legal/domain/consent_required.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';
import 'package:eros_app/features/legal/presentation/legal_routes.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_copy.dart';
import 'package:eros_app/features/legal/presentation/providers/legal_documents_provider.dart';
import 'package:eros_app/features/legal/presentation/providers/signup_consents_provider.dart';
import 'package:eros_app/features/match_preferences/domain/models/filter_patch.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preferences_provider.dart';
import 'package:eros_app/features/legal/data/repositories/age_signal_repository.dart';
import 'package:eros_app/features/legal/presentation/providers/age_signal_providers.dart';
import 'package:eros_app/features/legal/presentation/screens/underage_screen.dart';

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
      // Optional (RFC-010): null when the user skipped the phone step.
      phoneNumber: draft.phoneNumber,
      // Optional (RFC-009 CF-F6): what the store said before the date of birth step.
      ageSignal: _ageCheck(userId)?.signal,

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
      diet: draft.diet ?? DisplayableField(field: null, visible: false),
      pronouns: draft.pronouns ?? DisplayableField(field: null, visible: false),
      starSign: draft.starSign ?? DisplayableField(field: null, visible: false),
      ethnicity: draft.ethnicity ?? DisplayableField(field: [], visible: false),
      brainAttributes: draft.brainAttributes ?? DisplayableField(field: null, visible: false),
      brainDescription: draft.brainDescription ?? DisplayableField(field: null, visible: false),
      bodyAttributes: draft.bodyAttributes ?? DisplayableField(field: null, visible: false),
      bodyDescription: draft.bodyDescription ?? DisplayableField(field: null, visible: false),
      // Every consent given at sign-up, each on the version shown (RFC-009 §5.2). Marketing is
      // among them when ticked.
      consents: ref.read(signupConsentsProvider).toRequest(),
    );
  }

  /// The store check from before the date of birth step, if it was for this user.
  SignupAgeCheck? _ageCheck(String userId) {
    final check = ref.read(signupAgeCheckProvider);
    return check?.uid == userId ? check : null;
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
      field: RelationshipType.monogamous,
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
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Build request
      final request = _buildCreateUserRequest(user.uid);

      // Submit to backend
      final repository = ref.read(profileRepositoryProvider);
      await repository.createUser(request);
      // The consents are on the server now, with the profile.
      await ref.read(signupConsentsProvider.notifier).clear();

      // Sign-up sent the store's answer, so the next launch doesn't ask again (CF-F6).
      if (_ageCheck(user.uid) != null) {
        await ExistingUserAgeSignal.markAskedIn(ref.read(sharedPreferencesProvider), user.uid);
      }

      await _saveInterestedIn();

      // Navigate to Q&A section (user account is now created)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile created! Now let\'s add some Q&A'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to Q&A section (replace current route)
        Navigator.pushReplacementNamed(context, '/profile-creation/qa');
      }
    } on ConsentRequiredException catch (e) {
      final step = LegalRoutes.stepFor(e.missing);
      if (step != null) {
        _backToConsentStep(e.missing, step);
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorMessage = LegalCopy.updateToSignUp;
      });
    } on UnderageSignUpException {
      // The backend's 403 `UNDERAGE` (RFC-009 CF-B12): nothing was created.
      if (mounted) UnderageScreen.show(context);
    } on ProfileValidationException catch (e) {
      if (e.namesField('phoneNumber')) {
        _backToPhoneStep();
        return;
      }
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

  /// The backend refused the phone number: back to the phone step, which says why (RFC-010).
  /// The draft keeps everything else, so the user walks the later steps again with them filled.
  void _backToPhoneStep() {
    ref.read(phoneNumberRejectedProvider.notifier).state = true;
    if (!mounted) return;
    var found = false;
    Navigator.of(context).popUntil((route) {
      found = route.settings.name == phoneStepRoute;
      return found || route.isFirst;
    });
    if (!found) Navigator.of(context).pushNamed(phoneStepRoute);
  }

  /// The backend wants [missing] agreed to again (400 `CONSENT_REQUIRED`): forget them, reload
  /// the current documents, and go back to [step], the first step that takes one of them.
  void _backToConsentStep(List<DocumentKind> missing, String step) {
    ref.read(signupConsentsProvider.notifier).forget(missing);
    ref.read(consentsToReviewProvider.notifier).state = missing.toSet();
    ref.invalidate(legalDocumentsForCityProvider);
    if (!mounted) return;
    LegalRoutes.returnTo(context, step);
  }

  /// The phone step's route (`main.dart`).
  static const phoneStepRoute = '/profile-creation/phone';

  /// Saves the Interested in step's choice now that the user exists (RFC-007 §4.9). A failure
  /// doesn't hold up sign-up: the Matches tab asks again when `GET /match/` returns 409.
  Future<void> _saveInterestedIn() async {
    final genders = ref.read(profileCreationProvider).interestedIn;
    if (genders == null || genders.isEmpty) return;
    try {
      await ref.read(matchPreferencesProvider.notifier).save(GenderPatch(genders));
    } catch (e) {
      // The type only: the message could hold the choice, which is private (RFC-007 D-9).
      debugPrint('Warning: Failed to save Interested in (${e.runtimeType})');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ] else if (_errorMessage != null) ...[
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: AppColors.error,
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
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.input),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.error,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                  AppButton(label: 'Try Again', onPressed: _submit),
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
