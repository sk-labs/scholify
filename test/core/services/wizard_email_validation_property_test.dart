import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/services/wizard_validation_service.dart';
import 'package:drift/native.dart';
import 'dart:math';

/// Property-based tests for WizardValidationService email validation
/// 
/// Feature: scholify-roadmap-tracker
/// Task: 3.3 Write property test for wizard email validation
/// 
/// This test suite validates:
/// - Property 3: Wizard email validation
/// 
/// Requirements: H1.4

void main() {
  late AppLocalDatabase database;
  late WizardValidationService validationService;

  setUp(() {
    // Create in-memory database for testing
    database = AppLocalDatabase(executor: NativeDatabase.memory());
    
    // Create wizard validation service
    validationService = WizardValidationService(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Property 3: Wizard email validation', () {
    /// **Validates: Requirements H1.4**
    /// 
    /// For any string input as email, the wizard SHALL accept it if and only if
    /// it contains at least one @ character followed by at least one character
    /// (domain segment).
    test('wizard accepts emails with @ followed by at least one character', () {
      const numIterations = 1000;
      final random = Random(42); // Fixed seed for reproducibility
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate random email string with various characteristics
        final email = _generateRandomEmail(random);
        
        // Validate email
        final isValid = validationService.validateEmail(email);
        
        // Calculate expected result: contains @ followed by at least one character
        final atIndex = email.indexOf('@');
        final expectedValid = atIndex != -1 && atIndex < email.length - 1;
        
        // Assert: validation result matches expected
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Email validation failed for: "$email" '
              '(@ at index: $atIndex, length: ${email.length})',
        );
      }
    });

    test('emails without @ are rejected', () {
      const numIterations = 100;
      final random = Random(123);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate email without @ character
        final email = _generateEmailWithoutAt(random);
        
        // Validate
        final isValid = validationService.validateEmail(email);
        
        // Assert: should be rejected
        expect(
          isValid,
          isFalse,
          reason: 'Email without @ should be rejected: "$email"',
        );
      }
    });

    test('emails with @ but no domain segment are rejected', () {
      const numIterations = 100;
      final random = Random(456);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate email with @ at the end (no domain segment)
        final localPart = _generateLocalPart(random);
        final email = '$localPart@';
        
        // Validate
        final isValid = validationService.validateEmail(email);
        
        // Assert: should be rejected
        expect(
          isValid,
          isFalse,
          reason: 'Email with @ but no domain should be rejected: "$email"',
        );
      }
    });

    test('emails with @ followed by at least one character are accepted', () {
      const numIterations = 100;
      final random = Random(789);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate email with @ followed by at least one character
        final localPart = _generateLocalPart(random);
        final domainPart = _generateDomainPart(random);
        final email = '$localPart@$domainPart';
        
        // Validate
        final isValid = validationService.validateEmail(email);
        
        // Assert: should be accepted
        expect(
          isValid,
          isTrue,
          reason: 'Email with @ and domain should be accepted: "$email"',
        );
      }
    });

    test('multiple @ characters are handled correctly', () {
      const numIterations = 100;
      final random = Random(101112);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate email with multiple @ characters
        final email = _generateEmailWithMultipleAt(random);
        
        // Validate
        final isValid = validationService.validateEmail(email);
        
        // Calculate expected result: first @ must have at least one character after it
        final atIndex = email.indexOf('@');
        final expectedValid = atIndex != -1 && atIndex < email.length - 1;
        
        // Assert: validation handles multiple @ correctly
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Multiple @ handling failed for: "$email"',
        );
      }
    });

    test('special characters in email are handled correctly', () {
      const numIterations = 100;
      final random = Random(131415);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate email with special characters
        final email = _generateEmailWithSpecialChars(random);
        
        // Validate
        final isValid = validationService.validateEmail(email);
        
        // Calculate expected result
        final atIndex = email.indexOf('@');
        final expectedValid = atIndex != -1 && atIndex < email.length - 1;
        
        // Assert: special characters are handled correctly
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Special character handling failed for: "$email"',
        );
      }
    });

    test('empty and whitespace-only emails are rejected', () {
      const numIterations = 50;
      final random = Random(161718);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate empty or whitespace-only string
        final email = _generateEmptyOrWhitespace(random);
        
        // Validate
        final isValid = validationService.validateEmail(email);
        
        // Assert: should be rejected (no @ character)
        expect(
          isValid,
          isFalse,
          reason: 'Empty/whitespace email should be rejected: "$email"',
        );
      }
    });

    test('@ at the beginning with domain is accepted', () {
      const numIterations = 100;
      final random = Random(192021);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate email starting with @
        final domainPart = _generateDomainPart(random);
        final email = '@$domainPart';
        
        // Validate
        final isValid = validationService.validateEmail(email);
        
        // Assert: should be accepted (@ at index 0, followed by domain)
        expect(
          isValid,
          isTrue,
          reason: 'Email starting with @ should be accepted: "$email"',
        );
      }
    });

    test('very long emails are validated correctly', () {
      const numIterations = 100;
      final random = Random(222324);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate very long email (100-1000 characters)
        final localLength = 50 + random.nextInt(450);
        final domainLength = 50 + random.nextInt(450);
        final localPart = _generateLongString(random, localLength);
        final domainPart = _generateLongString(random, domainLength);
        final email = '$localPart@$domainPart';
        
        // Validate
        final isValid = validationService.validateEmail(email);
        
        // Assert: should be accepted (has @ followed by domain)
        expect(
          isValid,
          isTrue,
          reason: 'Long email should be accepted (length: ${email.length})',
        );
      }
    });

    test('validation is deterministic', () {
      const numIterations = 100;
      final random = Random(252627);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final email = _generateRandomEmail(random);
        
        // Validate multiple times
        final result1 = validationService.validateEmail(email);
        final result2 = validationService.validateEmail(email);
        final result3 = validationService.validateEmail(email);
        
        // Assert: all results are identical (deterministic)
        expect(
          result1,
          equals(result2),
          reason: 'Validation should be deterministic for: "$email"',
        );
        expect(
          result2,
          equals(result3),
          reason: 'Validation should be deterministic for: "$email"',
        );
      }
    });

    test('edge cases are handled correctly', () {
      // Test specific edge cases
      final testCases = [
        // (email, expectedValid)
        ('user@domain.com', true),           // Standard email
        ('user@domain', true),               // No TLD
        ('user@d', true),                    // Single char domain
        ('@domain', true),                   // No local part
        ('user@', false),                    // No domain
        ('@', false),                        // Only @
        ('', false),                         // Empty
        ('user', false),                     // No @
        ('user@@domain', true),              // Multiple @ (first @ has domain)
        ('user@domain@com', true),           // Multiple @ (first @ has domain)
        ('@', false),                        // Just @
        ('@@', true),                        // Two @ (first @ followed by second @)
        ('user@domain.co.uk', true),         // Multiple dots in domain
        ('user.name@domain.com', true),      // Dot in local part
        ('user+tag@domain.com', true),       // Plus in local part
        ('user_name@domain.com', true),      // Underscore in local part
        ('user-name@domain.com', true),      // Hyphen in local part
        ('123@456', true),                   // Numbers only
        ('user@domain.', true),              // Trailing dot
        ('.user@domain', true),              // Leading dot
        ('user..name@domain', true),         // Double dot
        ('user@domain..com', true),          // Double dot in domain
        ('user name@domain.com', true),      // Space in local part
        ('user@domain name.com', true),      // Space in domain
        ('user\t@domain', true),             // Tab before @
        ('user@\tdomain', true),             // Tab after @
        ('user\n@domain', true),             // Newline before @
        ('user@\ndomain', true),             // Newline after @
        ('user@', false),                    // @ at end
        ('a@b', true),                       // Minimal valid
        ('a@', false),                       // Minimal invalid
        ('@b', true),                        // @ at start with domain
      ];
      
      for (final testCase in testCases) {
        final email = testCase.$1;
        final expectedValid = testCase.$2;
        
        final isValid = validationService.validateEmail(email);
        
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Email validation failed for: "$email"',
        );
      }
    });

    test('Unicode characters in email are handled correctly', () {
      const numIterations = 100;
      final random = Random(282930);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate email with Unicode characters
        final email = _generateEmailWithUnicode(random);
        
        // Validate
        final isValid = validationService.validateEmail(email);
        
        // Calculate expected result
        final atIndex = email.indexOf('@');
        final expectedValid = atIndex != -1 && atIndex < email.length - 1;
        
        // Assert: Unicode is handled correctly
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Unicode handling failed for: "$email"',
        );
      }
    });

    test('boundary condition: @ at last position is rejected', () {
      const numIterations = 100;
      final random = Random(313233);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate string with @ at the end
        final prefix = _generateNonEmptyString(random);
        final email = '$prefix@';
        
        // Validate
        final isValid = validationService.validateEmail(email);
        
        // Assert: should be rejected (no character after @)
        expect(
          isValid,
          isFalse,
          reason: 'Email with @ at end should be rejected: "$email"',
        );
      }
    });

    test('boundary condition: @ at first position with domain is accepted', () {
      const numIterations = 100;
      final random = Random(343536);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate string with @ at the beginning
        final suffix = _generateNonEmptyString(random);
        final email = '@$suffix';
        
        // Validate
        final isValid = validationService.validateEmail(email);
        
        // Assert: should be accepted (@ followed by domain)
        expect(
          isValid,
          isTrue,
          reason: 'Email with @ at start should be accepted: "$email"',
        );
      }
    });

    test('metamorphic property: adding characters after @ maintains validity', () {
      const numIterations = 100;
      final random = Random(373839);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate base email with @ but no domain
        final localPart = _generateLocalPart(random);
        final baseEmail = '$localPart@';
        
        // Base email should be invalid
        final baseValid = validationService.validateEmail(baseEmail);
        expect(baseValid, isFalse);
        
        // Add domain part
        final domainPart = _generateNonEmptyString(random);
        final extendedEmail = '$baseEmail$domainPart';
        
        // Extended email should be valid
        final extendedValid = validationService.validateEmail(extendedEmail);
        expect(
          extendedValid,
          isTrue,
          reason: 'Adding domain should make email valid: "$baseEmail" -> "$extendedEmail"',
        );
      }
    });

    test('metamorphic property: removing characters after @ can invalidate', () {
      const numIterations = 100;
      final random = Random(404142);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate valid email
        final localPart = _generateLocalPart(random);
        final domainPart = _generateDomainPart(random);
        final validEmail = '$localPart@$domainPart';
        
        // Valid email should be accepted
        final validResult = validationService.validateEmail(validEmail);
        expect(validResult, isTrue);
        
        // Remove domain part (keep only @)
        final invalidEmail = '$localPart@';
        
        // Invalid email should be rejected
        final invalidResult = validationService.validateEmail(invalidEmail);
        expect(
          invalidResult,
          isFalse,
          reason: 'Removing domain should invalidate email: "$validEmail" -> "$invalidEmail"',
        );
      }
    });
  });
}

