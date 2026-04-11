# Profile Creation Feature - Implementation Status

## Overview
The profile creation journey has been scaffolded with a robust architecture that supports the multi-step flow described in `screenshots/Screenshot_Catalogue.md`. The implementation follows clean architecture principles with feature-first organization.

## ✅ Completed

### 1. Domain Layer
All backend enums and models have been created with full parity to the Kotlin backend:

**Enums** (`lib/features/profile/domain/enums/`):
- `gender.dart` - Gender identity (MALE, FEMALE, NON_BINARY, OTHER)
- `preferences.dart` - All preference enums:
  - DateIntentions, KidsPreference, AlcoholConsumption, SmokingStatus
  - EducationLevel, RelationshipType, SexualOrientation, Pronouns
  - Religion, PoliticalView, Diet, Ethnicity
  - BrainAttribute, BodyAttribute
- `interests.dart` - Hobby/interest categories:
  - Sport (50+ options), FoodAndDrink (28 options)
  - Creative (16 options), Entertainment (24 options)
  - MusicGenre (33 options), Activity (27 options)
  - Interest (28 options)
- `personality.dart` - Trait (43 options) and StarSign (12 options)
- `questions.dart` - PredefinedQuestion (42+ questions across 4 categories)

**Models** (`lib/features/profile/domain/models/`):
- `displayable_field.dart` - Wrapper for fields with visibility control
- `create_user_request.dart` - Final request model with validation
- `profile_creation_draft.dart` - Draft model for progressive data collection

**Barrel Export** (`lib/features/profile/domain/profile_domain.dart`):
- Single import point for all domain types

### 2. Data Layer
**Service** (`lib/features/profile/data/services/`):
- `profile_creation_service.dart` - SharedPreferences persistence
  - Save/load draft data
  - Survive app restarts
  - Clear on completion

### 3. Presentation Layer
**Providers** (`lib/features/profile/presentation/providers/`):
- `profile_creation_provider.dart` - Riverpod state management
  - `profileCreationProvider` - StateNotifier for draft
  - `profileCreationServiceProvider` - Service instance
  - Auto-loads draft on app start

**Example Screens** (`lib/features/profile/presentation/screens/`):
- `name_input_screen.dart` - Text input pattern (step 1/11)
- `height_input_screen.dart` - Unit conversion pattern (step 8/11)

### 4. Core Utilities
**Validation** (`lib/core/utils/validators.dart`):
- ✅ Email validation with regex
- ✅ SQL injection prevention (sanitizeInput)
- ✅ XSS prevention (HTML/script tag removal)
- ✅ Name validation
- ✅ Age validation (18-120)
- ✅ Height validation (3-9 ft)

## 🚧 Remaining Work

### Screens to Implement
Based on `screenshots/Screenshot_Catalogue.md`, the following screens need to be created following the established patterns:

**Basic Info Section** (11 screens total):
1. ✅ Name input - `name_input_screen.dart`
2. ⏳ Location input - with GPS/manual entry
3. ⏳ Dating cities selector - multi-select from API results
4. ⏳ Gender identity - single select with "Other" text input
5. ⏳ Gender preference - multi-select (who they want to date)
6. ⏳ Date of birth - DD/MM/YYYY with validation
7. ⏳ Languages spoken - multi-select with sign language option
8. ✅ Height input - `height_input_screen.dart`
9. ⏳ How found us - single select with "Other" text input
10. ⏳ Email - with marketing consent checkbox
11. ⏳ Terms & Conditions - legal agreement with user's name

**Profile Preferences Section** (6 screens):
12. ⏳ Date intentions - DateIntentions enum
13. ⏳ Kids preference - KidsPreference enum
14. ⏳ Alcohol consumption - AlcoholConsumption enum
15. ⏳ Smoking status - SmokingStatus enum
16. ⏳ Education level - EducationLevel enum
17. ⏳ Job and study - Text inputs

**Interests Section** (1 multi-tab screen):
18. ⏳ Interests selector
    - Sports, Food & Drink, Creative, Entertainment, Music, Activities, Interests
    - Min 5, Max 10 selections total
    - Search functionality

**Personality Section** (1 multi-tab screen):
19. ⏳ Traits selector
    - Personality Traits, Star Sign
    - Min 3, Max 10 selections
    - Selected items shown at top

**Q&A Section** (1 screen):
20. ⏳ Q&A selector
    - 4 tabs: Fun, Ambitions, Interests, Personal
    - Min 1, Max 3 Q&A pairs
    - 150 char max per answer

**Photos Section** (2 screens):
21. ⏳ Photo upload - Min 3, Max 6 photos
22. ⏳ Preview & confirmation - Final review before submission

