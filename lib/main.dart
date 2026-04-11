import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/welcome_screen.dart';
import 'features/profile/presentation/screens/name_input_screen.dart';
import 'features/profile/presentation/screens/location_input_screen.dart';
import 'features/profile/presentation/screens/dating_cities_screen.dart';
import 'features/profile/presentation/screens/gender_screen.dart';
import 'features/profile/presentation/screens/date_of_birth_screen.dart';
import 'features/profile/presentation/screens/languages_screen.dart';
import 'features/profile/presentation/screens/height_input_screen.dart';
import 'features/profile/presentation/screens/education_screen.dart';
import 'features/profile/presentation/screens/phone_number_input_screen.dart';
import 'features/profile/presentation/screens/terms_screen.dart';
import 'features/profile/presentation/screens/basic_info_complete_screen.dart';
import 'features/profile/presentation/screens/preferences/date_intentions_screen.dart';
import 'features/profile/presentation/screens/preferences/kids_preference_screen.dart';
import 'features/profile/presentation/screens/preferences/alcohol_screen.dart';
import 'features/profile/presentation/screens/preferences/smoking_screen.dart';
import 'features/profile/presentation/screens/preferences/occupation_screen.dart';
import 'features/profile/presentation/screens/preferences/relationship_type_screen.dart';
import 'features/profile/presentation/screens/preferences/sexual_orientation_screen.dart';
import 'features/profile/presentation/screens/preferences/preferences_complete_screen.dart';
import 'features/profile/presentation/screens/interests/interests_screen.dart';
import 'features/profile/presentation/screens/personality/personality_screen.dart';
import 'features/profile/presentation/screens/submission/profile_submission_screen.dart';
import 'features/profile/presentation/providers/profile_creation_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ProviderScope(
      overrides: [
        // Provide the initialized SharedPreferences instance
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const ErosApp(),
    ),
  );
}

class ErosApp extends StatelessWidget {
  const ErosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const WelcomeScreen(),
      routes: {
        // Profile creation routes - Basic Info Section
        '/profile-creation/name': (context) => const NameInputScreen(),
        '/profile-creation/location': (context) => const LocationInputScreen(),
        '/profile-creation/dating-cities': (context) => const DatingCitiesScreen(),
        '/profile-creation/gender': (context) => const GenderScreen(),
        '/profile-creation/dob': (context) => const DateOfBirthScreen(),
        '/profile-creation/languages': (context) => const LanguagesScreen(),
        '/profile-creation/height': (context) => const HeightInputScreen(),
        '/profile-creation/education': (context) => const EducationScreen(),
        '/profile-creation/phone': (context) => const PhoneNumberInputScreen(),
        '/profile-creation/terms': (context) => const TermsScreen(),
        '/profile-creation/complete-basic': (context) => const BasicInfoCompleteScreen(),

        // Profile creation routes - Preferences Section
        '/profile-creation/preferences/date-intentions': (context) => const DateIntentionsScreen(),
        '/profile-creation/preferences/kids': (context) => const KidsPreferenceScreen(),
        '/profile-creation/preferences/alcohol': (context) => const AlcoholScreen(),
        '/profile-creation/preferences/smoking': (context) => const SmokingScreen(),
        '/profile-creation/preferences/occupation': (context) => const OccupationScreen(),
        '/profile-creation/preferences/relationship-type': (context) => const RelationshipTypeScreen(),
        '/profile-creation/preferences/sexual-orientation': (context) => const SexualOrientationScreen(),
        '/profile-creation/preferences/complete': (context) => const PreferencesCompleteScreen(),

        // Profile creation routes - Interests & Personality
        '/profile-creation/interests': (context) => const InterestsScreen(),
        '/profile-creation/personality': (context) => const PersonalityScreen(),

        // Profile creation routes - Submission
        '/profile-creation/submit': (context) => const ProfileSubmissionScreen(),

        // TODO: Add routes for Q&A and photos sections (optional)
      },
    );
  }
}