// ── Helper Functions ──────────────────────────────────────────────────────

/// Generates a random email string with various characteristics
String _generateRandomEmail(Random random) {
  final type = random.nextInt(10);
  
  switch (type) {
    case 0:
      // Empty string
      return '';
    case 1:
      // No @ character
      return _generateEmailWithoutAt(random);
    case 2:
      // @ at the end (no domain)
      return '${_generateLocalPart(random)}@';
    case 3:
    case 4:
    case 5:
      // Valid email
      return '${_generateLocalPart(random)}@${_generateDomainPart(random)}';
    case 6:
      // Multiple @ characters
      return _generateEmailWithMultipleAt(random);
    case 7:
      // Special characters
      return _generateEmailWithSpecialChars(random);
    case 8:
      // @ at the beginning
      return '@${_generateDomainPart(random)}';
    case 9:
      // Just @
      return '@';
    default:
      return 'user@domain.com';
  }
}

/// Generates an email without @ character
String _generateEmailWithoutAt(Random random) {
  final words = ['user', 'admin', 'test', 'email', 'name', 'john', 'jane'];
  final domains = ['domain', 'example', 'test', 'mail', 'com', 'org'];
  
  final word = words[random.nextInt(words.length)];
  final domain = domains[random.nextInt(domains.length)];
  
  return '$word$domain';
}

