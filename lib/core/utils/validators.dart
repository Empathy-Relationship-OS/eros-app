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

  /// Check if text is safe (no SQL injection or XSS attempts)
  /// This is a more lenient check that allows common punctuation
  /// but blocks actual SQL injection and script tags
  static bool isSafeText(String text) {
    // Block obvious SQL injection patterns (multiple dangerous keywords together)
    final dangerousPatterns = [
      RegExp(r'\bDROP\s+TABLE\b', caseSensitive: false),
      RegExp(r'\bDELETE\s+FROM\b', caseSensitive: false),
      RegExp(r'\bINSERT\s+INTO\b', caseSensitive: false),
      RegExp(r'\bUPDATE\s+\w+\s+SET\b', caseSensitive: false), // UPDATE tablename SET
      RegExp(r'\bSELECT\s+.+\s+FROM\b', caseSensitive: false),
      RegExp(r'\bUNION\s+SELECT\b', caseSensitive: false),
      RegExp(r'--\s*$', caseSensitive: false), // SQL comment at end
      RegExp(r'/\*|\*/', caseSensitive: false), // SQL block comments
      RegExp(r'<script[^>]*>', caseSensitive: false), // Script tags
      RegExp(r'javascript:', caseSensitive: false), // JavaScript protocol
      RegExp(r'on\w+\s*=', caseSensitive: false), // Event handlers like onclick=
    ];

    for (final pattern in dangerousPatterns) {
      if (pattern.hasMatch(text)) {
        return false;
      }
    }

    return true;
  }

  /// Sanitize text input to prevent SQL injection and XSS
  static String sanitizeInput(String input) {
    // Remove potential SQL injection characters
    String sanitized = input
        .replaceAll(';', '')
        .replaceAll("'", '')
        .replaceAll('"', '')
        .replaceAll('\\', '')
        .replaceAll('--', '')
        .replaceAll('/*', '')
        .replaceAll('*/', '');

    // Remove HTML/script tags for XSS prevention
    sanitized = sanitized
        .replaceAll(RegExp(r'<script.*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<.*?>'), '');

    return sanitized.trim();
  }

  /// Validate text input with length constraints
  static String? validateText(
    String? value, {
    int? minLength,
    int? maxLength,
    String? fieldName,
  }) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'Field'} is required';
    }

    final sanitized = sanitizeInput(value);

    if (minLength != null && sanitized.length < minLength) {
      return '${fieldName ?? 'Field'} must be at least $minLength characters';
    }

    if (maxLength != null && sanitized.length > maxLength) {
      return '${fieldName ?? 'Field'} must not exceed $maxLength characters';
    }

    return null;
  }

  /// Validate name input
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }

    final sanitized = sanitizeInput(value);

    if (sanitized.length < 2) {
      return 'Name must be at least 2 characters';
    }

    if (sanitized.length > 50) {
      return 'Name must not exceed 50 characters';
    }

    // Check if name contains only letters, spaces, hyphens, and apostrophes
    if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(sanitized)) {
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
