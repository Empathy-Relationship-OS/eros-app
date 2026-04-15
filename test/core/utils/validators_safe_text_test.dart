import 'package:flutter_test/flutter_test.dart';
import 'package:eros_app/core/utils/validators.dart';

void main() {
  group('Validators.isSafeText', () {
    test('should allow normal text with punctuation', () {
      expect(Validators.isSafeText('I love hiking, traveling, and good food!'), true);
      expect(Validators.isSafeText("I'm a software engineer who loves coding."), true);
      expect(Validators.isSafeText('My favorite quote is: "Be yourself"'), true);
      expect(Validators.isSafeText('I enjoy reading (especially sci-fi novels).'), true);
      expect(Validators.isSafeText('Contact me at: user@example.com'), true);
      expect(Validators.isSafeText('I like 50% dark chocolate & coffee'), true);
      expect(Validators.isSafeText('Price range: \$10-\$20'), true);
    });

    test('should allow text with special characters for lists', () {
      expect(Validators.isSafeText('My hobbies: {reading, coding, gaming}'), true);
      expect(Validators.isSafeText('Languages: [English, Spanish, French]'), true);
    });

    test('should block SQL injection attempts', () {
      expect(Validators.isSafeText('DROP TABLE users'), false);
      expect(Validators.isSafeText('DELETE FROM accounts'), false);
      expect(Validators.isSafeText('INSERT INTO users VALUES'), false);
      expect(Validators.isSafeText('UPDATE users SET password'), false);
      expect(Validators.isSafeText('SELECT * FROM users'), false);
      expect(Validators.isSafeText('UNION SELECT password'), false);
      expect(Validators.isSafeText('Some text -- '), false);
      expect(Validators.isSafeText('Test /* comment */ text'), false);
    });

    test('should block XSS attempts', () {
      expect(Validators.isSafeText('<script>alert("xss")</script>'), false);
      expect(Validators.isSafeText('<script src="malicious.js">'), false);
      expect(Validators.isSafeText('javascript:alert(1)'), false);
      expect(Validators.isSafeText('<img onclick="alert(1)">'), false);
      expect(Validators.isSafeText('<div onload="malicious()">'), false);
    });

    test('should allow SQL keywords in normal context', () {
      // These should pass because they're not in SQL injection patterns
      expect(Validators.isSafeText('I want to select a restaurant'), true);
      expect(Validators.isSafeText('Please delete my spam folder'), true);
      expect(Validators.isSafeText('I need to update my profile'), true);
      expect(Validators.isSafeText('Let me insert a joke here'), true);
    });

    test('should handle empty and whitespace strings', () {
      expect(Validators.isSafeText(''), true);
      expect(Validators.isSafeText('   '), true);
      expect(Validators.isSafeText('\n\t'), true);
    });

    test('should allow emojis and unicode', () {
      expect(Validators.isSafeText('I love coding! 💻🚀'), true);
      expect(Validators.isSafeText('Café, naïve, résumé'), true);
      expect(Validators.isSafeText('你好世界'), true);
    });
  });
}
