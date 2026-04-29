import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/services/plan_comparison_service.dart';
import 'dart:math';

/// Property-based tests for PlanComparisonService
/// 
/// Feature: scholify-roadmap-tracker
/// Task: 3.5
/// 
/// This test suite validates:
/// - Property 14: Plan upgrade comparison
/// 
/// Requirements: B2.3
/// 
/// **Validates: Requirements B2.3**
/// 
/// For any pair of plans (current, requested), the upgrade request SHALL be accepted
/// if and only if requested > current in the ordering: starter < professional < enterprise.

void main() {
  late PlanComparisonService service;

  setUp(() {
    service = PlanComparisonService();
  });

  group('Property 14: Plan upgrade comparison', () {
    /// **Validates: Requirements B2.3**
    /// 
    /// For any pair of plans (current, requested), the upgrade request SHALL be accepted
    /// if and only if requested > current in the ordering: starter < professional < enterprise.
    test('plan comparison follows strict hierarchy: starter < professional < enterprise', () {
      const numIterations = 1000;
      final random = Random(42); // Fixed seed for reproducibility

      // Define the plan hierarchy
      final plans = ['starter', 'professional', 'enterprise'];
      final planValues = {'starter': 1, 'professional': 2, 'enterprise': 3};

      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate random plan pair
        final currentPlan = plans[random.nextInt(plans.length)];
        final requestedPlan = plans[random.nextInt(plans.length)];

        // Apply random case variations
        final currentPlanVariant = _applyRandomCase(currentPlan, random);
        final requestedPlanVariant = _applyRandomCase(requestedPlan, random);

        // Optionally add whitespace
        final currentPlanWithWhitespace = _maybeAddWhitespace(currentPlanVariant, random);
        final requestedPlanWithWhitespace = _maybeAddWhitespace(requestedPlanVariant, random);

        // Compare plans
        final result = service.comparePlans(
          currentPlanWithWhitespace,
          requestedPlanWithWhitespace,
        );

        // Calculate expected result: requested > current
        final currentValue = planValues[currentPlan]!;
        final requestedValue = planValues[requestedPlan]!;
        final expectedResult = requestedValue > currentValue;

        // Assert: comparison result matches expected
        expect(
          result,
          equals(expectedResult),
          reason: 'Plan comparison failed for: '
              'current="$currentPlanWithWhitespace" (normalized: $currentPlan, value: $currentValue), '
              'requested="$requestedPlanWithWhitespace" (normalized: $requestedPlan, value: $requestedValue). '
              'Expected: $expectedResult, Got: $result',
        );
      }
    });

    test('valid upgrades are accepted', () {
      // Test all valid upgrade paths
      final validUpgrades = [
        ['starter', 'professional'],
        ['starter', 'enterprise'],
        ['professional', 'enterprise'],
      ];

      for (final upgrade in validUpgrades) {
        final current = upgrade[0];
        final requested = upgrade[1];

        final result = service.comparePlans(current, requested);

        expect(
          result,
          isTrue,
          reason: 'Valid upgrade $current → $requested should be accepted',
        );
      }
    });

    test('same plan is rejected', () {
      const numIterations = 100;
      final random = Random(123);
      final plans = ['starter', 'professional', 'enterprise'];

      for (int iteration = 0; iteration < numIterations; iteration++) {
        final plan = plans[random.nextInt(plans.length)];

        // Apply random case variations
        final currentVariant = _applyRandomCase(plan, random);
        final requestedVariant = _applyRandomCase(plan, random);

        // Add random whitespace
        final currentWithWhitespace = _maybeAddWhitespace(currentVariant, random);
        final requestedWithWhitespace = _maybeAddWhitespace(requestedVariant, random);

        final result = service.comparePlans(
          currentWithWhitespace,
          requestedWithWhitespace,
        );

        expect(
          result,
          isFalse,
          reason: 'Same plan upgrade should be rejected: '
              'current="$currentWithWhitespace", requested="$requestedWithWhitespace"',
        );
      }
    });

    test('downgrades are rejected', () {
      // Test all downgrade paths
      final downgrades = [
        ['professional', 'starter'],
        ['enterprise', 'starter'],
        ['enterprise', 'professional'],
      ];

      for (final downgrade in downgrades) {
        final current = downgrade[0];
        final requested = downgrade[1];

        final result = service.comparePlans(current, requested);

        expect(
          result,
          isFalse,
          reason: 'Downgrade $current → $requested should be rejected',
        );
      }
    });

    test('invalid plan names are rejected', () {
      const numIterations = 200;
      final random = Random(456);
      final validPlans = ['starter', 'professional', 'enterprise'];

      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate invalid plan name
        final invalidPlan = _generateInvalidPlanName(random);
        final validPlan = validPlans[random.nextInt(validPlans.length)];

        // Test invalid current plan
        final result1 = service.comparePlans(invalidPlan, validPlan);
        expect(
          result1,
          isFalse,
          reason: 'Invalid current plan should be rejected: '
              'current="$invalidPlan", requested="$validPlan"',
        );

        // Test invalid requested plan
        final result2 = service.comparePlans(validPlan, invalidPlan);
        expect(
          result2,
          isFalse,
          reason: 'Invalid requested plan should be rejected: '
              'current="$validPlan", requested="$invalidPlan"',
        );

        // Test both invalid
        final invalidPlan2 = _generateInvalidPlanName(random);
        final result3 = service.comparePlans(invalidPlan, invalidPlan2);
        expect(
          result3,
          isFalse,
          reason: 'Both invalid plans should be rejected: '
              'current="$invalidPlan", requested="$invalidPlan2"',
        );
      }
    });

    test('comparison is case-insensitive', () {
      const numIterations = 100;
      final random = Random(789);
      final plans = ['starter', 'professional', 'enterprise'];

      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Pick two different plans for a valid upgrade
        final currentIndex = random.nextInt(plans.length - 1);
        final requestedIndex = currentIndex + 1 + random.nextInt(plans.length - currentIndex - 1);

        final current = plans[currentIndex];
        final requested = plans[requestedIndex];

        // Apply various case transformations
        final currentVariant = _applyRandomCase(current, random);
        final requestedVariant = _applyRandomCase(requested, random);

        final result = service.comparePlans(currentVariant, requestedVariant);

        expect(
          result,
          isTrue,
          reason: 'Case-insensitive comparison failed: '
              'current="$currentVariant" (normalized: $current), '
              'requested="$requestedVariant" (normalized: $requested)',
        );
      }
    });

    test('comparison handles whitespace correctly', () {
      const numIterations = 100;
      final random = Random(101112);
      final plans = ['starter', 'professional', 'enterprise'];

      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Pick two different plans for a valid upgrade
        final currentIndex = random.nextInt(plans.length - 1);
        final requestedIndex = currentIndex + 1 + random.nextInt(plans.length - currentIndex - 1);

        final current = plans[currentIndex];
        final requested = plans[requestedIndex];

        // Add random whitespace
        final currentWithWhitespace = _addRandomWhitespace(current, random);
        final requestedWithWhitespace = _addRandomWhitespace(requested, random);

        final result = service.comparePlans(currentWithWhitespace, requestedWithWhitespace);

        expect(
          result,
          isTrue,
          reason: 'Whitespace handling failed: '
              'current="$currentWithWhitespace" (normalized: $current), '
              'requested="$requestedWithWhitespace" (normalized: $requested)',
        );
      }
    });

    test('comparison is deterministic', () {
      // Test that the same inputs always produce the same output
      const numIterations = 100;
      final random = Random(131415);
      final plans = ['starter', 'professional', 'enterprise'];

      for (int iteration = 0; iteration < numIterations; iteration++) {
        final currentPlan = plans[random.nextInt(plans.length)];
        final requestedPlan = plans[random.nextInt(plans.length)];

        // Call comparison multiple times with same inputs
        final result1 = service.comparePlans(currentPlan, requestedPlan);
        final result2 = service.comparePlans(currentPlan, requestedPlan);
        final result3 = service.comparePlans(currentPlan, requestedPlan);

        expect(
          result1,
          equals(result2),
          reason: 'Comparison should be deterministic: '
              'current="$currentPlan", requested="$requestedPlan"',
        );

        expect(
          result2,
          equals(result3),
          reason: 'Comparison should be deterministic: '
              'current="$currentPlan", requested="$requestedPlan"',
        );
      }
    });

    test('transitivity property: if A < B and B < C, then A < C', () {
      // Test transitivity of the plan hierarchy
      // starter < professional < enterprise
      
      // starter < professional
      expect(service.comparePlans('starter', 'professional'), isTrue);
      
      // professional < enterprise
      expect(service.comparePlans('professional', 'enterprise'), isTrue);
      
      // Therefore: starter < enterprise (transitivity)
      expect(service.comparePlans('starter', 'enterprise'), isTrue);
    });

    test('antisymmetry property: if A < B, then NOT (B < A)', () {
      const numIterations = 100;
      final random = Random(161718);
      final plans = ['starter', 'professional', 'enterprise'];

      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Pick two different plans
        final index1 = random.nextInt(plans.length);
        var index2 = random.nextInt(plans.length);
        
        // Ensure different plans
        while (index2 == index1) {
          index2 = random.nextInt(plans.length);
        }

        final plan1 = plans[index1];
        final plan2 = plans[index2];

        final result1 = service.comparePlans(plan1, plan2);
        final result2 = service.comparePlans(plan2, plan1);

        // Exactly one should be true (antisymmetry)
        expect(
          result1 != result2,
          isTrue,
          reason: 'Antisymmetry violated: '
              'comparePlans("$plan1", "$plan2") = $result1, '
              'comparePlans("$plan2", "$plan1") = $result2. '
              'Exactly one should be true.',
        );
      }
    });

    test('irreflexivity property: NOT (A < A) for any plan', () {
      final plans = ['starter', 'professional', 'enterprise'];

      for (final plan in plans) {
        final result = service.comparePlans(plan, plan);

        expect(
          result,
          isFalse,
          reason: 'Irreflexivity violated: plan "$plan" should not be less than itself',
        );
      }
    });
  });

  group('PlanComparisonService helper methods', () {
    test('isValidPlan correctly identifies valid plans', () {
      const numIterations = 100;
      final random = Random(192021);
      final validPlans = ['starter', 'professional', 'enterprise'];

      for (int iteration = 0; iteration < numIterations; iteration++) {
        final plan = validPlans[random.nextInt(validPlans.length)];
        final variant = _applyRandomCase(plan, random);
        final withWhitespace = _maybeAddWhitespace(variant, random);

        final result = service.isValidPlan(withWhitespace);

        expect(
          result,
          isTrue,
          reason: 'Valid plan should be recognized: "$withWhitespace" (normalized: $plan)',
        );
      }
    });

    test('isValidPlan correctly rejects invalid plans', () {
      const numIterations = 100;
      final random = Random(222324);

      for (int iteration = 0; iteration < numIterations; iteration++) {
        final invalidPlan = _generateInvalidPlanName(random);

        final result = service.isValidPlan(invalidPlan);

        expect(
          result,
          isFalse,
          reason: 'Invalid plan should be rejected: "$invalidPlan"',
        );
      }
    });

    test('getPlanValue returns correct hierarchy values', () {
      final expectedValues = {
        'starter': 1,
        'professional': 2,
        'enterprise': 3,
      };

      for (final entry in expectedValues.entries) {
        final plan = entry.key;
        final expectedValue = entry.value;

        final result = service.getPlanValue(plan);

        expect(
          result,
          equals(expectedValue),
          reason: 'Plan "$plan" should have value $expectedValue',
        );
      }
    });

    test('getPlanValue returns null for invalid plans', () {
      const numIterations = 50;
      final random = Random(252627);

      for (int iteration = 0; iteration < numIterations; iteration++) {
        final invalidPlan = _generateInvalidPlanName(random);

        final result = service.getPlanValue(invalidPlan);

        expect(
          result,
          isNull,
          reason: 'Invalid plan should return null: "$invalidPlan"',
        );
      }
    });

    test('getValidPlans returns all valid plan codes', () {
      final result = service.getValidPlans();

      expect(result, contains('starter'));
      expect(result, contains('professional'));
      expect(result, contains('enterprise'));
      expect(result.length, equals(3));
    });
  });
}

