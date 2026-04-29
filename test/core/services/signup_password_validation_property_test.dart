import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/services/signup_validation_service.dart';
import 'dart:math';

/// Property-based tests for SignupValidationService - Password Validation
/// 
/// Feature: scholify-roadmap-tracker
/// Task: 3.4
/// 
/// This test suite validates:
/// - Property 13: Signup password length validation
/// 
/// Requirements: B1.8

void main() {
  late SignupValidationService validationService;

  setUp(() {
    validationService = SignupValidationService();
  });

  group('Property 13: Signup password length validation', () {
    /// **Validates: Requirements B1.8**
    /// 
    /// For any string input as password, the signup form SHALL accept it if and only if
    /// its length is at least 8 characters.
    test('password validation accepts passwords with length >= 8', () {
      const numIterations = 1000;
      final random = Random(42); // Fixed seed for reproducibility
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate random password with various characteristics
        final password = _generateRandomPassword(random);
        
        // Validate password
        final isValid = validationService.validatePassword(password);
        
        // Calculate expected result: length >= 8
        final expectedValid = password.length >= 8;
        
        // Assert: validation result matches expected
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Password validation failed for password of length ${password.length}',
        );
      }
    });

    test('passwords with exactly 8 characters are accepted (boundary)', () {
      const numIterations = 100;
      final random = Random(100);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate password with exactly 8 characters
        final password = _generatePasswordOfLength(random, 8);
        
        // Validate
        final isValid = validationService.validatePassword(password);
        
        // Assert: should be accepted (boundary case)
        expect(
          isValid,
          isTrue,
          reason: 'Password with exactly 8 characters should be accepted: "$password"',
        );
        
        // Verify length
        expect(password.length, equals(8));
      }
    });

    test('passwords with exactly 7 characters are rejected (boundary)', () {
      const numIterations = 100;
      final random = Random(200);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate password with exactly 7 characters
        final password = _generatePasswordOfLength(random, 7);
        
        // Validate
        final isValid = validationService.validatePassword(password);
        
        // Assert: should be rejected (boundary case)
        expect(
          isValid,
          isFalse,
          reason: 'Password with exactly 7 characters should be rejected: "$password"',
        );
        
        // Verify length
        expect(password.length, equals(7));
      }
    });

    test('empty passwords are rejected', () {
      const numIterations = 10;
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Empty password
        final password = '';
        
        // Validate
        final isValid = validationService.validatePassword(password);
        
        // Assert: should be rejected
        expect(
          isValid,
          isFalse,
          reason: 'Empty password should be rejected',
        );
      }
    });

    test('very short passwords (1-7 chars) are rejected', () {
      const numIterations = 100;
      final random = Random(300);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate password with length 1-7
        final length = random.nextInt(7) + 1; // 1 to 7
        final password = _generatePasswordOfLength(random, length);
        
        // Validate
        final isValid = validationService.validatePassword(password);
        
        // Assert: should be rejected
        expect(
          isValid,
          isFalse,
          reason: 'Password with length $length should be rejected: "$password"',
        );
        
        // Verify length
        expect(password.length, equals(length));
      }
    });

    test('passwords with length >= 8 are accepted', () {
      const numIterations = 100;
      final random = Random(400);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate password with length 8-100
        final length = random.nextInt(93) + 8; // 8 to 100
        final password = _generatePasswordOfLength(random, length);
        
        // Validate
        final isValid = validationService.validatePassword(password);
        
        // Assert: should be accepted
        expect(
          isValid,
          isTrue,
          reason: 'Password with length $length should be accepted: "$password"',
        );
        
        // Verify length
        expect(password.length, equals(length));
      }
    });

    test('very long passwords are accepted', () {
      const numIterations = 50;
      final random = Random(500);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate very long password (100-1000 characters)
        final length = 100 + random.nextInt(900);
        final password = _generatePasswordOfLength(random, length);
        
        // Validate
        final isValid = validationService.validatePassword(password);
        
        // Assert: should be accepted
        expect(
          isValid,
          isTrue,
          reason: 'Very long password (length $length) should be accepted',
        );
        
        // Verify length
        expect(password.length, equals(length));
      }
    });

    test('passwords with special characters are validated by length only', () {
      const numIterations = 100;
      final random = Random(600);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate password with special characters
        final password = _generatePasswordWithSpecialChars(random);
        
        // Validate
        final isValid = validationService.validatePassword(password);
        
        // Calculate expected result based on length only
        final expectedValid = password.length >= 8;
        
        // Assert: validation is based on length only, not character content
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Password with special characters should be validated by length only: '
              '"$password" (length: ${password.length})',
        );
      }
    });

    test('passwords with Unicode characters are validated by length', () {
      const numIterations = 100;
      final random = Random(700);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate password with Unicode characters
        final password = _generatePasswordWithUnicode(random);
        
        // Validate
        final isValid = validationService.validatePassword(password);
        
        // Calculate expected result based on length
        final expectedValid = password.length >= 8;
        
        // Assert: validation is based on length
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Password with Unicode should be validated by length: '
              '"$password" (length: ${password.length})',
        );
      }
    });

    test('passwords with whitespace are validated by length', () {
      const numIterations = 100;
      final random = Random(800);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate password with whitespace
        final password = _generatePasswordWithWhitespace(random);
        
        // Validate
        final isValid = validationService.validatePassword(password);
        
        // Calculate expected result based on length
        final expectedValid = password.length >= 8;
        
        // Assert: validation is based on length (whitespace counts)
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Password with whitespace should be validated by length: '
              '"$password" (length: ${password.length})',
        );
      }
    });

    test('password validation is deterministic', () {
      const numIterations = 100;
      final random = Random(900);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final password = _generateRandomPassword(random);
        
        // Validate multiple times
        final result1 = validationService.validatePassword(password);
        final result2 = validationService.validatePassword(password);
        final result3 = validationService.validatePassword(password);
        
        // Assert: all results are identical (deterministic)
        expect(
          result1,
          equals(result2),
          reason: 'Validation should be deterministic for: "$password"',
        );
        expect(
          result2,
          equals(result3),
          reason: 'Validation should be deterministic for: "$password"',
        );
      }
    });

    test('edge case password lengths are handled correctly', () {
      final testCases = [
        ('', false),                    // Empty
        ('a', false),                   // Length 1
        ('ab', false),                  // Length 2
        ('abc', false),                 // Length 3
        ('abcd', false),                // Length 4
        ('abcde', false),               // Length 5
        ('abcdef', false),              // Length 6
        ('abcdefg', false),             // Length 7 (boundary - rejected)
        ('abcdefgh', true),             // Length 8 (boundary - accepted)
        ('abcdefghi', true),            // Length 9
        ('abcdefghij', true),           // Length 10
        ('12345678', true),             // Length 8 (numbers)
        ('!@#\$%^&*', true),            // Length 8 (special chars)
        ('        ', true),             // Length 8 (spaces)
        ('Pass123!', true),             // Length 8 (mixed)
        ('VeryLongPasswordWith50Characters12345678901234', true), // Length 50
      ];
      
      for (final testCase in testCases) {
        final password = testCase.$1;
        final expectedValid = testCase.$2;
        
        final isValid = validationService.validatePassword(password);
        
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Password validation failed for: "$password" (length: ${password.length})',
        );
      }
    });

    test('password validation only checks length, not content', () {
      // Passwords with various content but same length should have same validation result
      final testCases = [
        // All length 8 - should all be accepted
        ('12345678', true),
        ('abcdefgh', true),
        ('ABCDEFGH', true),
        ('!@#\$%^&*', true),
        ('        ', true),
        ('Pass123!', true),
        ('пароль12', true), // Cyrillic + numbers
        ('密码密码密码密码', true), // Chinese characters
        
        // All length 7 - should all be rejected
        ('1234567', false),
        ('abcdefg', false),
        ('ABCDEFG', false),
        ('!@#\$%^&', false),
        ('       ', false),
        ('Pass123', false),
        ('пароль1', false),
        ('密码密码密码密', false),
      ];
      
      for (final testCase in testCases) {
        final password = testCase.$1;
        final expectedValid = testCase.$2;
        
        final isValid = validationService.validatePassword(password);
        
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Password validation should only check length for: "$password" '
              '(length: ${password.length})',
        );
      }
    });

    test('metamorphic property: adding characters to invalid password makes it valid', () {
      const numIterations = 100;
      final random = Random(1000);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate short password (1-7 characters)
        final shortLength = random.nextInt(7) + 1;
        final shortPassword = _generatePasswordOfLength(random, shortLength);
        
        // Validate short password (should be invalid)
        final shortIsValid = validationService.validatePassword(shortPassword);
        expect(shortIsValid, isFalse);
        
        // Add characters to make it at least 8 characters
        final charsToAdd = 8 - shortLength;
        final additionalChars = _generatePasswordOfLength(random, charsToAdd);
        final longPassword = shortPassword + additionalChars;
        
        // Validate long password (should be valid)
        final longIsValid = validationService.validatePassword(longPassword);
        
        // Assert: adding characters to reach length 8 makes it valid
        expect(
          longIsValid,
          isTrue,
          reason: 'Adding $charsToAdd characters to "$shortPassword" should make it valid: "$longPassword"',
        );
        expect(longPassword.length, greaterThanOrEqualTo(8));
      }
    });

    test('metamorphic property: removing characters from valid password can make it invalid', () {
      const numIterations = 100;
      final random = Random(1100);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate valid password (8-20 characters)
        final longLength = random.nextInt(13) + 8; // 8 to 20
        final longPassword = _generatePasswordOfLength(random, longLength);
        
        // Validate long password (should be valid)
        final longIsValid = validationService.validatePassword(longPassword);
        expect(longIsValid, isTrue);
        
        // Remove characters to make it less than 8 characters
        final charsToRemove = random.nextInt(longLength - 1) + 1;
        final newLength = longLength - charsToRemove;
        final shortPassword = longPassword.substring(0, newLength);
        
        // Validate short password
        final shortIsValid = validationService.validatePassword(shortPassword);
        
        // Calculate expected result
        final expectedValid = newLength >= 8;
        
        // Assert: validation matches expected based on new length
        expect(
          shortIsValid,
          equals(expectedValid),
          reason: 'Removing $charsToRemove characters from "$longPassword" (length $longLength) '
              'to get "$shortPassword" (length $newLength) should result in valid=$expectedValid',
        );
      }
    });

    test('comprehensive random password generation covers all length ranges', () {
      const numIterations = 1000;
      final random = Random(1200);
      
      final lengthDistribution = <int, int>{};
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final password = _generateRandomPassword(random);
        final length = password.length;
        
        lengthDistribution[length] = (lengthDistribution[length] ?? 0) + 1;
        
        // Validate
        final isValid = validationService.validatePassword(password);
        final expectedValid = length >= 8;
        
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Password validation failed for length $length',
        );
      }
      
      // Verify we generated passwords across different length ranges
      final hasShort = lengthDistribution.keys.any((len) => len < 8);
      final hasBoundary = lengthDistribution.keys.any((len) => len == 7 || len == 8);
      final hasLong = lengthDistribution.keys.any((len) => len > 8);
      
      expect(hasShort, isTrue, reason: 'Should generate some short passwords');
      expect(hasBoundary, isTrue, reason: 'Should generate boundary case passwords');
      expect(hasLong, isTrue, reason: 'Should generate some long passwords');
    });
  });
}

