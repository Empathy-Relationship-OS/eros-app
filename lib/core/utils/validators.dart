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
}
