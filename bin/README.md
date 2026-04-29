# PocketBase Rules Verification Script

## Overview

The `verify_pocketbase_rules.dart` script validates that a live PocketBase instance has the correct tenant-isolation rules applied to each collection as defined in `docs/POCKETBASE_TENANT_RULES.md`.

## Requirements

- **Requirement A1.1**: Checks every collection listed in `docs/POCKETBASE_TENANT_RULES.md` against the live PocketBase Admin API
- **Requirement A1.2**: Reports collection name, rule type, expected value, and actual value for any mismatches
- **Requirement A1.3**: Reports "All rules verified" when all rules match
- **Requirement A1.4**: Executable as a standalone Dart script using `dart run`

## Usage

### Basic Usage

```bash
POCKETBASE_ADMIN_PASSWORD=your_password dart run bin/verify_pocketbase_rules.dart
```

### Environment Variables

The script accepts the following environment variables:

- `POCKETBASE_URL` (optional): PocketBase instance URL. Default: `http://127.0.0.1:8090`
- `POCKETBASE_ADMIN_EMAIL` (optional): Admin email for authentication. Default: `admin@scholify.local`
- `POCKETBASE_ADMIN_PASSWORD` (required): Admin password for authentication

### Example with Custom URL

```bash
POCKETBASE_URL=https://your-instance.pocketbase.io \
POCKETBASE_ADMIN_EMAIL=admin@example.com \
POCKETBASE_ADMIN_PASSWORD=your_password \
dart run bin/verify_pocketbase_rules.dart
```

## Exit Codes

- **0**: All rules match successfully
- **1**: One or more rule mismatches detected, or connection error

## Output Format

### Success Case

```
Verifying PocketBase rules...
PocketBase URL: http://127.0.0.1:8090

✓ tenants: all rules match
✓ tenant_licenses: all rules match
✓ school_owners: all rules match
✓ student_profiles: all rules match
✓ student_attendance: all rules match

All rules verified ✓
```

### Mismatch Case

```
Verifying PocketBase rules...
PocketBase URL: http://127.0.0.1:8090

✓ tenants: all rules match
✗ student_profiles: rule mismatches detected
  listRule mismatch:
    Expected: @request.auth.id != '' && (
  @request.auth.is_superadmin = true ||
  @request.auth.tenant_id = tenant_id
)
    Actual:   @request.auth.id != ''
✓ tenant_licenses: all rules match
✓ school_owners: all rules match
✓ student_attendance: all rules match

Summary: 1 collection(s) with mismatches or errors
```

## Verified Collections

The script verifies the following collections:

1. `tenants`
2. `tenant_licenses`
3. `school_owners`
4. `student_profiles`
5. `student_attendance`

For each collection, it checks:

- `listRule`
- `viewRule`
- `createRule`
- `updateRule`
- `deleteRule`

## Testing

Unit tests for the script are located in `test/bin/verify_pocketbase_rules_test.dart`.

Run tests with:

```bash
flutter test test/bin/verify_pocketbase_rules_test.dart
```

## Integration with CI/CD

This script can be integrated into CI/CD pipelines to ensure PocketBase rules are correctly configured before deployment:

```yaml
# Example GitHub Actions workflow
- name: Verify PocketBase Rules
  env:
    POCKETBASE_URL: ${{ secrets.POCKETBASE_URL }}
    POCKETBASE_ADMIN_EMAIL: ${{ secrets.POCKETBASE_ADMIN_EMAIL }}
    POCKETBASE_ADMIN_PASSWORD: ${{ secrets.POCKETBASE_ADMIN_PASSWORD }}
  run: dart run bin/verify_pocketbase_rules.dart
```

## Security Notes

- The script requires admin credentials to access the PocketBase Admin API
- Store credentials securely using environment variables or secrets management
- The script is read-only and does not modify any collection rules
- Admin credentials are only used for authentication and are not logged or stored