// ── Helper Functions ──────────────────────────────────────────────────────

/// Generates a random password with various characteristics
String _generateRandomPassword(Random random) {
  final type = random.nextInt(10);
  
  switch (type) {
    case 0:
      // Empty string
      return '';
    case 1:
      // Very short (1-3 characters)
      return _generatePasswordOfLength(random, random.nextInt(3) + 1);
    case 2:
      // Short (4-7 characters) - below threshold
      return _generatePasswordOfLength(random, random.nextInt(4) + 4);
    case 3:
      // Exactly 7 characters (boundary - invalid)
      return _generatePasswordOfLength(random, 7);
    case 4:
      // Exactly 8 characters (boundary - valid)
      return _generatePasswordOfLength(random, 8);
    case 5:
      // Medium (9-20 characters)
      return _generatePasswordOfLength(random, random.nextInt(12) + 9);
    case 6:
      // Long (21-50 characters)
      return _generatePasswordOfLength(random, random.nextInt(30) + 21);
    case 7:
      // With special characters
      return _generatePasswordWithSpecialChars(random);
    case 8:
      // With Unicode
      return _generatePasswordWithUnicode(random);
    case 9:
      // With whitespace
      return _generatePasswordWithWhitespace(random);
    default:
      return 'password';
  }
}

