# BrandingValidationService

## Overview

The `BrandingValidationService` provides validation for tenant branding settings, specifically logo file size validation according to requirement B3.7 from the scholify-roadmap-tracker spec.

## Features

- **Logo File Size Validation**: Validates that logo images are <= 2 MB (2,097,152 bytes)
- **Descriptive Error Messages**: Provides user-friendly error messages with actual file size
- **Pure Function**: Deterministic validation based solely on file size

## Usage

### Basic Validation

```dart
import 'package:scholify/core/services/branding_validation_service.dart';
import 'dart:typed_data';

final validationService = BrandingValidationService();

// Validate logo size
final imageBytes = Uint8List.fromList([...]); // Your image bytes
final isValid = validationService.validateLogoSize(imageBytes);

if (isValid) {
  print('Logo is valid');
} else {
  print('Logo is too large');
}
```

### Validation with Error Message

```dart
final result = validationService.validateLogoWithMessage(imageBytes);

if (result.isValid) {
  // Proceed with logo upload
  await uploadLogo(imageBytes);
} else {
  // Show error to user
  showError(result.errorMessage!);
}
```

### Custom Error Message

```dart
if (!validationService.validateLogoSize(imageBytes)) {
  final errorMessage = validationService.getLogoSizeErrorMessage(imageBytes.length);
  // Display: "Image must be under 2 MB. Current size: 3.45 MB"
  showSnackbar(errorMessage);
}
```

## Integration Example

### In a Branding Settings Page

```dart
class BrandingSettingsPage extends StatefulWidget {
  @override
  _BrandingSettingsPageState createState() => _BrandingSettingsPageState();
}

class _BrandingSettingsPageState extends State<BrandingSettingsPage> {
  final _validationService = BrandingValidationService();
  Uint8List? _selectedLogo;
  String? _errorMessage;

  Future<void> _pickLogo() async {
    // Use file_picker or image_picker to get image
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      final imageBytes = result.files.single.bytes!;
      
      // Validate logo size
      final validationResult = _validationService.validateLogoWithMessage(imageBytes);
      
      setState(() {
        if (validationResult.isValid) {
          _selectedLogo = imageBytes;
          _errorMessage = null;
        } else {
          _selectedLogo = null;
          _errorMessage = validationResult.errorMessage;
        }
      });
    }
  }

  Future<void> _saveBranding() async {
    if (_selectedLogo == null) return;
    
    // Encode to base64 and save to database
    final base64Logo = base64Encode(_selectedLogo!);
    await database.saveTenantBranding(
      tenantId: tenantContext.tenantId,
      logoBase64: base64Logo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Branding Settings')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _pickLogo,
            child: Text('Upload Logo'),
          ),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red),
            ),
          if (_selectedLogo != null)
            Image.memory(_selectedLogo!, height: 100),
          ElevatedButton(
            onPressed: _selectedLogo != null ? _saveBranding : null,
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
}
```

## Validation Rules

### Property 15: Logo File Size Validation

**Requirement B3.7**: The Branding_Settings_Page SHALL reject images larger than 2 MB and display "Image must be under 2 MB."

**Validation Logic**:
- **Accepts**: Any byte array with size <= 2,097,152 bytes (2 MB)
- **Rejects**: Any byte array with size > 2,097,152 bytes (2 MB)

**Boundary Cases**:
- 0 bytes (empty): ✅ Accepted
- 2,097,152 bytes (exactly 2 MB): ✅ Accepted
- 2,097,153 bytes (2 MB + 1 byte): ❌ Rejected

**Content Independence**: Validation is based solely on file size, not on:
- Image format (PNG, JPEG, etc.)
- Image dimensions
- Image quality
- Byte patterns or content

## Constants

```dart
BrandingValidationService.maxLogoSizeBytes = 2 * 1024 * 1024; // 2,097,152 bytes
```

## Testing

The service is thoroughly tested with property-based tests covering:
- Random file sizes from 0 bytes to 100 MB
- Boundary cases (exactly 2 MB, 2 MB ± 1 byte)
- Deterministic behavior
- Content independence
- Metamorphic properties (adding/removing bytes)
- Different byte patterns

Run tests:
```bash
flutter test test/core/services/branding_validation_service_property_test.dart
```

## Related Components

- **TenantBrandingEntries**: Drift table storing tenant branding data
- **BrandingService**: Service for managing tenant branding (to be implemented)
- **Foundation Shell**: Displays tenant logo and display name

## Future Enhancements

1. **Image Format Validation**: Validate that the file is a valid PNG or JPEG
2. **Image Dimension Validation**: Enforce minimum/maximum dimensions
3. **Image Compression**: Automatically compress images that exceed size limit
4. **Multiple Logo Sizes**: Support different logo sizes for different contexts (app bar, login page, etc.)
5. **Logo Preview**: Generate thumbnail previews before upload

## References

- **Spec**: `.kiro/specs/scholify-roadmap-tracker`
- **Design Document**: Property 15 - Logo File Size Validation
- **Requirements**: B3.7 - Per-Tenant Branding
