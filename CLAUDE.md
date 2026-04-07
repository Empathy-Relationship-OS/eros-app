# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Eros** is a Flutter-based dating application focused on preventing small talk and facilitating actual dates. The app shows a limited number of matches per day at predefined times, handles location-based date planning, and includes a deposit system to ensure commitment to scheduled dates.

### Core User Flow
1. **Profile Setup**: Users create profiles with photos, preferences, interests, and Q&A responses
2. **Daily Matching**: Users receive up to 7 matches per batch (3 batches/day, 21 total matches)
3. **Match Actions**: Users like or pass on profiles
4. **Date Scheduling**: Matched users put down deposits and agree on availability
5. **Location Selection**: App determines optimal venue based on activity and user locations
6. **Date Confirmation**: Users confirm attendance on the day; cancellations result in lost deposits and temporary bans

## Commands

### Development
```bash
# Run the app
flutter run

# Run on specific device
flutter run -d <device_id>

# Hot reload during development (in running app)
# Press 'r' in terminal

# Hot restart (full restart)
# Press 'R' in terminal
```

### Testing
```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run a specific test file
flutter test test/widget_test.dart
```

### Code Quality
```bash
# Analyze code
flutter analyze

# Format code
flutter format .

# Check for outdated dependencies
flutter pub outdated
```

### Build
```bash
# Build for Android
flutter build apk
flutter build appbundle  # For Play Store

# Build for iOS
flutter build ios
flutter build ipa  # For App Store
```

### Dependencies
```bash
# Get dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade
```

## Architecture

### Current State
This is a **greenfield Flutter project** - currently only has the default Flutter counter app. The entire application needs to be built from scratch following the specifications below.

### Planned Architecture

#### Feature-First Structure
```
lib/
├── core/                    # Shared utilities, constants, themes
│   ├── theme/              # App theme (orange/white/black color scheme)
│   ├── constants/          # App-wide constants, enums
│   ├── utils/              # Validators, formatters, helpers
│   └── network/            # API client, interceptors
├── features/
│   ├── auth/               # Firebase authentication, OTP verification
│   │   ├── data/          # Repositories, data sources
│   │   ├── domain/        # Entities, use cases
│   │   └── presentation/  # Screens, widgets, state management
│   ├── profile/           # User profile creation and management
│   ├── matching/          # Daily batches, match actions, last 24 hours
│   ├── dates/             # Date scheduling, venue selection, confirmations
│   ├── preferences/       # Dating preferences, activity preferences
│   └── photos/            # Photo upload with S3 presigned URLs
└── main.dart
```

#### State Management
Use **Riverpod** for state management throughout the app. Consider:
- `StateNotifier` for complex feature state
- `FutureProvider` for async data fetching
- `StreamProvider` for real-time updates
- `StateProvider` for simple state

#### API Integration
- Base URL: `http://localhost:8080` (dev) or `https://api.eros.app` (prod)
- Authentication: Firebase Authentication with ID tokens in `Authorization: Bearer <token>` header
- All endpoints require authentication except `/` health check
- Rate limiting: 3 batches per day, token bucket system (100 capacity, 10s refill)

### Key Backend Endpoints
Reference `openapi/documentation.yaml` for complete API specification:

**User Management**
- `POST /users` - Create user profile
- `GET /users/me` - Get current user
- `PATCH /users/me` - Update profile
- `GET /users/id/{id}/public` - Get public profile

**Photos** (S3 Direct Upload)
- `POST /users/me/photos/presigned-url` - Get upload URL
- `POST /users/me/photos` - Confirm upload
- `DELETE /users/me/photos/{photoId}` - Delete photo

**Matching**
- `GET /match/` - Fetch daily batch (up to 7 matches)
- `PATCH /match/action/{matchId}` - Like or pass
- `GET /match/last-24` - Get last 24 hours of passes

**Q&A**
- `POST /users/qa/me/collection` - Create/update Q&A collection
- `GET /users/qa/me` - Get user's Q&As

## Design System

### Color Scheme
Based on `screenshots/logo/eros_discord_icon.jpg`:
- **Primary**: Warm orange tones
- **Background**: White
- **Text**: Black
- Replace any purple/red tones from reference screenshots with orange

### UI/UX Guidelines
- Reference designs in `screenshots/` directory
- See `screenshots/Screenshot_Catalogue.md` for detailed screen-by-screen breakdown
- All screenshots show skeleton/wireframe - implement with Eros branding
- No need to replicate decorative background drawings; use solid backgrounds instead

### Key UI Patterns
- **Progress Bars**: Show current step in multi-step flows (profile creation, onboarding)
- **Input Validation**: All text inputs must validate against SQL injection, XSS attacks
- **Character Limits**: Enforce limits (bio: 500 chars, Q&A answers: 150 chars, etc.)
- **Image Requirements**: 3-6 photos required, first is primary/thumbnail
- **Selection Chips**: Show selected state with dark/grey background
- **Binary Actions**: Use clear paired buttons (Like/Pass, Continue/Back)

## Domain Models & Enums

### Core Enums (must sync with backend)
Reference `screenshots/Screenshot_Catalogue.md` lines 141-619 for complete enum definitions:

**Gender & Preferences**
- `Gender`: MALE, FEMALE, NON_BINARY, OTHER
- `GenderPreference`: Array of Gender values

