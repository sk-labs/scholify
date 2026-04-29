# PlanComparisonService

## Overview

The `PlanComparisonService` implements plan comparison logic for the Scholify platform's plan upgrade request flow. It determines whether a requested plan upgrade is valid based on the plan hierarchy.

## Plan Hierarchy

The service enforces a strict plan hierarchy:

```
starter < professional < enterprise
```

Where:
- `starter` has value 1
- `professional` has value 2
- `enterprise` has value 3

## Valid Upgrades

The following upgrade paths are valid (requested > current):

- `starter` → `professional`
- `starter` → `enterprise`
- `professional` → `enterprise`

## Invalid Upgrades

The following are rejected (same plan or downgrade):

- `starter` → `starter` (same plan)
- `professional` → `starter` (downgrade)
- `professional` → `professional` (same plan)
- `enterprise` → `starter` (downgrade)
- `enterprise` → `professional` (downgrade)
- `enterprise` → `enterprise` (same plan)

## Usage

### Basic Comparison

```dart
final service = PlanComparisonService();

// Valid upgrade
final isValid = service.comparePlans('starter', 'professional');
print(isValid); // true

// Invalid (same plan)
final isInvalid = service.comparePlans('starter', 'starter');
print(isInvalid); // false

// Invalid (downgrade)
final isDowngrade = service.comparePlans('professional', 'starter');
print(isDowngrade); // false
```

### Case-Insensitive Comparison

The service handles case variations automatically:

```dart
final service = PlanComparisonService();

// All of these work
service.comparePlans('STARTER', 'professional'); // true
service.comparePlans('Starter', 'Professional'); // true
service.comparePlans('starter', 'PROFESSIONAL'); // true
```

### Whitespace Handling

Leading and trailing whitespace is automatically trimmed:

```dart
final service = PlanComparisonService();

// Whitespace is handled
service.comparePlans('  starter  ', 'professional'); // true
service.comparePlans('starter', '  professional  '); // true
```

### Validating Plan Names

Check if a plan code is valid:

```dart
final service = PlanComparisonService();

service.isValidPlan('starter'); // true
service.isValidPlan('professional'); // true
service.isValidPlan('enterprise'); // true
service.isValidPlan('invalid'); // false
service.isValidPlan(''); // false
```

### Getting Plan Values

Retrieve the hierarchy value for a plan:

```dart
final service = PlanComparisonService();

service.getPlanValue('starter'); // 1
service.getPlanValue('professional'); // 2
service.getPlanValue('enterprise'); // 3
service.getPlanValue('invalid'); // null
```

### Getting All Valid Plans

Retrieve the list of all valid plan codes:

```dart
final service = PlanComparisonService();

final plans = service.getValidPlans();
print(plans); // ['starter', 'professional', 'enterprise']
```

## Integration with Plan Upgrade Request Flow

This service is used in the Plan Upgrade Request flow (Requirement B2.3) to validate upgrade requests before submission:

```dart
class PlanUpgradeRequestPage extends StatefulWidget {
  // ...
}

class _PlanUpgradeRequestPageState extends State<PlanUpgradeRequestPage> {
  final _planComparisonService = PlanComparisonService();
  
  void _submitUpgradeRequest() {
    final currentPlan = _getCurrentPlan();
    final requestedPlan = _selectedPlan;
    
    // Validate upgrade request
    if (!_planComparisonService.comparePlans(currentPlan, requestedPlan)) {
      _showError('You can only upgrade to a higher plan. '
          'Current: $currentPlan, Requested: $requestedPlan');
      return;
    }
    
    // Proceed with submission
    _saveUpgradeRequest(currentPlan, requestedPlan);
  }
}
```

## Properties and Guarantees

The service guarantees the following mathematical properties:

### 1. Transitivity
If A < B and B < C, then A < C

Example: `starter < professional` and `professional < enterprise`, therefore `starter < enterprise`

### 2. Antisymmetry
If A < B, then NOT (B < A)

Example: If `starter < professional`, then NOT (`professional < starter`)

### 3. Irreflexivity
NOT (A < A) for any plan

Example: NOT (`starter < starter`)

### 4. Determinism
The same inputs always produce the same output

Example: `comparePlans('starter', 'professional')` always returns `true`

## Testing

The service is thoroughly tested with property-based tests that verify:

- Correct hierarchy enforcement across all plan pairs
- Case-insensitive comparison
- Whitespace handling
- Invalid plan name rejection
- Deterministic behavior
- Mathematical properties (transitivity, antisymmetry, irreflexivity)

See `test/core/services/plan_comparison_service_property_test.dart` for the complete test suite.

## Requirements

**Feature:** scholify-roadmap-tracker  
**Task:** 3.5  
**Property:** 14 - Plan upgrade comparison  
**Validates:** Requirements B2.3

From the requirements document:

> THE Plan_Upgrade_Page SHALL prevent submission if the requested plan is the same as or lower than the current plan.

## Related Files

- Service: `lib/core/services/plan_comparison_service.dart`
- Tests: `test/core/services/plan_comparison_service_property_test.dart`
- Requirements: `.kiro/specs/scholify-roadmap-tracker/requirements.md` (B2.3)
- Design: `.kiro/specs/scholify-roadmap-tracker/design.md` (Property 14)