### Navigation & Routes
The app uses **named routes** for navigation. Routes need to be defined in `main.dart`:

```dart
'/profile-creation/name': (context) => const NameInputScreen(),
'/profile-creation/location': (context) => const LocationInputScreen(),
'/profile-creation/dating-cities': (context) => const DatingCitiesScreen(),
// ... etc
```

### API Integration
When ready to submit, implement:
- `POST /users` - Create user profile (use `CreateUserRequest.toJson()`)
- Photo upload flow:
  1. `POST /users/me/photos/presigned-url` - Get S3 presigned URL
  2. `PUT <presigned-url>` - Upload directly to S3
  3. `POST /users/me/photos` - Confirm upload with photoKey

## Architecture Patterns

### Screen Structure
All screens follow this pattern:

```dart
class SomeInputScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<SomeInputScreen> createState() => _SomeInputScreenState();
}

class _SomeInputScreenState extends ConsumerState<SomeInputScreen> {
  // 1. Form key and controllers
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _loadExistingData(); // Load from draft
    _controller.addListener(_validateForm);
  }

  void _loadExistingData() {
    final draft = ref.read(profileCreationProvider);
    // Populate controllers from draft
  }

  void _validateForm() {
    setState(() {
      _isValid = _formKey.currentState?.validate() ?? false;
    });
  }

  Future<void> _continue() async {
    // Save to draft
    await ref.read(profileCreationProvider.notifier).updateFields(...);

    // Navigate to next screen
    Navigator.pushNamed(context, '/next-route');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildProgressBar(step, totalSteps),
          // ... form fields
          ElevatedButton(onPressed: _isValid ? _continue : null),
        ],
      ),
    );
  }
}
```

### State Management Flow
1. User fills form → validates
2. On continue → save to `ProfileCreationDraft` via provider
3. Provider automatically persists to SharedPreferences
4. Navigate to next screen
5. Next screen loads draft and populates fields
6. Repeat until all fields collected
7. Final screen converts draft to `CreateUserRequest` and submits

### Validation Best Practices
- Use `Validators.sanitizeInput()` on all text inputs before saving
- Validate on every keystroke (via controller listener)
- Disable "Continue" button until valid
- Show inline error messages via `TextFormField.validator`

## Next Steps (Prioritized)

1. **Implement remaining basic info screens** (9 screens)
   - Start with location, gender, DOB as they're required fields
   - Use existing screens as templates

2. **Set up navigation routes** in `main.dart`
   - Define all routes upfront
   - Consider using `go_router` for better navigation management

3. **Implement preferences section** (6 screens)
   - These are simpler - mostly single/multi-select from enums

4. **Implement interests & personality** (2 complex screens)
   - Multi-tab selectors with search
   - Enforce min/max constraints

5. **Implement Q&A** (1 screen)
   - Tab-based question selection
   - Text input for answers

6. **Implement photos** (2 screens)
   - Image picker integration
   - S3 presigned URL upload flow

7. **API integration**
   - Create repository in `features/profile/data/repositories/`
   - Implement error handling
   - Show loading states

8. **Testing**
   - Widget tests for each screen
   - Integration test for full flow
   - Test draft persistence

## Files Created

```
lib/features/profile/
├── domain/
│   ├── enums/
│   │   ├── gender.dart
│   │   ├── interests.dart
│   │   ├── personality.dart
│   │   ├── preferences.dart
│   │   └── questions.dart
│   ├── models/
│   │   ├── create_user_request.dart
│   │   ├── displayable_field.dart
│   │   └── profile_creation_draft.dart
│   └── profile_domain.dart (barrel file)
├── data/
│   └── services/
│       └── profile_creation_service.dart
└── presentation/
    ├── providers/
    │   └── profile_creation_provider.dart
    └── screens/
        ├── name_input_screen.dart
        └── height_input_screen.dart
```

## Design Tokens (from CLAUDE.md)

**Colors**:
- Primary: Warm orange (from logo)
- Background: White
- Text: Black
- Disabled: Grey[300]

**Spacing**:
- Screen padding: 24px
- Section spacing: 32px
- Input spacing: 16px

**Components**:
- Input fields: 12px border radius, 2px focus border
- Buttons: 28px border radius, 56px height
- Progress bar: 8px height, 4px border radius

## Questions for User

1. Should we implement a "Skip" option for optional fields?
2. Should there be a "Save as draft" explicit button, or just auto-save on navigation?
3. For location - should we integrate a specific maps SDK or use a simpler geocoding API?
4. Photo upload - should we allow cropping/editing in-app?
5. Should there be a final "Review all" screen before submission?

---

**Last Updated**: Profile creation foundation complete. Ready to implement remaining screens.
