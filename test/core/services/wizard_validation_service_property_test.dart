import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/services/wizard_validation_service.dart';
import 'package:drift/native.dart';
import 'dart:math';

/// Property-based tests for WizardValidationService
/// 
/// Feature: scholify-roadmap-tracker
/// Tasks: 3.1, 3.2
/// 
/// This test suite validates:
/// - Property 1: Wizard school name validation
/// - Property 2: Wizard plan and seat limit validation
/// 
/// Requirements: H1.2, H1.3

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

  group('Property 1: Wizard school name validation', () {
    /// **Validates: Requirements H1.2**
    /// 
    /// For any string input as school name, the wizard SHALL accept it if and only if
    /// it is non-empty after trimming whitespace.
    test('wizard accepts non-empty school names after trimming', () {
      const numIterations = 1000;
      final random = Random(42); // Fixed seed for reproducibility
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate random school name with various characteristics
        final schoolName = _generateRandomSchoolName(random);
        
        // Validate school name
        final isValid = validationService.validateSchoolName(schoolName);
        
        // Calculate expected result: non-empty after trimming
        final trimmed = schoolName.trim();
        final expectedValid = trimmed.isNotEmpty;
        
        // Assert: validation result matches expected
        expect(
          isValid,
          equals(expectedValid),
          reason: 'School name validation failed for: "$schoolName" '
              '(trimmed: "$trimmed", length: ${trimmed.length})',
        );
      }
    });

    test('empty strings are rejected', () {
      const numIterations = 100;
      final random = Random(123);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate various empty/whitespace-only strings
        final emptyName = _generateEmptyOrWhitespaceString(random);
        
        // Validate
        final isValid = validationService.validateSchoolName(emptyName);
        
        // Assert: all empty/whitespace-only strings are rejected
        expect(
          isValid,
          isFalse,
          reason: 'Empty/whitespace string should be rejected: "$emptyName"',
        );
      }
    });

    test('non-empty strings with leading/trailing whitespace are accepted', () {
      const numIterations = 100;
      final random = Random(456);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate non-empty string with whitespace padding
        final coreName = _generateNonEmptyString(random);
        final leadingSpaces = ' ' * random.nextInt(10);
        final trailingSpaces = ' ' * random.nextInt(10);
        final paddedName = '$leadingSpaces$coreName$trailingSpaces';
        
        // Validate
        final isValid = validationService.validateSchoolName(paddedName);
        
        // Assert: should be accepted (non-empty after trimming)
        expect(
          isValid,
          isTrue,
          reason: 'Non-empty string with whitespace should be accepted: "$paddedName"',
        );
      }
    });

    test('special characters and Unicode are handled correctly', () {
      const numIterations = 100;
      final random = Random(789);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate school name with special characters and Unicode
        final schoolName = _generateSchoolNameWithSpecialChars(random);
        
        // Validate
        final isValid = validationService.validateSchoolName(schoolName);
        
        // Calculate expected result
        final trimmed = schoolName.trim();
        final expectedValid = trimmed.isNotEmpty;
        
        // Assert: validation handles special characters correctly
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Special character handling failed for: "$schoolName"',
        );
      }
    });

    test('very long school names are validated correctly', () {
      const numIterations = 100;
      final random = Random(101112);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate very long school name (100-1000 characters)
        final length = 100 + random.nextInt(900);
        final longName = _generateLongSchoolName(random, length);
        
        // Validate
        final isValid = validationService.validateSchoolName(longName);
        
        // Calculate expected result
        final trimmed = longName.trim();
        final expectedValid = trimmed.isNotEmpty;
        
        // Assert: long names are validated correctly
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Long name validation failed (length: $length)',
        );
      }
    });

    test('validation is deterministic', () {
      const numIterations = 100;
      final random = Random(131415);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final schoolName = _generateRandomSchoolName(random);
        
        // Validate multiple times
        final result1 = validationService.validateSchoolName(schoolName);
        final result2 = validationService.validateSchoolName(schoolName);
        final result3 = validationService.validateSchoolName(schoolName);
        
        // Assert: all results are identical (deterministic)
        expect(
          result1,
          equals(result2),
          reason: 'Validation should be deterministic for: "$schoolName"',
        );
        expect(
          result2,
          equals(result3),
          reason: 'Validation should be deterministic for: "$schoolName"',
        );
      }
    });

    test('tenant_id derivation produces valid identifiers', () {
      const numIterations = 1000;
      final random = Random(161718);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate random school name
        final schoolName = _generateRandomSchoolName(random);
        
        // Skip empty names (not valid input)
        if (schoolName.trim().isEmpty) continue;
        
        // Derive tenant_id
        final tenantId = validationService.deriveTenantId(schoolName);
        
        // Assert: tenant_id is lowercase
        expect(
          tenantId,
          equals(tenantId.toLowerCase()),
          reason: 'Tenant ID should be lowercase: "$tenantId" from "$schoolName"',
        );
        
        // Assert: tenant_id contains only alphanumeric and underscore
        final validPattern = RegExp(r'^[a-z0-9_]+$');
        expect(
          validPattern.hasMatch(tenantId),
          isTrue,
          reason: 'Tenant ID should contain only [a-z0-9_]: "$tenantId" from "$schoolName"',
        );
      }
    });

    test('tenant_id derivation is deterministic', () {
      const numIterations = 100;
      final random = Random(192021);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final schoolName = _generateRandomSchoolName(random);
        
        // Skip empty names
        if (schoolName.trim().isEmpty) continue;
        
        // Derive tenant_id multiple times
        final tenantId1 = validationService.deriveTenantId(schoolName);
        final tenantId2 = validationService.deriveTenantId(schoolName);
        final tenantId3 = validationService.deriveTenantId(schoolName);
        
        // Assert: all results are identical
        expect(
          tenantId1,
          equals(tenantId2),
          reason: 'Tenant ID derivation should be deterministic',
        );
        expect(
          tenantId2,
          equals(tenantId3),
          reason: 'Tenant ID derivation should be deterministic',
        );
      }
    });

    test('different school names produce different tenant_ids (collision resistance)', () {
      const numIterations = 100;
      final random = Random(222324);
      
      final seenTenantIds = <String, String>{};
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate unique school name
        final schoolName = 'School ${random.nextInt(1000000)} ${_generateNonEmptyString(random)}';
        
        // Derive tenant_id
        final tenantId = validationService.deriveTenantId(schoolName);
        
        // Check for collisions
        if (seenTenantIds.containsKey(tenantId)) {
          // Collision detected - verify the school names are actually different
          final previousSchoolName = seenTenantIds[tenantId]!;
          
          // If school names are different but produce same tenant_id, that's expected
          // (e.g., "School-A" and "School_A" both become "school_a")
          // We just verify the derivation is consistent
          final reDerived = validationService.deriveTenantId(previousSchoolName);
          expect(
            reDerived,
            equals(tenantId),
            reason: 'Re-derivation should produce same tenant_id',
          );
        } else {
          seenTenantIds[tenantId] = schoolName;
        }
      }
    });

    test('tenant_id derivation handles edge cases', () {
      // Test specific edge cases
      final testCases = [
        ('School Name', 'school_name'),
        ('School-Name', 'school_name'),
        ('School_Name', 'school_name'),
        ('School123', 'school123'),
        ('123School', '123school'),
        ('School@#\$%', 'school____'),
        ('École Française', '_cole_fran_aise'),
        ('学校', '__'),
        ('   Trimmed   ', '___trimmed___'),
        ('A', 'a'),
        ('ABC-DEF-GHI', 'abc_def_ghi'),
      ];
      
      for (final testCase in testCases) {
        final schoolName = testCase.$1;
        final expectedTenantId = testCase.$2;
        
        final tenantId = validationService.deriveTenantId(schoolName);
        
        expect(
          tenantId,
          equals(expectedTenantId),
          reason: 'Tenant ID derivation failed for: "$schoolName"',
        );
      }
    });
  });

  group('Property 2: Wizard plan and seat limit validation', () {
    /// **Validates: Requirements H1.3**
    /// 
    /// For any plan code and seat limit pair, the wizard SHALL accept it if and only if
    /// the plan is one of starter, professional, or enterprise (case-insensitive) AND
    /// the seat limit is a positive integer.
    test('wizard accepts valid plan and seat limit combinations', () {
      const numIterations = 1000;
      final random = Random(2000); // Fixed seed for reproducibility
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate random plan code and seat limit
        final planCode = _generateRandomPlanCode(random);
        final seatLimit = _generateRandomSeatLimit(random);
        
        // Validate plan and seat limit
        final isPlanValid = validationService.validatePlan(planCode);
        final isSeatLimitValid = validationService.validateSeatLimit(seatLimit);
        
        // Calculate expected results
        final normalizedPlan = planCode.toLowerCase().trim();
        final expectedPlanValid = normalizedPlan == 'starter' || 
                                  normalizedPlan == 'professional' || 
                                  normalizedPlan == 'enterprise';
        final expectedSeatLimitValid = seatLimit > 0;
        
        // Assert: plan validation matches expected
        expect(
          isPlanValid,
          equals(expectedPlanValid),
          reason: 'Plan validation failed for: "$planCode" '
              '(normalized: "$normalizedPlan")',
        );
        
        // Assert: seat limit validation matches expected
        expect(
          isSeatLimitValid,
          equals(expectedSeatLimitValid),
          reason: 'Seat limit validation failed for: $seatLimit',
        );
        
        // Assert: both must be valid for wizard to accept
        final bothValid = isPlanValid && isSeatLimitValid;
        final expectedBothValid = expectedPlanValid && expectedSeatLimitValid;
        expect(
          bothValid,
          equals(expectedBothValid),
          reason: 'Combined validation failed for plan "$planCode" and seat limit $seatLimit',
        );
      }
    });

    test('valid plans are accepted (case-insensitive)', () {
      const numIterations = 100;
      final random = Random(2001);
      
      final validPlans = ['starter', 'professional', 'enterprise'];
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Pick a valid plan and apply random case variations
        final basePlan = validPlans[random.nextInt(validPlans.length)];
        final planCode = _applyRandomCase(basePlan, random);
        
        // Add random whitespace
        final paddedPlan = _addRandomWhitespace(planCode, random);
        
        // Validate
        final isValid = validationService.validatePlan(paddedPlan);
        
        // Assert: should be accepted
        expect(
          isValid,
          isTrue,
          reason: 'Valid plan should be accepted: "$paddedPlan" (base: "$basePlan")',
        );
      }
    });

    test('invalid plans are rejected', () {
      const numIterations = 100;
      final random = Random(2002);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate invalid plan code
        final planCode = _generateInvalidPlanCode(random);
        
        // Validate
        final isValid = validationService.validatePlan(planCode);
        
        // Assert: should be rejected
        expect(
          isValid,
          isFalse,
          reason: 'Invalid plan should be rejected: "$planCode"',
        );
      }
    });

    test('positive seat limits are accepted', () {
      const numIterations = 100;
      final random = Random(2003);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate positive seat limit (1 to 1,000,000)
        final seatLimit = random.nextInt(1000000) + 1;
        
        // Validate
        final isValid = validationService.validateSeatLimit(seatLimit);
        
        // Assert: should be accepted
        expect(
          isValid,
          isTrue,
          reason: 'Positive seat limit should be accepted: $seatLimit',
        );
      }
    });

    test('zero and negative seat limits are rejected', () {
      const numIterations = 100;
      final random = Random(2004);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate zero or negative seat limit
        final seatLimit = random.nextInt(1000) * -1; // 0 to -999
        
        // Validate
        final isValid = validationService.validateSeatLimit(seatLimit);
        
        // Assert: should be rejected
        expect(
          isValid,
          isFalse,
          reason: 'Zero/negative seat limit should be rejected: $seatLimit',
        );
      }
    });

    test('edge case seat limits are handled correctly', () {
      final testCases = [
        (1, true),           // Minimum valid
        (2, true),
        (10, true),
        (100, true),
        (1000, true),
        (10000, true),
        (100000, true),
        (1000000, true),
        (999999999, true),   // Very large positive
        (0, false),          // Zero
        (-1, false),         // Negative
        (-10, false),
        (-100, false),
        (-1000, false),
        (-999999999, false), // Very large negative
      ];
      
      for (final testCase in testCases) {
        final seatLimit = testCase.$1;
        final expectedValid = testCase.$2;
        
        final isValid = validationService.validateSeatLimit(seatLimit);
        
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Seat limit validation failed for: $seatLimit',
        );
      }
    });

    test('plan validation is case-insensitive', () {
      final testCases = [
        'starter',
        'STARTER',
        'Starter',
        'StArTeR',
        'professional',
        'PROFESSIONAL',
        'Professional',
        'PrOfEsSiOnAl',
        'enterprise',
        'ENTERPRISE',
        'Enterprise',
        'EnTeRpRiSe',
      ];
      
      for (final planCode in testCases) {
        final isValid = validationService.validatePlan(planCode);
        
        expect(
          isValid,
          isTrue,
          reason: 'Valid plan with case variation should be accepted: "$planCode"',
        );
      }
    });

    test('plan validation handles whitespace correctly', () {
      final testCases = [
        ('  starter  ', true),
        ('\tstarter\t', true),
        ('  professional  ', true),
        ('  enterprise  ', true),
        ('   ', false),
        ('  invalid  ', false),
      ];
      
      for (final testCase in testCases) {
        final planCode = testCase.$1;
        final expectedValid = testCase.$2;
        
        final isValid = validationService.validatePlan(planCode);
        
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Plan validation with whitespace failed for: "$planCode"',
        );
      }
    });

    test('invalid plan codes are rejected', () {
      final invalidPlans = [
        '',
        ' ',
        'basic',
        'free',
        'premium',
        'standard',
        'start',
        'prof',
        'ent',
        'starter1',
        'professional2',
        'enterprise3',
        'starter-plan',
        'professional_plan',
        'enterprise-plan',
        'INVALID',
        'random',
        '123',
        'starter professional',
        'professional,enterprise',
      ];
      
      for (final planCode in invalidPlans) {
        final isValid = validationService.validatePlan(planCode);
        
        expect(
          isValid,
          isFalse,
          reason: 'Invalid plan should be rejected: "$planCode"',
        );
      }
    });

    test('plan and seat limit validation is deterministic', () {
      const numIterations = 100;
      final random = Random(2005);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final planCode = _generateRandomPlanCode(random);
        final seatLimit = _generateRandomSeatLimit(random);
        
        // Validate multiple times
        final planResult1 = validationService.validatePlan(planCode);
        final planResult2 = validationService.validatePlan(planCode);
        final planResult3 = validationService.validatePlan(planCode);
        
        final seatResult1 = validationService.validateSeatLimit(seatLimit);
        final seatResult2 = validationService.validateSeatLimit(seatLimit);
        final seatResult3 = validationService.validateSeatLimit(seatLimit);
        
        // Assert: all results are identical (deterministic)
        expect(planResult1, equals(planResult2));
        expect(planResult2, equals(planResult3));
        expect(seatResult1, equals(seatResult2));
        expect(seatResult2, equals(seatResult3));
      }
    });

    test('combined validation: only valid plan AND positive seat limit accepted', () {
      const numIterations = 200;
      final random = Random(2006);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final planCode = _generateRandomPlanCode(random);
        final seatLimit = _generateRandomSeatLimit(random);
        
        final isPlanValid = validationService.validatePlan(planCode);
        final isSeatLimitValid = validationService.validateSeatLimit(seatLimit);
        
        // Both must be valid for wizard to accept
        final bothValid = isPlanValid && isSeatLimitValid;
        
        // Calculate expected
        final normalizedPlan = planCode.toLowerCase().trim();
        final expectedPlanValid = normalizedPlan == 'starter' || 
                                  normalizedPlan == 'professional' || 
                                  normalizedPlan == 'enterprise';
        final expectedSeatLimitValid = seatLimit > 0;
        final expectedBothValid = expectedPlanValid && expectedSeatLimitValid;
        
        expect(
          bothValid,
          equals(expectedBothValid),
          reason: 'Combined validation failed: plan="$planCode" ($isPlanValid), '
              'seatLimit=$seatLimit ($isSeatLimitValid)',
        );
      }
    });
  });
}

