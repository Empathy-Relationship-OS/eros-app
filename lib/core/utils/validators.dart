import 'package:eros_app/core/constants/user_text_limits.dart';
import 'package:eros_app/core/utils/user_text.dart';

/// Input validation utilities
class Validators {
  Validators._();

  /// Email validation regex
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Validate email format
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    return _emailRegex.hasMatch(email.trim());
  }

  /// Validate email and return error message if invalid
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!isValidEmail(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validate free text after cleaning it with [UserText.clean] (RFC-004 D-16). Lengths are
  /// counted in code points, as the backend counts them.
  static String? validateText(
    String? value, {
    int? minLength,
    int? maxLength,
    String? fieldName,
    bool multiline = false,
  }) {
    final name = fieldName ?? 'Field';
    final cleaned = UserText.clean(value ?? '', multiline: multiline);
    if (cleaned.isEmpty) {
      return '$name is required';
    }

    final length = UserText.length(cleaned);
    if (minLength != null && length < minLength) {
      return '$name must be at least $minLength characters';
    }

    if (maxLength != null && length > maxLength) {
      return '$name must not exceed $maxLength characters';
    }

    return null;
  }

  /// Letters from any script with their accents, spaces, hyphens, and straight and curly
  /// apostrophes.
  static final RegExp _nameCharacters = RegExp(r"^[\p{L}\p{M}\s\-'\u2019]+$", unicode: true);

  /// Validate a first or last name (RFC-004 D-16): at least 2 and at most
  /// [UserTextLimits.name] characters after cleaning, in any script.
  static String? validateName(String? value) {
    final cleaned = UserText.clean(value ?? '');
    if (cleaned.isEmpty) {
      return 'Name is required';
    }

    final length = UserText.length(cleaned);
    if (length < 2) {
      return 'Name must be at least 2 characters';
    }

    if (length > UserTextLimits.name) {
      return 'Name must not exceed ${UserTextLimits.name} characters';
    }

    if (!_nameCharacters.hasMatch(cleaned)) {
      return 'Name can only contain letters, spaces, hyphens, and apostrophes';
    }

    return null;
  }

  /// Validate age (18-120)
  static String? validateAge(int? age) {
    if (age == null) {
      return 'Age is required';
    }

    if (age < 18) {
      return 'You must be at least 18 years old';
    }

    if (age > 120) {
      return 'Please enter a valid age';
    }

    return null;
  }

  /// Validate height in feet (3-9 ft)
  static String? validateHeightFeet(double? height) {
    if (height == null) {
      return 'Height is required';
    }

    if (height < 3.0) {
      return 'Height must be at least 3 feet';
    }

    if (height > 9.0) {
      return 'Height must not exceed 9 feet';
    }

    return null;
  }

  /// Validate OTP code (6 digits)
  static String? validateOTP(String? value) {
    if (value == null || value.isEmpty) {
      return 'Verification code is required';
    }

    if (value.length != 6) {
      return 'Verification code must be 6 digits';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'Verification code must contain only digits';
    }

    return null;
  }

  /// Validate password (minimum 8 characters)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    return null;
  }

  /// Check password strength
  static PasswordStrength getPasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.none;
    if (password.length < 8) return PasswordStrength.weak;

    int strength = 0;

    // Check length
    if (password.length >= 12) strength++;

    // Check for lowercase
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;

    // Check for uppercase
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;

    // Check for numbers
    if (RegExp(r'\d').hasMatch(password)) strength++;

    // Check for special characters
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;

    if (strength <= 2) return PasswordStrength.weak;
    if (strength <= 3) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  /// Validate confirm password matches
  static String? validateConfirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }
}

/// Password strength enum
enum PasswordStrength {
  none,
  weak,
  medium,
  strong,
}
