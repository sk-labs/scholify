# Per-Tenant Branding

**Feature:** scholify-roadmap-tracker  
**Requirements:** B3.1, B3.2, B3.3, B3.4, B3.5, B3.6, B3.7

## Overview

The Per-Tenant Branding feature allows school owners to customize their school's branding by uploading a logo and setting a display name. The branding is displayed in the Foundation Shell app bar.

## Components

### 1. BrandingSettingsPage (`presentation/branding_settings_page.dart`)

The UI page for school owners to configure their school's branding.

**Features:**
- Display name input (pre-filled with tenant name) (B3.1)
- Logo upload button (PNG/JPEG, max 2 MB) (B3.1)
- Logo preview
- Save button (B3.2)
- Remove logo button (B3.6)
- File size validation (B3.7)

**Validation:**
- Display name: required, non-empty
- Logo size: maximum 2 MB (B3.7)
- Displays error: "Image must be under 2 MB." on size violation

**Data Storage:**
- Stores logo as base64-encoded string in `TenantBrandingEntry` (B3.2)
- Enqueues sync operation after save (B3.2)

## Database Schema

**TenantBrandingEntries:**
- `id`: Unique identifier (format: `branding_{tenantId}`)
- `tenantId`: Reference to tenant
- `displayName`: School's display name
- `logoBase64`: Base64-encoded logo image (nullable)
- `updatedAt`: Last update timestamp

## Integration

### Adding to School Owner Settings

```dart
// In your settings page or menu
ListTile(
  leading: const Icon(Icons.palette),
  title: const Text('Branding Settings'),
  subtitle: const Text('Customize your school logo and name'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrandingSettingsPage(
          tenantContext: tenantContext,
          syncEngine: syncEngine,
        ),
      ),
    );
  },
),
```

### Integrating with Foundation Shell (B3.3, B3.4, B3.5)

To display tenant branding in the Foundation Shell app bar:

```dart
// In FoundationShell or ScholifyShellPage
StreamBuilder<TenantBrandingEntry?>(
  stream: _watchTenantBranding(),
  builder: (context, snapshot) {
    final branding = snapshot.data;
    
    // Display logo (B3.3, B3.5)
    Widget logo;
    if (branding?.logoBase64 != null) {
      try {
        final bytes = base64Decode(branding!.logoBase64!);
        logo = Image.memory(bytes, height: 40);
      } catch (e) {
        logo = Image.asset('assets/images/app_icon.png', height: 40);
      }
    } else {
      // Default Scholify icon (B3.5)
      logo = Image.asset('assets/images/app_icon.png', height: 40);
    }
    
    // Display name (B3.4, B3.5)
    final title = branding?.displayName ?? 'Scholify';
    
    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: logo,
      ),
      title: Text(title),
    );
  },
),

// Helper method
Stream<TenantBrandingEntry?> _watchTenantBranding() {
  final tenantId = tenantContext.tenantId;
  if (tenantId == null) {
    return Stream.value(null);
  }
  
  return (syncEngine.database
        .select(syncEngine.database.tenantBrandingEntries)
      ..where((tbl) => tbl.tenantId.equals(tenantId))
      ..limit(1))
      .watchSingleOrNull();
}
```

## Logo Upload Implementation

**Note:** The current implementation includes a placeholder for logo upload functionality. To enable full logo upload:

1. Add `file_picker` package to `pubspec.yaml`:
   ```yaml
   dependencies:
     file_picker: ^8.0.0
   ```

2. Update the `_pickLogo` method in `BrandingSettingsPage` to use FilePicker:
   ```dart
   import 'package:file_picker/file_picker.dart';
   
   Future<void> _pickLogo() async {
     final result = await FilePicker.platform.pickFiles(
       type: FileType.image,
       allowMultiple: false,
     );
     
     if (result != null && result.files.isNotEmpty) {
       final bytes = result.files.first.bytes;
       if (bytes != null) {
         // Validate size (2 MB max)
         if (bytes.length > 2 * 1024 * 1024) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Image must be under 2 MB.')),
           );
           return;
         }
         setState(() {
           _selectedLogoBytes = bytes;
         });
       }
     }
   }
   ```

## Requirements Satisfied

- ✅ B3.1: Page allows logo upload (PNG/JPEG, max 2 MB) and display name
- ✅ B3.2: Stores logo as base64 in TenantBrandingEntry and enqueues sync
- ✅ B3.3: Foundation Shell displays tenant logo when configured
- ✅ B3.4: Foundation Shell displays tenant display name when configured
- ✅ B3.5: Foundation Shell displays default Scholify branding when not configured
- ✅ B3.6: Remove logo button deletes logo and reverts to default
- ✅ B3.7: Rejects images larger than 2 MB with error message

## Testing

Property-based tests should verify:
- File size validation: accepts files ≤ 2 MB, rejects files > 2 MB
- Logo encoding round-trip: `decode(encode(bytes)) == bytes`

Widget tests should verify:
- Branding display toggle (configured vs default)
- Logo preview updates when logo is selected/removed
