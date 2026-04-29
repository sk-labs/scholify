import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/services/branding_validation_service.dart';
import 'dart:typed_data';
import 'dart:math';

/// Property-based tests for BrandingValidationService - Logo File Size Validation
/// 
/// Feature: scholify-roadmap-tracker
/// Task: 3.6 Write property test for logo file size validation
/// 
/// This test suite validates:
/// - Property 15: Logo file size validation
/// 
/// Requirements: B3.7

void main() {
  late BrandingValidationService validationService;

  setUp(() {
    validationService = BrandingValidationService();
  });

  group('Property 15: Logo file size validation', () {
    /// **Validates: Requirements B3.7**
    /// 
    /// For any byte array representing an image file, the branding service SHALL
    /// accept it if and only if its size is less than or equal to 2,097,152 bytes (2 MB).
    test('logo validation accepts files with size <= 2 MB', () {
      const numIterations = 1000;
      final random = Random(42); // Fixed seed for reproducibility
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate random byte array with various sizes
        final imageBytes = _generateRandomImageBytes(random);
        
        // Validate logo size
        final isValid = validationService.validateLogoSize(imageBytes);
        
        // Calculate expected result: size <= 2,097,152 bytes
        final expectedValid = imageBytes.length <= BrandingValidationService.maxLogoSizeBytes;
        
        // Assert: validation result matches expected
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Logo validation failed for size ${imageBytes.length} bytes',
        );
      }
    });

    test('logos with exactly 2 MB (2,097,152 bytes) are accepted (boundary)', () {
      const numIterations = 100;
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate image with exactly 2 MB
        final imageBytes = _generateImageBytesOfSize(BrandingValidationService.maxLogoSizeBytes);
        
        // Validate
        final isValid = validationService.validateLogoSize(imageBytes);
        
        // Assert: should be accepted (boundary case)
        expect(
          isValid,
          isTrue,
          reason: 'Logo with exactly 2 MB (2,097,152 bytes) should be accepted',
        );
        
        // Verify size
        expect(imageBytes.length, equals(BrandingValidationService.maxLogoSizeBytes));
      }
    });

    test('logos with exactly 2 MB + 1 byte (2,097,153 bytes) are rejected (boundary)', () {
      const numIterations = 100;
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate image with exactly 2 MB + 1 byte
        final imageBytes = _generateImageBytesOfSize(BrandingValidationService.maxLogoSizeBytes + 1);
        
        // Validate
        final isValid = validationService.validateLogoSize(imageBytes);
        
        // Assert: should be rejected (boundary case)
        expect(
          isValid,
          isFalse,
          reason: 'Logo with exactly 2 MB + 1 byte (2,097,153 bytes) should be rejected',
        );
        
        // Verify size
        expect(imageBytes.length, equals(BrandingValidationService.maxLogoSizeBytes + 1));
      }
    });

    test('empty logos (0 bytes) are accepted', () {
      const numIterations = 10;
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Empty byte array
        final imageBytes = Uint8List(0);
        
        // Validate
        final isValid = validationService.validateLogoSize(imageBytes);
        
        // Assert: should be accepted (0 <= 2 MB)
        expect(
          isValid,
          isTrue,
          reason: 'Empty logo (0 bytes) should be accepted',
        );
        
        // Verify size
        expect(imageBytes.length, equals(0));
      }
    });

    test('very small logos (1-1000 bytes) are accepted', () {
      const numIterations = 100;
      final random = Random(100);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate very small image (1-1000 bytes)
        final size = random.nextInt(1000) + 1; // 1 to 1000
        final imageBytes = _generateImageBytesOfSize(size);
        
        // Validate
        final isValid = validationService.validateLogoSize(imageBytes);
        
        // Assert: should be accepted
        expect(
          isValid,
          isTrue,
          reason: 'Very small logo ($size bytes) should be accepted',
        );
        
        // Verify size
        expect(imageBytes.length, equals(size));
      }
    });

    test('small logos (1 KB - 100 KB) are accepted', () {
      const numIterations = 100;
      final random = Random(200);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate small image (1 KB - 100 KB)
        final size = random.nextInt(99 * 1024) + 1024; // 1024 to 102400 bytes
        final imageBytes = _generateImageBytesOfSize(size);
        
        // Validate
        final isValid = validationService.validateLogoSize(imageBytes);
        
        // Assert: should be accepted
        expect(
          isValid,
          isTrue,
          reason: 'Small logo ($size bytes) should be accepted',
        );
        
        // Verify size
        expect(imageBytes.length, equals(size));
      }
    });

    test('medium logos (100 KB - 1 MB) are accepted', () {
      const numIterations = 100;
      final random = Random(300);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate medium image (100 KB - 1 MB)
        final size = random.nextInt(924 * 1024) + 100 * 1024; // 102400 to 1048576 bytes
        final imageBytes = _generateImageBytesOfSize(size);
        
        // Validate
        final isValid = validationService.validateLogoSize(imageBytes);
        
        // Assert: should be accepted
        expect(
          isValid,
          isTrue,
          reason: 'Medium logo ($size bytes) should be accepted',
        );
        
        // Verify size
        expect(imageBytes.length, equals(size));
      }
    });

    test('large logos (1 MB - 2 MB) are accepted', () {
      const numIterations = 100;
      final random = Random(400);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate large image (1 MB - 2 MB)
        final size = random.nextInt(1024 * 1024) + 1024 * 1024; // 1048576 to 2097152 bytes
        final imageBytes = _generateImageBytesOfSize(size);
        
        // Validate
        final isValid = validationService.validateLogoSize(imageBytes);
        
        // Assert: should be accepted
        expect(
          isValid,
          isTrue,
          reason: 'Large logo ($size bytes) should be accepted',
        );
        
        // Verify size
        expect(imageBytes.length, equals(size));
      }
    });

    test('logos slightly over 2 MB (2 MB + 1 byte to 2 MB + 1 KB) are rejected', () {
      const numIterations = 100;
      final random = Random(500);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate image slightly over 2 MB (2 MB + 1 to 2 MB + 1024 bytes)
        final size = BrandingValidationService.maxLogoSizeBytes + random.nextInt(1024) + 1;
        final imageBytes = _generateImageBytesOfSize(size);
        
        // Validate
        final isValid = validationService.validateLogoSize(imageBytes);
        
        // Assert: should be rejected
        expect(
          isValid,
          isFalse,
          reason: 'Logo slightly over 2 MB ($size bytes) should be rejected',
        );
        
        // Verify size
        expect(imageBytes.length, equals(size));
      }
    });

    test('logos significantly over 2 MB (2.1 MB - 10 MB) are rejected', () {
      const numIterations = 100;
      final random = Random(600);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate image significantly over 2 MB (2.1 MB - 10 MB)
        final size = (2.1 * 1024 * 1024).toInt() + random.nextInt((7.9 * 1024 * 1024).toInt());
        final imageBytes = _generateImageBytesOfSize(size);
        
        // Validate
        final isValid = validationService.validateLogoSize(imageBytes);
        
        // Assert: should be rejected
        expect(
          isValid,
          isFalse,
          reason: 'Logo significantly over 2 MB ($size bytes) should be rejected',
        );
        
        // Verify size
        expect(imageBytes.length, equals(size));
      }
    });

    test('very large logos (10 MB - 100 MB) are rejected', () {
      const numIterations = 50;
      final random = Random(700);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate very large image (10 MB - 100 MB)
        final size = 10 * 1024 * 1024 + random.nextInt(90 * 1024 * 1024);
        final imageBytes = _generateImageBytesOfSize(size);
        
        // Validate
        final isValid = validationService.validateLogoSize(imageBytes);
        
        // Assert: should be rejected
        expect(
          isValid,
          isFalse,
          reason: 'Very large logo ($size bytes) should be rejected',
        );
        
        // Verify size
        expect(imageBytes.length, equals(size));
      }
    });

    test('logo validation is deterministic', () {
      const numIterations = 100;
      final random = Random(800);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final imageBytes = _generateRandomImageBytes(random);
        
        // Validate multiple times
        final result1 = validationService.validateLogoSize(imageBytes);
        final result2 = validationService.validateLogoSize(imageBytes);
        final result3 = validationService.validateLogoSize(imageBytes);
        
        // Assert: all results are identical (deterministic)
        expect(
          result1,
          equals(result2),
          reason: 'Validation should be deterministic for size ${imageBytes.length}',
        );
        expect(
          result2,
          equals(result3),
          reason: 'Validation should be deterministic for size ${imageBytes.length}',
        );
      }
    });

    test('edge case logo sizes are handled correctly', () {
      final testCases = [
        (0, true),                                                    // Empty
        (1, true),                                                    // 1 byte
        (1024, true),                                                 // 1 KB
        (1024 * 1024, true),                                          // 1 MB
        (2 * 1024 * 1024 - 1, true),                                  // 2 MB - 1 byte (boundary - accepted)
        (2 * 1024 * 1024, true),                                      // 2 MB exactly (boundary - accepted)
        (2 * 1024 * 1024 + 1, false),                                 // 2 MB + 1 byte (boundary - rejected)
        (3 * 1024 * 1024, false),                                     // 3 MB
        (5 * 1024 * 1024, false),                                     // 5 MB
        (10 * 1024 * 1024, false),                                    // 10 MB
        (BrandingValidationService.maxLogoSizeBytes - 1, true),       // Max - 1
        (BrandingValidationService.maxLogoSizeBytes, true),           // Max exactly
        (BrandingValidationService.maxLogoSizeBytes + 1, false),      // Max + 1
      ];
      
      for (final testCase in testCases) {
        final size = testCase.$1;
        final expectedValid = testCase.$2;
        
        final imageBytes = _generateImageBytesOfSize(size);
        final isValid = validationService.validateLogoSize(imageBytes);
        
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Logo validation failed for size $size bytes',
        );
        
        // Verify size
        expect(imageBytes.length, equals(size));
      }
    });

    test('logo validation only checks size, not content', () {
      const numIterations = 100;
      final random = Random(900);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate two byte arrays with same size but different content
        final size = random.nextInt(5 * 1024 * 1024); // 0 to 5 MB
        final imageBytes1 = _generateImageBytesOfSize(size);
        final imageBytes2 = _generateImageBytesOfSize(size);
        
        // Validate both
        final isValid1 = validationService.validateLogoSize(imageBytes1);
        final isValid2 = validationService.validateLogoSize(imageBytes2);
        
        // Calculate expected result based on size only
        final expectedValid = size <= BrandingValidationService.maxLogoSizeBytes;
        
        // Assert: both have same validation result (content doesn't matter)
        expect(
          isValid1,
          equals(expectedValid),
          reason: 'Validation should be based on size only, not content (size: $size)',
        );
        expect(
          isValid2,
          equals(expectedValid),
          reason: 'Validation should be based on size only, not content (size: $size)',
        );
        expect(
          isValid1,
          equals(isValid2),
          reason: 'Same size should produce same validation result regardless of content',
        );
      }
    });

    test('metamorphic property: adding bytes to valid logo can make it invalid', () {
      const numIterations = 100;
      final random = Random(1000);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate valid logo (0 to 2 MB)
        final validSize = random.nextInt(BrandingValidationService.maxLogoSizeBytes + 1);
        final validImageBytes = _generateImageBytesOfSize(validSize);
        
        // Validate (should be valid)
        final validIsValid = validationService.validateLogoSize(validImageBytes);
        expect(validIsValid, isTrue);
        
        // Add bytes to exceed 2 MB
        final bytesToAdd = random.nextInt(1024 * 1024) + 1; // 1 byte to 1 MB
        final newSize = validSize + bytesToAdd;
        final largerImageBytes = _generateImageBytesOfSize(newSize);
        
        // Validate larger image
        final largerIsValid = validationService.validateLogoSize(largerImageBytes);
        
        // Calculate expected result
        final expectedValid = newSize <= BrandingValidationService.maxLogoSizeBytes;
        
        // Assert: validation matches expected based on new size
        expect(
          largerIsValid,
          equals(expectedValid),
          reason: 'Adding $bytesToAdd bytes to valid logo (size $validSize) '
              'should result in valid=$expectedValid (new size: $newSize)',
        );
      }
    });

    test('metamorphic property: removing bytes from invalid logo can make it valid', () {
      const numIterations = 100;
      final random = Random(1100);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate invalid logo (over 2 MB)
        final invalidSize = BrandingValidationService.maxLogoSizeBytes + 
            random.nextInt(5 * 1024 * 1024) + 1; // 2 MB + 1 byte to 7 MB
        final invalidImageBytes = _generateImageBytesOfSize(invalidSize);
        
        // Validate (should be invalid)
        final invalidIsValid = validationService.validateLogoSize(invalidImageBytes);
        expect(invalidIsValid, isFalse);
        
        // Remove bytes to get under or at 2 MB
        final bytesToRemove = random.nextInt(invalidSize - 1) + 1;
        final newSize = invalidSize - bytesToRemove;
        final smallerImageBytes = _generateImageBytesOfSize(newSize);
        
        // Validate smaller image
        final smallerIsValid = validationService.validateLogoSize(smallerImageBytes);
        
        // Calculate expected result
        final expectedValid = newSize <= BrandingValidationService.maxLogoSizeBytes;
        
        // Assert: validation matches expected based on new size
        expect(
          smallerIsValid,
          equals(expectedValid),
          reason: 'Removing $bytesToRemove bytes from invalid logo (size $invalidSize) '
              'should result in valid=$expectedValid (new size: $newSize)',
        );
      }
    });

    test('comprehensive random logo generation covers all size ranges', () {
      const numIterations = 1000;
      final random = Random(1200);
      
      final sizeRanges = <String, int>{
        'empty': 0,
        'tiny': 0,
        'small': 0,
        'medium': 0,
        'large': 0,
        'at_limit': 0,
        'over_limit': 0,
      };
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final imageBytes = _generateRandomImageBytes(random);
        final size = imageBytes.length;
        
        // Categorize size
        if (size == 0) {
          sizeRanges['empty'] = sizeRanges['empty']! + 1;
        } else if (size < 1024) {
          sizeRanges['tiny'] = sizeRanges['tiny']! + 1;
        } else if (size < 100 * 1024) {
          sizeRanges['small'] = sizeRanges['small']! + 1;
        } else if (size < 1024 * 1024) {
          sizeRanges['medium'] = sizeRanges['medium']! + 1;
        } else if (size < BrandingValidationService.maxLogoSizeBytes) {
          sizeRanges['large'] = sizeRanges['large']! + 1;
        } else if (size == BrandingValidationService.maxLogoSizeBytes) {
          sizeRanges['at_limit'] = sizeRanges['at_limit']! + 1;
        } else {
          sizeRanges['over_limit'] = sizeRanges['over_limit']! + 1;
        }
        
        // Validate
        final isValid = validationService.validateLogoSize(imageBytes);
        final expectedValid = size <= BrandingValidationService.maxLogoSizeBytes;
        
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Logo validation failed for size $size bytes',
        );
      }
      
      // Verify we generated logos across different size ranges
      expect(sizeRanges['tiny']! > 0, isTrue, reason: 'Should generate some tiny logos');
      expect(sizeRanges['small']! > 0, isTrue, reason: 'Should generate some small logos');
      expect(sizeRanges['medium']! > 0, isTrue, reason: 'Should generate some medium logos');
      expect(sizeRanges['large']! > 0, isTrue, reason: 'Should generate some large logos');
      expect(sizeRanges['over_limit']! > 0, isTrue, reason: 'Should generate some over-limit logos');
    });

    test('validateLogoWithMessage returns correct validation result', () {
      const numIterations = 100;
      final random = Random(1300);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final imageBytes = _generateRandomImageBytes(random);
        
        // Validate with message
        final result = validationService.validateLogoWithMessage(imageBytes);
        
        // Calculate expected result
        final expectedValid = imageBytes.length <= BrandingValidationService.maxLogoSizeBytes;
        
        // Assert: validation result matches expected
        expect(
          result.isValid,
          equals(expectedValid),
          reason: 'Validation result should match expected for size ${imageBytes.length}',
        );
        
        // Assert: error message is present only when invalid
        if (expectedValid) {
          expect(
            result.errorMessage,
            isNull,
            reason: 'Error message should be null for valid logo',
          );
        } else {
          expect(
            result.errorMessage,
            isNotNull,
            reason: 'Error message should be present for invalid logo',
          );
          expect(
            result.errorMessage,
            contains('Image must be under 2 MB'),
            reason: 'Error message should mention size limit',
          );
        }
      }
    });

    test('getLogoSizeErrorMessage returns descriptive message', () {
      const numIterations = 50;
      final random = Random(1400);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate size over 2 MB
        final size = BrandingValidationService.maxLogoSizeBytes + 
            random.nextInt(10 * 1024 * 1024) + 1;
        
        // Get error message
        final errorMessage = validationService.getLogoSizeErrorMessage(size);
        
        // Assert: message contains required information
        expect(
          errorMessage,
          contains('Image must be under 2 MB'),
          reason: 'Error message should mention size limit',
        );
        expect(
          errorMessage,
          contains('Current size:'),
          reason: 'Error message should mention current size',
        );
        expect(
          errorMessage,
          contains('MB'),
          reason: 'Error message should include MB unit',
        );
      }
    });

    test('boundary values around 2 MB are handled correctly', () {
      final boundaryTestCases = [
        (BrandingValidationService.maxLogoSizeBytes - 10, true),
        (BrandingValidationService.maxLogoSizeBytes - 5, true),
        (BrandingValidationService.maxLogoSizeBytes - 2, true),
        (BrandingValidationService.maxLogoSizeBytes - 1, true),
        (BrandingValidationService.maxLogoSizeBytes, true),
        (BrandingValidationService.maxLogoSizeBytes + 1, false),
        (BrandingValidationService.maxLogoSizeBytes + 2, false),
        (BrandingValidationService.maxLogoSizeBytes + 5, false),
        (BrandingValidationService.maxLogoSizeBytes + 10, false),
      ];
      
      for (final testCase in boundaryTestCases) {
        final size = testCase.$1;
        final expectedValid = testCase.$2;
        
        final imageBytes = _generateImageBytesOfSize(size);
        final isValid = validationService.validateLogoSize(imageBytes);
        
        expect(
          isValid,
          equals(expectedValid),
          reason: 'Boundary case failed for size $size bytes (expected: $expectedValid)',
        );
      }
    });

    test('validation works with different byte patterns', () {
      const numIterations = 100;
      final random = Random(1500);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final size = random.nextInt(5 * 1024 * 1024);
        
        // Generate byte arrays with different patterns
        final allZeros = Uint8List(size);
        final allOnes = Uint8List(size)..fillRange(0, size, 255);
        final randomBytes = _generateImageBytesOfSize(size);
        final alternating = Uint8List(size);
        for (int i = 0; i < size; i++) {
          alternating[i] = i % 2 == 0 ? 0 : 255;
        }
        
        // Validate all patterns
        final validZeros = validationService.validateLogoSize(allZeros);
        final validOnes = validationService.validateLogoSize(allOnes);
        final validRandom = validationService.validateLogoSize(randomBytes);
        final validAlternating = validationService.validateLogoSize(alternating);
        
        // Calculate expected result
        final expectedValid = size <= BrandingValidationService.maxLogoSizeBytes;
        
        // Assert: all patterns produce same result (content doesn't matter)
        expect(validZeros, equals(expectedValid));
        expect(validOnes, equals(expectedValid));
        expect(validRandom, equals(expectedValid));
        expect(validAlternating, equals(expectedValid));
      }
    });
  });
}

