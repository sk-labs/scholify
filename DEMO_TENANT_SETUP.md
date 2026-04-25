# Demo Tenant Setup Guide

## Overview
This guide walks you through creating a demo tenant in your PocketBase instance at `https://vm-hms.lixcure.com` so you can test the Scholify app.

## Prerequisites
- PocketBase instance running at: `https://vm-hms.lixcure.com`
- Superuser credentials:
  - Email: `shakirullah@email.com`
  - Password: `KhanPsn@302`
- App configured to use production URL (already done in `lib/core/constants/branding.dart`)

## Step 1: Access PocketBase Admin Panel

1. Open your browser and navigate to: `https://vm-hms.lixcure.com/_/`
2. Sign in with the superuser credentials above

## Step 2: Create Required Collections (if not already created)

### A. Create `tenants` Collection

If the `tenants` collection doesn't exist:

1. Go to **Collections** → **New Collection**
2. Name: `tenants`
3. Type: **Base**
4. Add fields:
   - `tenant_id` (Text, Required, Unique)
   - `name` (Text, Required)
   - `is_active` (Bool, Default: true)
   - `updated_at` (Date)

5. Set API Rules (see `docs/POCKETBASE_TENANT_RULES.md` for details):
   - **List Rule**: `@request.auth.id != '' && (@request.auth.is_superadmin = true || @request.auth.tenant_id = tenant_id)`
   - **View Rule**: Same as List Rule
   - **Create Rule**: `@request.auth.id != '' && @request.auth.is_superadmin = true`
   - **Update Rule**: `@request.auth.id != '' && @request.auth.is_superadmin = true`
   - **Delete Rule**: `@request.auth.id != '' && @request.auth.is_superadmin = true`

### B. Verify/Update `users` Collection

The `users` collection should already exist (it's a PocketBase auth collection). Ensure it has these fields:

1. Go to **Collections** → **users**
2. Add/verify fields:
   - `tenant_id` (Text, Required for non-superadmin users)
   - `tenant_name` (Text)
   - `role` (Text, Default: "school_owner")
   - `is_superadmin` (Bool, Default: false)

## Step 3: Create Demo Tenant Record

1. Go to **Collections** → **tenants**
2. Click **New Record**
3. Fill in:
   - `tenant_id`: `demo_school_001`
   - `name`: `Demo School`
   - `is_active`: `true` (checked)
   - `updated_at`: (current date/time)
4. Click **Create**

## Step 4: Create Demo User Account

1. Go to **Collections** → **users**
2. Click **New Record**
3. Fill in:
   - `email`: `demo@school.com`
   - `password`: `Demo@123` (or your preferred password)
   - `passwordConfirm`: `Demo@123`
   - `tenant_id`: `demo_school_001`
   - `tenant_name`: `Demo School`
   - `role`: `school_owner`
   - `is_superadmin`: `false` (unchecked)
   - `verified`: `true` (checked - to skip email verification)
4. Click **Create**

## Step 5: Test Sign-In from Scholify App

1. If the app is running, hot reload it (press `r` in the terminal)
   - If not running, start it with: `flutter run -d windows`

2. On the login screen, enter:
   - **Email**: `demo@school.com`
   - **Password**: `Demo@123`

3. Click **Sign In**

4. You should be logged in as a school owner for "Demo School"

## Step 6: Add Sample Data (Optional)

To make the demo more realistic, you can add sample data to other collections:

### Student Profiles
1. Go to **Collections** → **student_profiles** (create if needed)
2. Add fields: `student_id`, `tenant_id`, `full_name`, `class_section`, `roll_no`, etc.
3. Create a few sample student records with `tenant_id = demo_school_001`

### Notice Boards
1. Go to **Collections** → **notice_boards** (create if needed)
2. Add a sample notice with `tenant_id = demo_school_001`

### Timetable Slots
1. Go to **Collections** → **timetable_slots** (create if needed)
2. Add sample timetable entries

## Troubleshooting

### Issue: "Invalid credentials" error
- Verify the email and password are correct
- Check that the user's `verified` field is set to `true`
- Ensure `tenant_id` is not empty

### Issue: "No tenant found" error
- Verify the tenant record exists with matching `tenant_id`
- Check that `is_active` is `true` on the tenant

### Issue: App shows empty data
- Verify sample data records have the correct `tenant_id`
- Check API rules allow the user to read records
- Ensure the user's `tenant_id` matches the data's `tenant_id`

### Issue: Connection error
- Verify the PocketBase URL in `lib/core/constants/branding.dart` is correct
- Check that `https://vm-hms.lixcure.com` is accessible
- Ensure SSL certificate is valid

## Next Steps

After successful login, you can:
1. Navigate through different features (Dashboard, Students, Attendance, etc.)
2. Test creating/editing records
3. Verify tenant isolation (data from other tenants should not be visible)
4. Test the sync functionality

## Demo Credentials Summary

**PocketBase Admin:**
- URL: `https://vm-hms.lixcure.com/_/`
- Email: `shakirullah@email.com`
- Password: `KhanPsn@302`

**Demo School Owner:**
- Email: `demo@school.com`
- Password: `Demo@123`
- Tenant: `demo_school_001` (Demo School)

## Collection Schema Reference

For complete collection schemas and API rules, see:
- `docs/POCKETBASE_TENANT_RULES.md` - Tenant isolation rules
- `lib/core/remote/pocketbase_gateway.dart` - Collection names and field mappings