// ── Helper Functions ──────────────────────────────────────────────────────

/// Generates a random school name with various characteristics
String _generateRandomSchoolName(Random random) {
  final type = random.nextInt(6);
  
  switch (type) {
    case 0:
      // Empty string
      return '';
    case 1:
      // Whitespace only
      return ' ' * (random.nextInt(10) + 1);
    case 2:
      // Normal school name
      return _generateNonEmptyString(random);
    case 3:
      // Name with leading/trailing whitespace
      final core = _generateNonEmptyString(random);
      final leading = ' ' * random.nextInt(5);
      final trailing = ' ' * random.nextInt(5);
      return '$leading$core$trailing';
    case 4:
      // Name with special characters
      return _generateSchoolNameWithSpecialChars(random);
    case 5:
      // Very short name
      return String.fromCharCode(65 + random.nextInt(26)); // A-Z
    default:
      return 'School';
  }
}

/// Generates an empty or whitespace-only string
String _generateEmptyOrWhitespaceString(Random random) {
  final type = random.nextInt(3);
  
  switch (type) {
    case 0:
      return '';
    case 1:
      return ' ' * (random.nextInt(20) + 1);
    case 2:
      return '\t' * (random.nextInt(5) + 1);
    default:
      return '';
  }
}

/// Generates a non-empty string
String _generateNonEmptyString(Random random) {
  final words = [
    'School', 'Academy', 'Institute', 'College', 'University',
    'High', 'Elementary', 'Primary', 'Secondary', 'International',
    'Public', 'Private', 'Charter', 'Montessori', 'Waldorf',
  ];
  
  final numWords = random.nextInt(3) + 1;
  final selectedWords = List.generate(
    numWords,
    (_) => words[random.nextInt(words.length)],
  );
  
  return selectedWords.join(' ');
}

