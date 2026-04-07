import 'package:flutter_test/flutter_test.dart';
import 'package:eros_app/core/utils/validators.dart';

void main() {
  group('Validators - Email Validation', () {
    test('isValidEmail returns true for valid email addresses', () {
      expect(Validators.isValidEmail('test@example.com'), true);
      expect(Validators.isValidEmail('user.name@example.co.uk'), true);
      expect(Validators.isValidEmail('test+tag@domain.com'), true);
      expect(Validators.isValidEmail('user_123@test-domain.org'), true);
    });

    test('isValidEmail returns false for invalid email addresses', () {
      expect(Validators.isValidEmail(''), false);
      expect(Validators.isValidEmail('notanemail'), false);
      expect(Validators.isValidEmail('@example.com'), false);
      expect(Validators.isValidEmail('test@'), false);
      expect(Validators.isValidEmail('test@.com'), false);
      expect(Validators.isValidEmail('test @example.com'), false);
      expect(Validators.isValidEmail('test@example'), false);
    });

    test('validateEmail returns null for valid emails', () {
      expect(Validators.validateEmail('test@example.com'), null);
      expect(Validators.validateEmail('user@domain.co.uk'), null);
    });

    test('validateEmail returns error message for invalid emails', () {
      expect(Validators.validateEmail(null), 'Email is required');
      expect(Validators.validateEmail(''), 'Email is required');
      expect(Validators.validateEmail('invalid'), 'Please enter a valid email address');
      expect(Validators.validateEmail('test@'), 'Please enter a valid email address');
    });
  });

  group('Validators - Input Sanitization', () {
    test('sanitizeInput removes SQL injection characters', () {
      expect(Validators.sanitizeInput("test'; DROP TABLE users;"), "test DROP TABLE users");
      expect(Validators.sanitizeInput('test" OR 1=1--'), "test OR 1=1");
      expect(Validators.sanitizeInput('test/* comment */'), "test comment");
      expect(Validators.sanitizeInput('test\\nvalue'), "testnvalue");
    });

    test('sanitizeInput removes XSS attack patterns', () {
      expect(
        Validators.sanitizeInput('<script>alert("XSS")</script>'),
        '',
      );
      expect(
        Validators.sanitizeInput('Hello <b>World</b>'),
        'Hello World',
      );
      expect(
        Validators.sanitizeInput('<img src=x onerror=alert(1)>'),
        '',
      );
    });

    test('sanitizeInput trims whitespace', () {
      expect(Validators.sanitizeInput('  test  '), 'test');
      expect(Validators.sanitizeInput('\ntest\n'), 'test');
    });

    test('sanitizeInput handles clean input correctly', () {
      expect(Validators.sanitizeInput('John Doe'), 'John Doe');
      expect(Validators.sanitizeInput('test123'), 'test123');
      expect(Validators.sanitizeInput('Hello World!'), 'Hello World!');
    });
  });

  group('Validators - Text Validation', () {
    test('validateText returns null for valid text', () {
      expect(
        Validators.validateText('Hello', minLength: 2, maxLength: 10),
        null,
      );
      expect(
        Validators.validateText('Test', fieldName: 'Name'),
        null,
      );
    });

    test('validateText returns error for empty text', () {
      expect(
        Validators.validateText(null),
        'Field is required',
      );
      expect(
        Validators.validateText(''),
        'Field is required',
      );
      expect(
        Validators.validateText(null, fieldName: 'Username'),
        'Username is required',
      );
    });

    test('validateText checks minimum length', () {
      expect(
        Validators.validateText('ab', minLength: 3),
        'Field must be at least 3 characters',
      );
      expect(
        Validators.validateText('a', minLength: 2, fieldName: 'Name'),
        'Name must be at least 2 characters',
      );
    });

    test('validateText checks maximum length', () {
      expect(
        Validators.validateText('12345678901', maxLength: 10),
        'Field must not exceed 10 characters',
      );
      expect(
        Validators.validateText('VeryLongName', maxLength: 5, fieldName: 'Name'),
        'Name must not exceed 5 characters',
      );
    });
  });

  group('Validators - Name Validation', () {
    test('validateName returns null for valid names', () {
      expect(Validators.validateName('John'), null);
      expect(Validators.validateName('Mary Jane'), null);
      expect(Validators.validateName("O'Brien"), null);
      expect(Validators.validateName('Anne-Marie'), null);
      expect(Validators.validateName('Jean-Luc'), null);
    });

    test('validateName returns error for invalid names', () {
      expect(Validators.validateName(null), 'Name is required');
      expect(Validators.validateName(''), 'Name is required');
      expect(Validators.validateName('A'), 'Name must be at least 2 characters');
    });

    test('validateName rejects names that are too long', () {
      final longName = 'A' * 51;
      expect(
        Validators.validateName(longName),
        'Name must not exceed 50 characters',
      );
    });

    test('validateName rejects names with invalid characters', () {
      expect(
        Validators.validateName('John123'),
        'Name can only contain letters, spaces, hyphens, and apostrophes',
      );
      expect(
        Validators.validateName('Test@Name'),
        'Name can only contain letters, spaces, hyphens, and apostrophes',
      );
      expect(
        Validators.validateName('Name!'),
        'Name can only contain letters, spaces, hyphens, and apostrophes',
      );
    });
  });

  group('Validators - Age Validation', () {
    test('validateAge returns null for valid ages', () {
      expect(Validators.validateAge(18), null);
      expect(Validators.validateAge(25), null);
      expect(Validators.validateAge(65), null);
      expect(Validators.validateAge(120), null);
    });

    test('validateAge returns error for null age', () {
      expect(Validators.validateAge(null), 'Age is required');
    });

    test('validateAge returns error for under 18', () {
      expect(Validators.validateAge(17), 'You must be at least 18 years old');
      expect(Validators.validateAge(10), 'You must be at least 18 years old');
      expect(Validators.validateAge(0), 'You must be at least 18 years old');
    });

    test('validateAge returns error for over 120', () {
      expect(Validators.validateAge(121), 'Please enter a valid age');
      expect(Validators.validateAge(150), 'Please enter a valid age');
    });
  });

  group('Validators - Height Validation', () {
    test('validateHeightFeet returns null for valid heights', () {
      expect(Validators.validateHeightFeet(3.0), null);
      expect(Validators.validateHeightFeet(5.5), null);
      expect(Validators.validateHeightFeet(6.2), null);
      expect(Validators.validateHeightFeet(9.0), null);
    });

    test('validateHeightFeet returns error for null height', () {
      expect(Validators.validateHeightFeet(null), 'Height is required');
    });

    test('validateHeightFeet returns error for too short', () {
      expect(
        Validators.validateHeightFeet(2.9),
        'Height must be at least 3 feet',
      );
      expect(
        Validators.validateHeightFeet(2.0),
        'Height must be at least 3 feet',
      );
    });

    test('validateHeightFeet returns error for too tall', () {
      expect(
        Validators.validateHeightFeet(9.1),
        'Height must not exceed 9 feet',
      );
      expect(
        Validators.validateHeightFeet(10.0),
        'Height must not exceed 9 feet',
      );
    });
  });

  group('Validators - OTP Validation', () {
    test('validateOTP returns null for valid OTP codes', () {
      expect(Validators.validateOTP('123456'), null);
      expect(Validators.validateOTP('000000'), null);
      expect(Validators.validateOTP('999999'), null);
    });

    test('validateOTP returns error for empty or null', () {
      expect(Validators.validateOTP(null), 'Verification code is required');
      expect(Validators.validateOTP(''), 'Verification code is required');
    });

    test('validateOTP returns error for wrong length', () {
      expect(
        Validators.validateOTP('12345'),
        'Verification code must be 6 digits',
      );
      expect(
        Validators.validateOTP('1234567'),
        'Verification code must be 6 digits',
      );
    });

    test('validateOTP returns error for non-numeric codes', () {
      expect(
        Validators.validateOTP('12345a'),
        'Verification code must contain only digits',
      );
      expect(
        Validators.validateOTP('abcdef'),
        'Verification code must contain only digits',
      );
      expect(
        Validators.validateOTP('12 456'),
        'Verification code must contain only digits',
      );
    });
  });
}