**Profile Attributes**
- `DateIntentions`: CASUAL_DATING, SERIOUS_DATING, FRIENDSHIP, NETWORKING, NOT_SURE
- `KidsPreference`: WANT_KIDS, DONT_WANT_KIDS, HAVE_KIDS, OPEN_TO_KIDS, PREFER_NOT_TO_SAY
- `AlcoholConsumption`: NEVER, SOMETIMES, REGULARLY, PREFER_NOT_TO_SAY
- `SmokingStatus`: NEVER, SOMETIMES, REGULARLY, QUITTING, PREFER_NOT_TO_SAY
- `EducationLevel`: COLLEGE, UNIVERSITY, APPRENTICESHIP, PREFER_NOT_TO_SAY

**Interests** (stored as `List<String>`)
- `Sport`: 50+ values (KICK_BOXING, GOLF, TENNIS, YOGA, etc.)
- `FoodAndDrink`: 28 values (BBQ, SUSHI, WINE, COFFEE, etc.)
- `Creative`: 16 values (PHOTOGRAPHY, PAINTING, WRITING, etc.)
- `Entertainment`: 24 values (READING, GAMING, NETFLIX, PODCASTS, etc.)
- `MusicGenre`: 33 values (JAZZ, HIPHOP, TECHNO, CLASSICAL_MUSIC, etc.)
- `Activity`: 27 values (HIKING, FESTIVALS, ESCAPE_ROOMS, etc.)
- `Interest`: 28 values (AI, FINANCE, PHILOSOPHY, SUSTAINABILITY, etc.)

**Personality**
- `Trait`: 43 values (ADVENTUROUS, AMBITIOUS, CREATIVE, EMPATHETIC, etc.)
- `StarSign`: ARIES through PISCES

**Questions**
- `PredefinedQuestion`: 42+ questions across 4 categories (Fun, Ambitions, Interests, Personal)
  - Each has a `getDisplayText()` method for UI rendering

## Security & Validation

### Input Validation Requirements
- **SQL Injection Prevention**: Sanitize all text inputs before submission
- **XSS Prevention**: Escape user-generated content in displays
- **Length Limits**: Enforce on all text fields (bio: 500, Q&A: 150, etc.)
- **Age Verification**: Only 18+ allowed (max 120 years)
- **Height Validation**: Min 3ft, Max 9ft
- **Email Validation**: Use proper regex for email format
- **Phone Validation**: OTP verification flow

### Data Privacy (GDPR-Conscious)
- Soft delete for user accounts (`PATCH /users/me` with status DELETED)
- User consent checkboxes for marketing emails
- Profile visibility controls (ACTIVE vs SLEEP_MODE status)

## Testing Strategy

### Widget Tests
- Test critical user journeys: onboarding, profile creation, matching flow
- Test form validation logic
- Test state transitions in Riverpod providers

### Integration Tests
- Test complete flows: sign up → profile creation → matching → date scheduling
- Test API integration with mock backend

### Golden Tests
- Capture visual regressions for key screens
- Test theme consistency across screens

## Key Implementation Notes

### Photo Upload Flow (S3 Direct Upload)
1. Request presigned URL: `POST /users/me/photos/presigned-url` with fileName and contentType
2. Upload directly to S3 using presigned URL (PUT request)
3. Confirm upload: `POST /users/me/photos` with photoKey
4. Backend verifies S3 object exists and saves metadata

### Matching Flow
- Users can fetch up to 3 batches per day
- Each batch contains up to 7 matches
- Actions (like/pass) trigger `PATCH /match/action/{matchId}`
- If mutual match, returns `MutualMatchInfo` with profile
- Last 24 hours feature allows reconsidering passes

### Date Commitment System
- Deposit required when accepting match
- 2-day window to decide on match
- Availability coordination with 2 retry attempts
- Cancellation within 24 hours = lost deposit + 1-day ban
- Location revealed 2 days before date
- 4-hour pre-date chat window with character/message limits

## Platform-Specific Considerations

### iOS
- Photo library permissions (Info.plist configuration)
- Push notifications (APNs setup)
- Deep linking for date confirmations

### Android
- Photo permissions (runtime permissions)
- FCM for push notifications
- Deep linking configuration

## Accessibility
- Ensure all interactive elements have semantic labels
- Support screen readers
- Minimum touch target size: 44x44 points
- Sufficient color contrast ratios

## You are a Senior Mobile Engineer

When working on this codebase, embody the expertise of a Senior Mobile Engineer with 15+ years in Flutter development for consumer social and dating platforms. Your approach should:

- **Ask clarifying questions** before implementing features to understand scope, design requirements, and technical constraints
- **Provide architectural guidance** at the Flutter layer before diving into implementation
- **Suggest industry-standard packages** (from pub.dev) with clear trade-off explanations
- **Consider performance**: Avoid jank, memory leaks, unnecessary rebuilds
- **Decompose widgets**: Keep widgets small, reusable, and testable
- **Think long-term**: Balance immediate functionality with maintainability
- **Apply SOLID principles** and clean architecture patterns
- **Flag GDPR/privacy concerns** relevant to a dating platform
- **Share real-world examples** and lessons learned from production apps

### Code Review Focus Areas
When reviewing or suggesting code, prioritize:
- Widget rebuild efficiency and jank-free rendering
- Memory management and disposal of resources
- Lazy loading for lists and images
- Accessibility and internationalization readiness
- Security considerations (data validation, secure storage)
- Testability and separation of concerns