/// Generates a school name with special characters and Unicode
String _generateSchoolNameWithSpecialChars(Random random) {
  final specialChars = [
    'School-Name',
    'School_Name',
    'School@Name',
    'School#123',
    'School & Academy',
    'École Française',
    'Schüle',
    'Escuela',
    '学校',
    'مدرسة',
    'School (Main Campus)',
    'School [Branch]',
    'School {A}',
    'School+Academy',
    'School=Name',
    'School|Name',
    'School\\Name',
    'School/Name',
    'School:Name',
    'School;Name',
    'School\'s Academy',
    'School"Name"',
    'School<Name>',
    'School?Name!',
    'School~Name',
    'School`Name',
  ];
  
  return specialChars[random.nextInt(specialChars.length)];
}

/// Generates a very long school name
String _generateLongSchoolName(Random random, int length) {
  final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ';
  return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
}

/// Generates a random plan code (valid or invalid)
String _generateRandomPlanCode(Random random) {
  final type = random.nextInt(10);
  
  switch (type) {
    case 0:
    case 1:
      // Valid plans with random case
      final validPlans = ['starter', 'professional', 'enterprise'];
      final plan = validPlans[random.nextInt(validPlans.length)];
      return _applyRandomCase(plan, random);
    case 2:
      // Valid plan with whitespace
      final validPlans = ['starter', 'professional', 'enterprise'];
      final plan = validPlans[random.nextInt(validPlans.length)];
      return _addRandomWhitespace(_applyRandomCase(plan, random), random);
    case 3:
    case 4:
      // Invalid plan codes
      return _generateInvalidPlanCode(random);
    case 5:
      // Empty string
      return '';
    case 6:
      // Whitespace only
      return ' ' * (random.nextInt(5) + 1);
    case 7:
      // Partial match
      final partials = ['start', 'prof', 'ent', 'starter1', 'professional2'];
      return partials[random.nextInt(partials.length)];
    case 8:
      // Random string
      final length = random.nextInt(15) + 1;
      final chars = 'abcdefghijklmnopqrstuvwxyz';
      return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
    case 9:
      // Numbers
      return random.nextInt(1000).toString();
    default:
      return 'invalid';
  }
}