/// Generates a password of exact length
String _generatePasswordOfLength(Random random, int length) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
}

/// Generates a password with special characters
String _generatePasswordWithSpecialChars(Random random) {
  const specialChars = '!@#\$%^&*()_+-=[]{}|;:,.<>?/~`';
  const alphanumeric = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  
  // Random length between 0 and 20
  final length = random.nextInt(21);
  
  return List.generate(length, (_) {
    if (random.nextBool()) {
      return specialChars[random.nextInt(specialChars.length)];
    } else {
      return alphanumeric[random.nextInt(alphanumeric.length)];
    }
  }).join();
}

/// Generates a password with Unicode characters
String _generatePasswordWithUnicode(Random random) {
  final unicodeStrings = [
    'пароль',      // Russian
    'パスワード',    // Japanese
    '密码',        // Chinese
    'كلمة السر',   // Arabic
    'mot de passe', // French
    'contraseña',  // Spanish
    'Passwort',    // German
    'senha',       // Portuguese
    '암호',        // Korean
    'รหัสผ่าน',    // Thai
  ];
  
  // Pick a random Unicode string
  final base = unicodeStrings[random.nextInt(unicodeStrings.length)];
  
  // Optionally add more characters
  if (random.nextBool()) {
    final extra = _generatePasswordOfLength(random, random.nextInt(10));
    return base + extra;
  }
  
  return base;
}

/// Generates a password with whitespace
String _generatePasswordWithWhitespace(Random random) {
  // Random length between 0 and 20
  final length = random.nextInt(21);
  
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 \t\n';
  return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
}
