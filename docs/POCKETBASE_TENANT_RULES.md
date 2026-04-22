# PocketBase Tenant Isolation Rules (Scholify)

## Purpose

This document defines baseline collection rules for strict tenant isolation in PocketBase.

## Assumptions

- Every user record has:
  - `tenant_id` (text)
  - `is_superadmin` (bool)
- Every tenant-scoped collection stores `tenant_id`.
- All app writes include `tenant_id`.

## Rule Pattern

Use this pattern for tenant-scoped collections:

```
@request.auth.id != '' && (
  @request.auth.is_superadmin = true ||
  @request.auth.tenant_id = tenant_id
)
```

## Recommended Rules By Collection

### tenants

- listRule

```
@request.auth.id != '' && (
  @request.auth.is_superadmin = true ||
  @request.auth.tenant_id = tenant_id
)
```

- viewRule

```
@request.auth.id != '' && (
  @request.auth.is_superadmin = true ||
  @request.auth.tenant_id = tenant_id
)
```

- createRule

```
@request.auth.id != '' && @request.auth.is_superadmin = true
```

- updateRule

```
@request.auth.id != '' && @request.auth.is_superadmin = true
```

- deleteRule

```
@request.auth.id != '' && @request.auth.is_superadmin = true
```

### tenant_licenses

- listRule/viewRule

```
@request.auth.id != '' && (
  @request.auth.is_superadmin = true ||
  @request.auth.tenant_id = tenant_id
)
```

- createRule/updateRule/deleteRule

```
@request.auth.id != '' && @request.auth.is_superadmin = true
```

### school_owners

- listRule/viewRule

```
@request.auth.id != '' && (
  @request.auth.is_superadmin = true ||
  @request.auth.tenant_id = tenant_id
)
```

- createRule/updateRule

```
@request.auth.id != '' && (
  @request.auth.is_superadmin = true ||
  @request.auth.tenant_id = tenant_id
)
```

- deleteRule

```
@request.auth.id != '' && @request.auth.is_superadmin = true
```

### student_profiles

- listRule/viewRule/createRule/updateRule

```
@request.auth.id != '' && (
  @request.auth.is_superadmin = true ||
  @request.auth.tenant_id = tenant_id
)
```

- deleteRule

```
@request.auth.id != '' && (
  @request.auth.is_superadmin = true ||
  @request.auth.tenant_id = tenant_id
)
```

### student_attendance

- listRule/viewRule/createRule/updateRule

```
@request.auth.id != '' && (
  @request.auth.is_superadmin = true ||
  @request.auth.tenant_id = tenant_id
)
```

- deleteRule

```
@request.auth.id != '' && (
  @request.auth.is_superadmin = true ||
  @request.auth.tenant_id = tenant_id
)
```

## Required Fields and Indexes

For each tenant-scoped collection:

- Required fields:
  - `tenant_id` (text, required)
  - `external_id` (text, optional but recommended)
  - `updated_at` (date)
- Recommended indexes:
  - `tenant_id`
  - `tenant_id, updated_at`
  - unique `external_id` (if used as upsert key)

## Notes

- The Flutter sync layer now sends tenant filter criteria on pull requests for non-superadmin contexts.
- The sync adapter also rejects records whose `tenant_id` does not match the active tenant when tenant scope is enforced.
- Superadmin contexts can pull across tenants.