/// Generates a local part (before @) for an email
String _generateLocalPart(Random random) {
  final type = random.nextInt(5);
  
  switch (type) {
    case 0:
      // Simple name
      final names = ['user', 'admin', 'test', 'john', 'jane', 'info', 'contact'];
      return names[random.nextInt(names.length)];
    case 1:
      // Name with dot
      return 'user.name${random.nextInt(100)}';
    case 2:
      // Name with plus
      return 'user+tag${random.nextInt(100)}';
    case 3:
      // Name with underscore
      return 'user_name${random.nextInt(100)}';
    case 4:
      // Name with hyphen
      return 'user-name${random.nextInt(100)}';
    default:
      return 'user';
  }
}

/// Generates a domain part (after @) for an email
String _generateDomainPart(Random random) {
  final type = random.nextInt(5);
  
  switch (type) {
    case 0:
      // Simple domain
      final domains = ['domain', 'example', 'test', 'mail', 'company'];
      return domains[random.nextInt(domains.length)];
    case 1:
      // Domain with TLD
      final domains = ['domain.com', 'example.org', 'test.net', 'mail.io'];
      return domains[random.nextInt(domains.length)];
    case 2:
      // Domain with subdomain
      return 'mail.example.com';
    case 3:
      // Single character domain
      final chars = 'abcdefghijklmnopqrstuvwxyz';
      return chars[random.nextInt(chars.length)];
    case 4:
      // Domain with multiple dots
      return 'mail.example.co.uk';
    default:
      return 'domain.com';
  }
}