// ============================================================================
// Helper Functions for Property-Based Testing
// ============================================================================

/// Applies random case transformation to a string
String _applyRandomCase(String input, Random random) {
  final caseType = random.nextInt(4);
  
  switch (caseType) {
    case 0:
      return input.toLowerCase();
    case 1:
      return input.toUpperCase();
    case 2:
      // Title case
      return input[0].toUpperCase() + input.substring(1).toLowerCase();
    case 3:
      // Random case for each character
      return input.split('').map((char) {
        return random.nextBool() ? char.toUpperCase() : char.toLowerCase();
      }).join();
    default:
      return input;
  }
}

/// Adds random whitespace (leading, trailing, or both) to a string
String _addRandomWhitespace(String input, Random random) {
  final leadingSpaces = ' ' * random.nextInt(5);
  final trailingSpaces = ' ' * random.nextInt(5);
  
  final addLeading = random.nextBool();
  final addTrailing = random.nextBool();
  
  if (addLeading && addTrailing) {
    return '$leadingSpaces$input$trailingSpaces';
  } else if (addLeading) {
    return '$leadingSpaces$input';
  } else if (addTrailing) {
    return '$input$trailingSpaces';
  } else {
    return input;
  }
}

/// Maybe adds whitespace to a string (50% chance)
String _maybeAddWhitespace(String input, Random random) {
  if (random.nextBool()) {
    return _addRandomWhitespace(input, random);
  }
  return input;
}

/// Generates an invalid plan name
String _generateInvalidPlanName(Random random) {
  final invalidNames = [
    'basic',
    'premium',
    'free',
    'trial',
    'standard',
    'advanced',
    'ultimate',
    'business',
    'personal',
    'team',
    '',
    ' ',
    'starter_plan',
    'professional_plan',
    'enterprise_plan',
    'INVALID',
    '123',
    'starter123',
    'professional-plan',
    'enterprise.plan',
    'null',
    'undefined',
  ];
  
  return invalidNames[random.nextInt(invalidNames.length)];
}
