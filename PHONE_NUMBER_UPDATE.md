# Phone Number Screen Update

## Summary
Replaced the email input screen (step 9/11) with a phone number input screen to improve UX. Users no longer need to enter their email twice since it's already collected during Firebase authentication.

## Changes Made

### 1. New Phone Number Screen
**File**: `lib/features/profile/presentation/screens/phone_number_input_screen.dart`

**Features**:
- Auto-populates from Firebase Auth if user authenticated with phone
- Manual input with validation (10-15 digits)
- Progress bar shows step 9 of 11
- Formats: Accepts international formats with country codes
- Auto-saves email from Firebase in the background
- Helper text guides users to include country code (e.g., +1 for US)

**Validation**:
- Requires 10-15 digits (international phone number range)
- Allows formatting characters: spaces, hyphens, parentheses, plus sign
- Shows helpful error messages

### 2. Profile Model Updates
**File**: `lib/features/profile/domain/models/profile_creation_draft.dart`

**Added**:
- `String? phoneNumber` field for storing phone number
- JSON serialization/deserialization support
- copyWith method support

**Note**: Phone number is stored in draft but NOT sent to backend yet (future enhancement)

### 3. Provider Updates
**File**: `lib/features/profile/presentation/providers/profile_creation_provider.dart`

**Updated**:
- `updateFields()` method now accepts `phoneNumber` parameter
- Persists phone number to SharedPreferences

### 4. Routing Updates
**File**: `lib/main.dart`

**Changed**:
- Replaced `EmailScreen` import with `PhoneNumberInputScreen`
- Route `/profile-creation/email` → `/profile-creation/phone`

**File**: `lib/features/profile/presentation/screens/education_screen.dart`

**Updated**:
- Navigation target changed from `/profile-creation/email` to `/profile-creation/phone`

## User Flow

**Step 9 (NEW)**: Phone Number
- User sees phone number screen
- If authenticated via phone: auto-populated from Firebase
- If authenticated via email: manual entry required
- Email is silently pulled from Firebase and saved to draft
- User proceeds to step 10 (Terms & Conditions)

## Backend Integration (Future)

The phone number field is:
- ✅ Stored in profile draft
- ✅ Persisted to local storage
- ❌ NOT sent to backend yet

When backend API is updated to accept phone numbers:
1. Add `phoneNumber` field to `CreateUserRequest` model
2. Update `toCreateUserRequest()` method in `ProfileCreationDraft`
3. Update backend API to accept phone number in `POST /users`

## UX Improvements

### Before
1. User signs up with email via Firebase
2. User fills profile...
3. **Step 9**: User must re-enter the same email ❌

### After
1. User signs up with email/phone via Firebase
2. User fills profile...
3. **Step 9**: User enters phone number (email auto-saved) ✅

## Email Handling

Email is now handled automatically:
- Pulled from `FirebaseAuth.instance.currentUser.email`
- Saved to draft in background when phone screen continues
- No user interaction required
- Still satisfies backend requirement for email field

## Testing

```bash
# Verify no analysis issues
flutter analyze lib/features/profile/presentation/screens/phone_number_input_screen.dart

# Test the flow
# 1. Navigate to /profile-creation/education
# 2. Select education level and continue
# 3. Should navigate to phone number screen
# 4. Enter phone number (or see auto-populated if from Firebase)
# 5. Continue to terms screen
```

## Files Modified

1. ✅ `lib/features/profile/presentation/screens/phone_number_input_screen.dart` (new)
2. ✅ `lib/features/profile/domain/models/profile_creation_draft.dart`
3. ✅ `lib/features/profile/presentation/providers/profile_creation_provider.dart`
4. ✅ `lib/main.dart`
5. ✅ `lib/features/profile/presentation/screens/education_screen.dart`

## Removed Files

- `lib/features/profile/presentation/screens/email_screen.dart` can be deleted (no longer used)

## Migration Notes

Existing users with saved drafts:
- Old drafts will still load correctly
- `phoneNumber` field will be `null` for existing drafts
- Users will need to enter phone number when they reach that screen
- Email will be auto-populated from Firebase if available

---

**Status**: Complete ✅
**Breaking Changes**: None (backwards compatible with existing drafts)
**Backend Changes Required**: Future enhancement