/// Generates an email with multiple @ characters
String _generateEmailWithMultipleAt(Random random) {
  final numAt = random.nextInt(3) + 2; // 2-4 @ characters
  final parts = List.generate(numAt + 1, (_) => _generateNonEmptyString(random));
  return parts.join('@');
}

/// Generates an email with special characters
String _generateEmailWithSpecialChars(Random random) {
  final specialChars = [
    'user!name@domain.com',
    'user#name@domain.com',
    'user\$name@domain.com',
    'user%name@domain.com',
    'user&name@domain.com',
    'user*name@domain.com',
    'user=name@domain.com',
    'user?name@domain.com',
    'user^name@domain.com',
    'user~name@domain.com',
    'user`name@domain.com',
    'user{name}@domain.com',
    'user[name]@domain.com',
    'user(name)@domain.com',
    'user<name>@domain.com',
    'user|name@domain.com',
    'user\\name@domain.com',
    'user/name@domain.com',
    'user:name@domain.com',
    'user;name@domain.com',
    'user,name@domain.com',
    'user name@domain.com',
    'user\tname@domain.com',
    'user\nname@domain.com',
  ];
  
  return specialChars[random.nextInt(specialChars.length)];
}

/// Generates an email with Unicode characters
String _generateEmailWithUnicode(Random random) {
  final unicodeEmails = [
    'user@domain.com',
    'üser@dömain.com',
    'user@dömäin.com',
    'ユーザー@ドメイン.com',
    'пользователь@домен.com',
    'مستخدم@نطاق.com',
    'user@例え.jp',
    'user@тест.ru',
    'user@مثال.com',
    'café@domain.com',
    'user@café.com',
    'naïve@domain.com',
    'user@naïve.com',
  ];
  
  return unicodeEmails[random.nextInt(unicodeEmails.length)];
}

/// Generates an empty or whitespace-only string
String _generateEmptyOrWhitespace(Random random) {
  final type = random.nextInt(4);
  
  switch (type) {
    case 0:
      return '';
    case 1:
      return ' ' * (random.nextInt(10) + 1);
    case 2:
      return '\t' * (random.nextInt(5) + 1);
    case 3:
      return '\n' * (random.nextInt(5) + 1);
    default:
      return '';
  }
}

/// Generates a non-empty string
String _generateNonEmptyString(Random random) {
  final words = [
    'user', 'admin', 'test', 'name', 'john', 'jane',
    'domain', 'example', 'mail', 'company', 'org',
  ];
  
  return words[random.nextInt(words.length)] + random.nextInt(1000).toString();
}

/// Generates a very long string
String _generateLongString(Random random, int length) {
  final chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
}
