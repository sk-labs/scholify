# Onboarding Wizard Integration Guide

## Overview

The `OnboardingWizardPage` implements a 3-step guided flow for creating new tenants in the Scholify platform.

**Feature**: scholify-roadmap-tracker  
**Requirements**: H1.1, H1.2, H1.3, H1.4, H1.5, H1.6, H1.7, H1.8

## Integration

To add the wizard to the Superadmin Dashboard, add this import:

```dart
import 'onboarding_wizard_page.dart';
```

Then add a new `_ModuleCard` in the dashboard's ListView:

```dart
_ModuleCard(
  title: 'Tenant Onboarding Wizard',
  subtitle: 'Guided flow to create tenant, license, and owner in one session.',
  trailing: 'New',
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingWizardPage(
          syncEngine: syncEngine,
          validationService: WizardValidationService(
            database: syncEngine.database,
          ),
        ),
      ),
    );
  },
),
```

## Features

### Step 1: Tenant Identity
- School name input with real-time validation
- Automatic tenant_id derivation (lowercase, non-alphanumeric → underscore)
- Duplicate tenant_id detection
- Visual feedback for derived tenant_id

### Step 2: License Configuration
- Plan dropdown (starter/professional/enterprise)
- Seat limit input with validation (positive integer)
- Default seat limit: 100

### Step 3: Owner Email
- Email input with format validation
- Validates presence of @ and domain segment

### Step 4: Confirmation
- Summary of all entered information
- "Create Tenant" button
- Progress indicator during save

## Validation Rules

All validation is handled by `WizardValidationService`:

- **School Name**: Non-empty after trimming
- **Tenant ID**: Derived from school name, must be unique
- **Plan**: One of starter/professional/enterprise (case-insensitive)
- **Seat Limit**: Positive integer
- **Email**: Contains @ followed by at least one character

## Atomic Transaction

The wizard uses a Drift transaction to ensure atomicity:

1. Insert `TenantRecord`
2. Insert `TenantLicenseEntry` (expires in 365 days)
3. Insert `SchoolOwnerEntry` (provisioning status: 'pending')
4. Enqueue 3 sync operations

If any step fails, the entire transaction is rolled back and an error message is displayed.

## Error Handling

- Validation errors are displayed inline at each step
- Transaction failures show an error message on the confirmation step
- Navigation controls are disabled during save
- Success shows a snackbar and navigates back to dashboard

## Testing

Widget tests are available in `test/features/superadmin/onboarding_wizard_page_test.dart`:

- Step navigation
- Validation error display
- Tenant ID derivation
- Back button functionality
- Progress indicator during save

Run tests with:
```bash
flutter test test/features/superadmin/onboarding_wizard_page_test.dart
```

## Dependencies

- `WizardValidationService` - Validation logic
- `SyncEngine` - Database operations and sync queue
- `AppLocalDatabase` - Drift database access
- Flutter Stepper widget - Multi-step UI

## Future Enhancements

- Email verification before provisioning
- Custom license expiry date selection
- Bulk tenant creation from CSV
- Integration with email service for owner invites