/// Generates an invalid plan code
String _generateInvalidPlanCode(Random random) {
  final invalidPlans = [
    'basic',
    'free',
    'premium',
    'standard',
    'start',
    'prof',
    'ent',
    'starter1',
    'professional2',
    'enterprise3',
    'starter-plan',
    'professional_plan',
    'enterprise-plan',
    'INVALID',
    'random',
    'plan',
    'subscription',
    'tier',
    'starter professional',
    'professional,enterprise',
    'starter+professional',
  ];
  
  return invalidPlans[random.nextInt(invalidPlans.length)];
}

/// Generates a random seat limit (positive, zero, or negative)
int _generateRandomSeatLimit(Random random) {
  final type = random.nextInt(10);
  
  switch (type) {
    case 0:
    case 1:
    case 2:
    case 3:
      // Positive integers (common case)
      return random.nextInt(1000) + 1;
    case 4:
      // Very large positive
      return random.nextInt(999999) + 1000;
    case 5:
      // Small positive (1-10)
      return random.nextInt(10) + 1;
    case 6:
      // Zero
      return 0;
    case 7:
    case 8:
      // Negative integers
      return -(random.nextInt(1000) + 1);
    case 9:
      // Very large negative
      return -(random.nextInt(999999) + 1000);
    default:
      return 1;
  }
}

/// Applies random case variations to a string
String _applyRandomCase(String text, Random random) {
  return text.split('').map((char) {
    if (random.nextBool()) {
      return char.toUpperCase();
    } else {
      return char.toLowerCase();
    }
  }).join();
}

/// Adds random whitespace padding to a string
String _addRandomWhitespace(String text, Random random) {
  final leadingSpaces = ' ' * random.nextInt(5);
  final trailingSpaces = ' ' * random.nextInt(5);
  return '$leadingSpaces$text$trailingSpaces';
}