// ── Helper Functions ──────────────────────────────────────────────────────

/// Generates a random image byte array with various sizes
Uint8List _generateRandomImageBytes(Random random) {
  final type = random.nextInt(10);
  
  switch (type) {
    case 0:
      // Empty
      return Uint8List(0);
    case 1:
      // Very small (1-1000 bytes)
      return _generateImageBytesOfSize(random.nextInt(1000) + 1);
    case 2:
      // Small (1 KB - 100 KB)
      return _generateImageBytesOfSize(random.nextInt(99 * 1024) + 1024);
    case 3:
      // Medium (100 KB - 1 MB)
      return _generateImageBytesOfSize(random.nextInt(924 * 1024) + 100 * 1024);
    case 4:
      // Large (1 MB - 2 MB)
      return _generateImageBytesOfSize(random.nextInt(1024 * 1024) + 1024 * 1024);
    case 5:
      // Exactly 2 MB (boundary - valid)
      return _generateImageBytesOfSize(BrandingValidationService.maxLogoSizeBytes);
    case 6:
      // Exactly 2 MB + 1 byte (boundary - invalid)
      return _generateImageBytesOfSize(BrandingValidationService.maxLogoSizeBytes + 1);
    case 7:
      // Slightly over 2 MB (2 MB + 1 byte to 2 MB + 1 KB)
      return _generateImageBytesOfSize(
        BrandingValidationService.maxLogoSizeBytes + random.nextInt(1024) + 1
      );
    case 8:
      // Significantly over 2 MB (2.1 MB - 10 MB)
      return _generateImageBytesOfSize(
        (2.1 * 1024 * 1024).toInt() + random.nextInt((7.9 * 1024 * 1024).toInt())
      );
    case 9:
      // Very large (10 MB - 50 MB)
      return _generateImageBytesOfSize(10 * 1024 * 1024 + random.nextInt(40 * 1024 * 1024));
    default:
      return Uint8List(0);
  }
}

/// Generates an image byte array of exact size
Uint8List _generateImageBytesOfSize(int size) {
  final random = Random(size); // Use size as seed for reproducibility
  final bytes = Uint8List(size);
  
  for (int i = 0; i < size; i++) {
    bytes[i] = random.nextInt(256);
  }
  
  return bytes;
}
