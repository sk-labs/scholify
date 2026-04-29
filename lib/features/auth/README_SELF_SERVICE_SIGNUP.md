# Self-Service Tenant Signup

**Feature:** scholify-roadmap-tracker  
**Requirements:** B1.1, B1.2, B1.3, B1.4, B1.5, B1.6, B1.7, B1.8

## Overview

The Self-Service Tenant Signup feature allows school administrators to register their school on Scholify without contacting the platform operator. Users can start using the platform immediately on the starter plan.

## Components

### 1. SelfServiceSignupPage (`presentation/self_service_signup_page.dart`)

The UI page that collects signup information and handles the signup flow.

**Features:**
- Accessible without authentication (B1.1)
- Collects: school name, owner full name, owner email, password (B1.2)
- Real-time validation with error messages
- Password visibility toggle
- Loading state during signup
- Error display for duplicate emails and other failures (B1.4, B1.7)

**Validation:**
- School name: non-empty after trimming
- Owner full name: non-empty after trimming
- Email: contains @ and domain segment (B1.3)
- Password: minimum 8 characters (B1.8)

### 2. SignupService (`data/signup_service.dart`)

The business logic service that orchestrates the signup process.

**Signup Flow:**
1. Validates all inputs using `SignupValidationService`
2. Checks email uniqueness in PocketBase (B1.3, B1.4)
3. Creates PocketBase user account (B1.5)
4. Creates local Drift records:
   - `TenantRecord` with `isActive=true`
   - `TenantLicenseEntry` with `planCode='starter'`, `seatLimit=100`, `expiresAt=now+365d`
   - `SchoolOwnerEntry` with `provisioningStatus='active'`
5. Enqueues sync operations for all three records
6. Auto-signs-in the user (B1.6)
7. Sets tenant context
8. Rolls back all records on failure (B1.7)

**Error Handling:**
- Returns `SignupResult` with success flag and error message
- Rolls back PocketBase user if local record creation fails
- Rolls back local records if sign-in fails
- Provides descriptive error messages for all failure scenarios

### 3. SignupValidationService (`core/services/signup_validation_service.dart`)

Validation logic for signup inputs (already implemented in Phase 1).

## Integration

To integrate the signup page into your app:

```dart
// In your auth flow or landing page
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => SelfServiceSignupPage(
      pocketbaseGateway: pocketbaseGateway,
      database: database,
      syncEngine: syncEngine,
      tenantContext: tenantContext,
      onSignupSuccess: () {
        // Navigate to Foundation Shell
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ScholifyShellPage(
              tenantContext: tenantContext,
              syncEngine: syncEngine,
            ),
          ),
        );
      },
    ),
  ),
);
```

## Starter Plan Details

New tenants are automatically provisioned with:
- **Plan Code:** `starter`
- **Seat Limit:** 100 students
- **License Duration:** 365 days from signup
- **Status:** Active

## Tenant ID Generation

The tenant ID is derived from the school name:
1. Convert to lowercase
2. Replace non-alphanumeric characters with underscores
3. Remove leading/trailing underscores
4. Append timestamp for uniqueness

Example: "Springfield High School" → `springfield_high_school_1714392000000`

## Error Messages

- **Duplicate Email (B1.4):** "An account with this email already exists."
- **Validation Errors:** Field-specific messages (e.g., "Password must be at least 8 characters")
- **Signup Failure (B1.7):** Descriptive error message with rollback confirmation
- **Sign-in Failure:** "Account created but sign-in failed. Please try signing in manually."

## Requirements Satisfied

- ✅ B1.1: Page accessible without authentication
- ✅ B1.2: Collects school name, owner full name, email, password
- ✅ B1.3: Validates email not already registered
- ✅ B1.4: Displays "An account with this email already exists" on duplicate
- ✅ B1.5: Creates PocketBase user, TenantRecord, TenantLicenseEntry (starter, 100 seats)
- ✅ B1.6: Auto-signs-in user and navigates to Foundation Shell
- ✅ B1.7: Rolls back all records on failure with descriptive error
- ✅ B1.8: Enforces minimum password length of 8 characters

## Testing

Property-based tests for validation logic are located in:
- `test/core/services/signup_password_validation_property_test.dart`

Integration tests for the complete signup flow should verify:
- Successful signup end-to-end
- Rollback on failure scenarios
- Email uniqueness validation
