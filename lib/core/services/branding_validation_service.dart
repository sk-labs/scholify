import 'dart:typed_data';

/// Service for validating branding-related inputs
/// 
/// Feature: scholify-roadmap-tracker
/// Requirements: B3.7
/// 
/// This service provides validation for tenant branding settings,
/// including logo file size validation.
class BrandingValidationService {
  /// Maximum allowed logo file size in bytes (2 MB)
  static const int maxLogoSizeBytes = 2 * 1024 * 1024; // 2,097,152 bytes

  /// Validates logo file size according to B3.7
  /// 
  /// Property 15: Logo File Size Validation
  /// 
  /// For any byte array representing an image file, the branding service SHALL
  /// accept it if and only if its size is less than or equal to 2,097,152 bytes (2 MB).
  /// 
  /// Parameters:
  /// - [imageBytes]: The byte array representing the image file
  /// 
  /// Returns:
  /// - `true` if the image size is <= 2 MB (2,097,152 bytes)
  /// - `false` otherwise
  bool validateLogoSize(Uint8List imageBytes) {
    return imageBytes.length <= maxLogoSizeBytes;
  }

  /// Gets a human-readable error message for logo size validation failure
  /// 
  /// Parameters:
  /// - [actualSizeBytes]: The actual size of the image in bytes
  /// 
  /// Returns:
  /// - A descriptive error message
  String getLogoSizeErrorMessage(int actualSizeBytes) {
    final actualSizeMB = (actualSizeBytes / (1024 * 1024)).toStringAsFixed(2);
    return 'Image must be under 2 MB. Current size: $actualSizeMB MB';
  }

  /// Validates logo file size and returns a validation result
  /// 
  /// Parameters:
  /// - [imageBytes]: The byte array representing the image file
  /// 
  /// Returns:
  /// - A [LogoValidationResult] containing validation status and error message
  LogoValidationResult validateLogoWithMessage(Uint8List imageBytes) {
    final isValid = validateLogoSize(imageBytes);
    
    if (isValid) {
      return LogoValidationResult(
        isValid: true,
        errorMessage: null,
      );
    } else {
      return LogoValidationResult(
        isValid: false,
        errorMessage: getLogoSizeErrorMessage(imageBytes.length),
      );
    }
  }
}

/// Result of logo validation
class LogoValidationResult {
  /// Whether the logo is valid
  final bool isValid;
  
  /// Error message if validation failed, null otherwise
  final String? errorMessage;

  const LogoValidationResult({
    required this.isValid,
    this.errorMessage,
  });
}
