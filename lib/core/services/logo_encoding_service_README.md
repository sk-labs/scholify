# LogoEncodingService

## Overview

The `LogoEncodingService` provides base64 encoding and decoding operations for tenant logo images. This service ensures that logo images can be safely stored as strings in the database and retrieved without data loss.

## Purpose

This service is part of the **Per-Tenant Branding** feature (Requirement B3) in the Scholify Roadmap Tracker. It handles the conversion of binary image data to base64-encoded strings for storage in the `TenantBrandingEntries` table.

## Key Features

- **Base64 Encoding**: Converts raw image bytes to base64 strings
- **Base64 Decoding**: Converts base64 strings back to raw image bytes
- **Round-Trip Verification**: Ensures that encode(decode(bytes)) == bytes
- **Deterministic Operations**: Same input always produces same output

## Core Property

The service guarantees the **round-trip property**:

```
For any valid image byte array:
  decode(encode(bytes)) == bytes
```

This property is validated by Property 16 in the design document and tested with 1000+ iterations across various byte array sizes and patterns.

## Usage

### Basic Encoding and Decoding

```dart
import 'package:scholify/core/services/logo_encoding_service.dart';
import 'dart:typed_data';

final service = LogoEncodingService();

// Encode image bytes to base64
final Uint8List imageBytes = ...; // Load from file
final String base64String = service.encodeLogoToBase64(imageBytes);

// Store base64String in database
await database.into(database.tenantBrandingEntries).insert(
  TenantBrandingEntriesCompanion.insert(
    tenantId: 'tenant_123',
    displayName: 'My School',
    logoBase64: Value(base64String),
  ),
);

// Later, decode base64 back to bytes
final String storedBase64 = ...; // Load from database
final Uint8List decodedBytes = service.decodeLogoFromBase64(storedBase64);

// Display image
Image.memory(decodedBytes);
```

### Verifying Round-Trip Property

```dart
final service = LogoEncodingService();
final Uint8List originalBytes = ...; // Load from file

// Verify that encoding and decoding preserves the original bytes
final bool isValid = service.verifyRoundTrip(originalBytes);

if (isValid) {
  print('Round-trip successful: bytes preserved');
} else {
  print('Round-trip failed: data loss detected');
}
```

### Comparing Byte Arrays

```dart
final service = LogoEncodingService();
final Uint8List bytes1 = ...;
final Uint8List bytes2 = ...;

final bool areEqual = service.bytesEqual(bytes1, bytes2);

if (areEqual) {
  print('Byte arrays are identical');
} else {
  print('Byte arrays differ');
}
```

## Integration with Branding Feature

The `LogoEncodingService` is used in conjunction with the `BrandingValidationService` to implement the complete branding workflow:

1. **Upload**: User selects a logo image file
2. **Validate**: `BrandingValidationService.validateLogoSize()` checks size <= 2 MB
3. **Encode**: `LogoEncodingService.encodeLogoToBase64()` converts to base64
4. **Store**: Save base64 string to `TenantBrandingEntries.logoBase64`
5. **Sync**: Enqueue for push sync to PocketBase
6. **Retrieve**: Load base64 string from database
7. **Decode**: `LogoEncodingService.decodeLogoFromBase64()` converts back to bytes
8. **Display**: Render image in app bar using `Image.memory()`

## Testing

The service is validated by comprehensive property-based tests in `test/core/services/logo_encoding_service_property_test.dart`:

- **1000+ iterations** across various byte array sizes (0 bytes to 2 MB)
- **All byte patterns**: zeros, ones, alternating, sequential, random
- **Edge cases**: empty arrays, single bytes, multiples of 3, non-multiples of 3
- **Metamorphic properties**: double round-trip, encoding uniqueness
- **Determinism**: same input always produces same output

### Running Tests

```bash
# Run logo encoding property tests
flutter test test/core/services/logo_encoding_service_property_test.dart

# Run all property tests
flutter test test/core/services/
```

## Requirements Validation

This service validates:

- **Requirement B3.2**: Store logo as base64-encoded string in `TenantBrandingEntry`
- **Requirement B3.8**: Round-trip property (Property 16 in design document)

## Design Document References

- **Design Document**: `.kiro/specs/scholify-roadmap-tracker/design.md`
- **Property 16**: Logo encoding round-trip
- **Requirements**: B3.2, B3.8
- **Task**: 3.7 Write property test for logo encoding round-trip

## Implementation Notes

### Base64 Encoding Details

- Uses Dart's built-in `dart:convert` library (`base64Encode` and `base64Decode`)
- Encoding works in 3-byte blocks, producing 4 base64 characters per block
- Padding (`=`) is added for byte arrays not divisible by 3
- Encoded strings are approximately 33% larger than original bytes

### Performance Considerations

- Encoding/decoding is fast for typical logo sizes (< 2 MB)
- For very large images, consider running on a background isolate
- Base64 strings are stored in database as TEXT columns

### Error Handling

- `decodeLogoFromBase64()` throws `FormatException` if base64 string is invalid
- Callers should wrap decode operations in try-catch blocks
- Invalid base64 strings indicate data corruption or tampering

## Related Services

- **BrandingValidationService**: Validates logo file size (max 2 MB)
- **TenantBrandingEntries**: Drift table storing logo base64 strings
- **FoundationShell**: Displays tenant logo in app bar

## Future Enhancements

- **Image Compression**: Add client-side compression before encoding to reduce storage
- **Object Storage**: Move logos from database to S3/CDN for production scale
- **Format Validation**: Verify image format (PNG/JPEG) before encoding
- **Thumbnail Generation**: Create smaller versions for list views

## Changelog

- **2024-01-XX**: Initial implementation with round-trip property validation
