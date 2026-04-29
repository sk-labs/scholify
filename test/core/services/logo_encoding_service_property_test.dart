import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/services/logo_encoding_service.dart';
import 'dart:typed_data';
import 'dart:math';

/// Property-based tests for LogoEncodingService - Logo Encoding Round-Trip
/// 
/// Feature: scholify-roadmap-tracker
/// Task: 3.7 Write property test for logo encoding round-trip
/// 
/// This test suite validates:
/// - Property 16: Logo encoding round-trip
/// 
/// Requirements: B3.8

void main() {
  late LogoEncodingService encodingService;

  setUp(() {
    encodingService = LogoEncodingService();
  });

  group('Property 16: Logo encoding round-trip', () {
    /// **Validates: Requirements B3.8**
    /// 
    /// For any valid image byte array, encoding to base64 and then decoding
    /// SHALL produce a byte array equal to the original.
    /// 
    /// This is the fundamental round-trip property:
    /// decode(encode(bytes)) == bytes
    test('encoding and decoding preserves original bytes for arbitrary byte arrays', () {
      const numIterations = 1000;
      final random = Random(42); // Fixed seed for reproducibility
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        // Generate random byte array with various sizes
        final originalBytes = _generateRandomBytes(random);
        
        // Encode to base64
        final encoded = encodingService.encodeLogoToBase64(originalBytes);
        
        // Decode back to bytes
        final decodedBytes = encodingService.decodeLogoFromBase64(encoded);
        
        // Assert: decoded bytes equal original bytes
        expect(
          decodedBytes.length,
          equals(originalBytes.length),
          reason: 'Round-trip failed: length mismatch for ${originalBytes.length} bytes',
        );
        
        // Check byte-by-byte equality
        for (int i = 0; i < originalBytes.length; i++) {
          expect(
            decodedBytes[i],
            equals(originalBytes[i]),
            reason: 'Round-trip failed: byte mismatch at index $i for ${originalBytes.length} bytes',
          );
        }
      }
    });

    test('round-trip property holds for empty byte arrays', () {
      const numIterations = 10;
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final originalBytes = Uint8List(0);
        
        // Encode and decode
        final encoded = encodingService.encodeLogoToBase64(originalBytes);
        final decodedBytes = encodingService.decodeLogoFromBase64(encoded);
        
        // Assert: empty array preserved
        expect(
          decodedBytes.length,
          equals(0),
          reason: 'Empty byte array should remain empty after round-trip',
        );
      }
    });

    test('round-trip property holds for single-byte arrays', () {
      const numIterations = 256;
      
      for (int byteValue = 0; byteValue < numIterations; byteValue++) {
        final originalBytes = Uint8List.fromList([byteValue]);
        
        // Encode and decode
        final encoded = encodingService.encodeLogoToBase64(originalBytes);
        final decodedBytes = encodingService.decodeLogoFromBase64(encoded);
        
        // Assert: single byte preserved
        expect(
          decodedBytes.length,
          equals(1),
          reason: 'Single byte array should have length 1 after round-trip',
        );
        expect(
          decodedBytes[0],
          equals(byteValue),
          reason: 'Single byte value $byteValue should be preserved after round-trip',
        );
      }
    });

    test('round-trip property holds for very small byte arrays (2-100 bytes)', () {
      const numIterations = 100;
      final random = Random(100);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final size = random.nextInt(99) + 2; // 2 to 100 bytes
        final originalBytes = _generateBytesOfSize(size, random);
        
        // Encode and decode
        final encoded = encodingService.encodeLogoToBase64(originalBytes);
        final decodedBytes = encodingService.decodeLogoFromBase64(encoded);
        
        // Assert: bytes preserved
        expect(
          decodedBytes.length,
          equals(originalBytes.length),
          reason: 'Round-trip failed for very small array of $size bytes',
        );
        expect(
          encodingService.bytesEqual(decodedBytes, originalBytes),
          isTrue,
          reason: 'Round-trip failed: bytes not equal for very small array of $size bytes',
        );
      }
    });

    test('round-trip property holds for small byte arrays (100 bytes - 10 KB)', () {
      const numIterations = 100;
      final random = Random(200);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final size = random.nextInt(10 * 1024 - 100) + 100; // 100 to 10240 bytes
        final originalBytes = _generateBytesOfSize(size, random);
        
        // Encode and decode
        final encoded = encodingService.encodeLogoToBase64(originalBytes);
        final decodedBytes = encodingService.decodeLogoFromBase64(encoded);
        
        // Assert: bytes preserved
        expect(
          decodedBytes.length,
          equals(originalBytes.length),
          reason: 'Round-trip failed for small array of $size bytes',
        );
        expect(
          encodingService.bytesEqual(decodedBytes, originalBytes),
          isTrue,
          reason: 'Round-trip failed: bytes not equal for small array of $size bytes',
        );
      }
    });

    test('round-trip property holds for medium byte arrays (10 KB - 100 KB)', () {
      const numIterations = 100;
      final random = Random(300);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final size = random.nextInt(90 * 1024) + 10 * 1024; // 10240 to 102400 bytes
        final originalBytes = _generateBytesOfSize(size, random);
        
        // Encode and decode
        final encoded = encodingService.encodeLogoToBase64(originalBytes);
        final decodedBytes = encodingService.decodeLogoFromBase64(encoded);
        
        // Assert: bytes preserved
        expect(
          decodedBytes.length,
          equals(originalBytes.length),
          reason: 'Round-trip failed for medium array of $size bytes',
        );
        expect(
          encodingService.bytesEqual(decodedBytes, originalBytes),
          isTrue,
          reason: 'Round-trip failed: bytes not equal for medium array of $size bytes',
        );
      }
    });

    test('round-trip property holds for large byte arrays (100 KB - 1 MB)', () {
      const numIterations = 50;
      final random = Random(400);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final size = random.nextInt(924 * 1024) + 100 * 1024; // 102400 to 1048576 bytes
        final originalBytes = _generateBytesOfSize(size, random);
        
        // Encode and decode
        final encoded = encodingService.encodeLogoToBase64(originalBytes);
        final decodedBytes = encodingService.decodeLogoFromBase64(encoded);
        
        // Assert: bytes preserved
        expect(
          decodedBytes.length,
          equals(originalBytes.length),
          reason: 'Round-trip failed for large array of $size bytes',
        );
        expect(
          encodingService.bytesEqual(decodedBytes, originalBytes),
          isTrue,
          reason: 'Round-trip failed: bytes not equal for large array of $size bytes',
        );
      }
    });

    test('round-trip property holds for very large byte arrays (1 MB - 2 MB)', () {
      const numIterations = 20;
      final random = Random(500);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final size = random.nextInt(1024 * 1024) + 1024 * 1024; // 1048576 to 2097152 bytes
        final originalBytes = _generateBytesOfSize(size, random);
        
        // Encode and decode
        final encoded = encodingService.encodeLogoToBase64(originalBytes);
        final decodedBytes = encodingService.decodeLogoFromBase64(encoded);
        
        // Assert: bytes preserved
        expect(
          decodedBytes.length,
          equals(originalBytes.length),
          reason: 'Round-trip failed for very large array of $size bytes',
        );
        expect(
          encodingService.bytesEqual(decodedBytes, originalBytes),
          isTrue,
          reason: 'Round-trip failed: bytes not equal for very large array of $size bytes',
        );
      }
    });

    test('round-trip property holds for byte arrays with all zeros', () {
      const numIterations = 50;
      final random = Random(600);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final size = random.nextInt(100 * 1024) + 1; // 1 to 102400 bytes
        final originalBytes = Uint8List(size); // All zeros by default
        
        // Encode and decode
        final encoded = encodingService.encodeLogoToBase64(originalBytes);
        final decodedBytes = encodingService.decodeLogoFromBase64(encoded);
        
        // Assert: bytes preserved
        expect(
          decodedBytes.length,
          equals(originalBytes.length),
          reason: 'Round-trip failed for all-zeros array of $size bytes',
        );
        expect(
          encodingService.bytesEqual(decodedBytes, originalBytes),
          isTrue,
          reason: 'Round-trip failed: bytes not equal for all-zeros array of $size bytes',
        );
      }
    });

    test('round-trip property holds for byte arrays with all ones (255)', () {
      const numIterations = 50;
      final random = Random(700);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final size = random.nextInt(100 * 1024) + 1; // 1 to 102400 bytes
        final originalBytes = Uint8List(size)..fillRange(0, size, 255);
        
        // Encode and decode
        final encoded = encodingService.encodeLogoToBase64(originalBytes);
        final decodedBytes = encodingService.decodeLogoFromBase64(encoded);
        
        // Assert: bytes preserved
        expect(
          decodedBytes.length,
          equals(originalBytes.length),
          reason: 'Round-trip failed for all-ones array of $size bytes',
        );
        expect(
          encodingService.bytesEqual(decodedBytes, originalBytes),
          isTrue,
          reason: 'Round-trip failed: bytes not equal for all-ones array of $size bytes',
        );
      }
    });

    test('round-trip property holds for byte arrays with alternating patterns', () {
      const numIterations = 50;
      final random = Random(800);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final size = random.nextInt(100 * 1024) + 1; // 1 to 102400 bytes
        final originalBytes = Uint8List(size);
        
        // Create alternating pattern
        for (int i = 0; i < size; i++) {
          originalBytes[i] = i % 2 == 0 ? 0 : 255;
        }
        
        // Encode and decode
        final encoded = encodingService.encodeLogoToBase64(originalBytes);
        final decodedBytes = encodingService.decodeLogoFromBase64(encoded);
        
        // Assert: bytes preserved
        expect(
          decodedBytes.length,
          equals(originalBytes.length),
          reason: 'Round-trip failed for alternating pattern array of $size bytes',
        );
        expect(
          encodingService.bytesEqual(decodedBytes, originalBytes),
          isTrue,
          reason: 'Round-trip failed: bytes not equal for alternating pattern array of $size bytes',
        );
      }
    });

    test('round-trip property holds for byte arrays with sequential values', () {
      const numIterations = 50;
      final random = Random(900);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final size = random.nextInt(10 * 1024) + 1; // 1 to 10240 bytes
        final originalBytes = Uint8List(size);
        
        // Create sequential pattern (0, 1, 2, ..., 255, 0, 1, ...)
        for (int i = 0; i < size; i++) {
          originalBytes[i] = i % 256;
        }
        
        // Encode and decode
        final encoded = encodingService.encodeLogoToBase64(originalBytes);
        final decodedBytes = encodingService.decodeLogoFromBase64(encoded);
        
        // Assert: bytes preserved
        expect(
          decodedBytes.length,
          equals(originalBytes.length),
          reason: 'Round-trip failed for sequential pattern array of $size bytes',
        );
        expect(
          encodingService.bytesEqual(decodedBytes, originalBytes),
          isTrue,
          reason: 'Round-trip failed: bytes not equal for sequential pattern array of $size bytes',
        );
      }
    });

    test('encoding is deterministic (same input produces same output)', () {
      const numIterations = 100;
      final random = Random(1000);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final originalBytes = _generateRandomBytes(random);
        
        // Encode multiple times
        final encoded1 = encodingService.encodeLogoToBase64(originalBytes);
        final encoded2 = encodingService.encodeLogoToBase64(originalBytes);
        final encoded3 = encodingService.encodeLogoToBase64(originalBytes);
        
        // Assert: all encodings are identical
        expect(
          encoded1,
          equals(encoded2),
          reason: 'Encoding should be deterministic for ${originalBytes.length} bytes',
        );
        expect(
          encoded2,
          equals(encoded3),
          reason: 'Encoding should be deterministic for ${originalBytes.length} bytes',
        );
      }
    });

    test('decoding is deterministic (same input produces same output)', () {
      const numIterations = 100;
      final random = Random(1100);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final originalBytes = _generateRandomBytes(random);
        final encoded = encodingService.encodeLogoToBase64(originalBytes);
        
        // Decode multiple times
        final decoded1 = encodingService.decodeLogoFromBase64(encoded);
        final decoded2 = encodingService.decodeLogoFromBase64(encoded);
        final decoded3 = encodingService.decodeLogoFromBase64(encoded);
        
        // Assert: all decodings are identical
        expect(
          encodingService.bytesEqual(decoded1, decoded2),
          isTrue,
          reason: 'Decoding should be deterministic for ${originalBytes.length} bytes',
        );
        expect(
          encodingService.bytesEqual(decoded2, decoded3),
          isTrue,
          reason: 'Decoding should be deterministic for ${originalBytes.length} bytes',
        );
      }
    });

    test('verifyRoundTrip method correctly validates round-trip property', () {
      const numIterations = 100;
      final random = Random(1200);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final originalBytes = _generateRandomBytes(random);
        
        // Verify round-trip
        final isValid = encodingService.verifyRoundTrip(originalBytes);
        
        // Assert: round-trip should always be valid
        expect(
          isValid,
          isTrue,
          reason: 'verifyRoundTrip should return true for ${originalBytes.length} bytes',
        );
      }
    });

    test('roundTripEncodeDecode method preserves bytes', () {
      const numIterations = 100;
      final random = Random(1300);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final originalBytes = _generateRandomBytes(random);
        
        // Perform round-trip
        final roundTrippedBytes = encodingService.roundTripEncodeDecode(originalBytes);
        
        // Assert: bytes preserved
        expect(
          encodingService.bytesEqual(roundTrippedBytes, originalBytes),
          isTrue,
          reason: 'roundTripEncodeDecode should preserve bytes for ${originalBytes.length} bytes',
        );
      }
    });

    test('bytesEqual method correctly compares byte arrays', () {
      const numIterations = 100;
      final random = Random(1400);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final bytes1 = _generateRandomBytes(random);
        final bytes2 = Uint8List.fromList(bytes1); // Copy
        final bytes3 = _generateRandomBytes(random); // Different
        
        // Assert: identical bytes are equal
        expect(
          encodingService.bytesEqual(bytes1, bytes2),
          isTrue,
          reason: 'Identical byte arrays should be equal',
        );
        
        // Assert: different bytes are not equal (unless by chance)
        if (bytes1.length != bytes3.length || !encodingService.bytesEqual(bytes1, bytes3)) {
          expect(
            encodingService.bytesEqual(bytes1, bytes3),
            isFalse,
            reason: 'Different byte arrays should not be equal',
          );
        }
      }
    });

    test('metamorphic property: double round-trip equals single round-trip', () {
      const numIterations = 100;
      final random = Random(1500);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final originalBytes = _generateRandomBytes(random);
        
        // Single round-trip
        final singleRoundTrip = encodingService.roundTripEncodeDecode(originalBytes);
        
        // Double round-trip
        final doubleRoundTrip = encodingService.roundTripEncodeDecode(singleRoundTrip);
        
        // Assert: both should equal original
        expect(
          encodingService.bytesEqual(singleRoundTrip, originalBytes),
          isTrue,
          reason: 'Single round-trip should equal original',
        );
        expect(
          encodingService.bytesEqual(doubleRoundTrip, originalBytes),
          isTrue,
          reason: 'Double round-trip should equal original',
        );
        expect(
          encodingService.bytesEqual(singleRoundTrip, doubleRoundTrip),
          isTrue,
          reason: 'Single and double round-trip should be equal',
        );
      }
    });

    test('metamorphic property: encoding different bytes produces different base64', () {
      const numIterations = 100;
      final random = Random(1600);
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final bytes1 = _generateRandomBytes(random);
        final bytes2 = _generateRandomBytes(random);
        
        // Skip if bytes happen to be identical
        if (encodingService.bytesEqual(bytes1, bytes2)) {
          continue;
        }
        
        // Encode both
        final encoded1 = encodingService.encodeLogoToBase64(bytes1);
        final encoded2 = encodingService.encodeLogoToBase64(bytes2);
        
        // Assert: different bytes should produce different base64
        expect(
          encoded1,
          isNot(equals(encoded2)),
          reason: 'Different byte arrays should produce different base64 strings',
        );
      }
    });

    test('edge case: byte arrays with sizes that are multiples of 3', () {
      // Base64 encoding works in groups of 3 bytes
      final testSizes = [3, 6, 9, 12, 15, 30, 60, 90, 300, 3000, 30000];
      
      for (final size in testSizes) {
        final originalBytes = _generateBytesOfSize(size, Random(size));
        
        // Encode and decode
        final encoded = encodingService.encodeLogoToBase64(originalBytes);
        final decodedBytes = encodingService.decodeLogoFromBase64(encoded);
        
        // Assert: bytes preserved
        expect(
          encodingService.bytesEqual(decodedBytes, originalBytes),
          isTrue,
          reason: 'Round-trip failed for size $size (multiple of 3)',
        );
      }
    });

    test('edge case: byte arrays with sizes that are NOT multiples of 3', () {
      // Base64 encoding adds padding for non-multiples of 3
      final testSizes = [1, 2, 4, 5, 7, 8, 10, 11, 31, 61, 91, 301, 3001, 30001];
      
      for (final size in testSizes) {
        final originalBytes = _generateBytesOfSize(size, Random(size));
        
        // Encode and decode
        final encoded = encodingService.encodeLogoToBase64(originalBytes);
        final decodedBytes = encodingService.decodeLogoFromBase64(encoded);
        
        // Assert: bytes preserved
        expect(
          encodingService.bytesEqual(decodedBytes, originalBytes),
          isTrue,
          reason: 'Round-trip failed for size $size (not multiple of 3)',
        );
      }
    });

    test('comprehensive random byte generation covers all size ranges', () {
      const numIterations = 1000;
      final random = Random(1700);
      
      final sizeRanges = <String, int>{
        'empty': 0,
        'tiny': 0,
        'small': 0,
        'medium': 0,
        'large': 0,
        'very_large': 0,
      };
      
      for (int iteration = 0; iteration < numIterations; iteration++) {
        final originalBytes = _generateRandomBytes(random);
        final size = originalBytes.length;
        
        // Categorize size
        if (size == 0) {
          sizeRanges['empty'] = sizeRanges['empty']! + 1;
        } else if (size < 100) {
          sizeRanges['tiny'] = sizeRanges['tiny']! + 1;
        } else if (size < 10 * 1024) {
          sizeRanges['small'] = sizeRanges['small']! + 1;
        } else if (size < 100 * 1024) {
          sizeRanges['medium'] = sizeRanges['medium']! + 1;
        } else if (size < 1024 * 1024) {
          sizeRanges['large'] = sizeRanges['large']! + 1;
        } else {
          sizeRanges['very_large'] = sizeRanges['very_large']! + 1;
        }
        
        // Verify round-trip
        final isValid = encodingService.verifyRoundTrip(originalBytes);
        
        expect(
          isValid,
          isTrue,
          reason: 'Round-trip failed for size $size bytes',
        );
      }
      
      // Verify we generated bytes across different size ranges
      expect(sizeRanges['tiny']! > 0, isTrue, reason: 'Should generate some tiny byte arrays');
      expect(sizeRanges['small']! > 0, isTrue, reason: 'Should generate some small byte arrays');
      expect(sizeRanges['medium']! > 0, isTrue, reason: 'Should generate some medium byte arrays');
      expect(sizeRanges['large']! > 0, isTrue, reason: 'Should generate some large byte arrays');
    });

    test('boundary values around base64 encoding block sizes are handled correctly', () {
      // Base64 encoding works in 3-byte blocks, producing 4 characters
      final boundaryTestCases = [
        0,    // Empty
        1,    // 1 byte (needs padding)
        2,    // 2 bytes (needs padding)
        3,    // 3 bytes (no padding)
        4,    // 4 bytes (needs padding)
        5,    // 5 bytes (needs padding)
        6,    // 6 bytes (no padding)
        255,  // Edge case
        256,  // Edge case
        1023, // Edge case
        1024, // 1 KB
        1025, // 1 KB + 1
      ];
      
      for (final size in boundaryTestCases) {
        final originalBytes = _generateBytesOfSize(size, Random(size));
        
        // Encode and decode
        final encoded = encodingService.encodeLogoToBase64(originalBytes);
        final decodedBytes = encodingService.decodeLogoFromBase64(encoded);
        
        // Assert: bytes preserved
        expect(
          encodingService.bytesEqual(decodedBytes, originalBytes),
          isTrue,
          reason: 'Boundary case failed for size $size bytes',
        );
      }
    });
  });
}

// ── Helper Functions ──────────────────────────────────────────────────────

/// Generates a random byte array with various sizes
Uint8List _generateRandomBytes(Random random) {
  final type = random.nextInt(10);
  
  switch (type) {
    case 0:
      // Empty
      return Uint8List(0);
    case 1:
      // Very small (1-100 bytes)
      return _generateBytesOfSize(random.nextInt(100) + 1, random);
    case 2:
      // Small (100 bytes - 10 KB)
      return _generateBytesOfSize(random.nextInt(10 * 1024 - 100) + 100, random);
    case 3:
      // Medium (10 KB - 100 KB)
      return _generateBytesOfSize(random.nextInt(90 * 1024) + 10 * 1024, random);
    case 4:
      // Large (100 KB - 1 MB)
      return _generateBytesOfSize(random.nextInt(924 * 1024) + 100 * 1024, random);
    case 5:
      // Very large (1 MB - 2 MB)
      return _generateBytesOfSize(random.nextInt(1024 * 1024) + 1024 * 1024, random);
    case 6:
      // Single byte
      return Uint8List.fromList([random.nextInt(256)]);
    case 7:
      // All zeros (various sizes)
      return Uint8List(random.nextInt(10 * 1024) + 1);
    case 8:
      // All ones (various sizes)
      final size = random.nextInt(10 * 1024) + 1;
      return Uint8List(size)..fillRange(0, size, 255);
    case 9:
      // Alternating pattern (various sizes)
      final size = random.nextInt(10 * 1024) + 1;
      final bytes = Uint8List(size);
      for (int i = 0; i < size; i++) {
        bytes[i] = i % 2 == 0 ? 0 : 255;
      }
      return bytes;
    default:
      return Uint8List(0);
  }
}

/// Generates a byte array of exact size with random content
Uint8List _generateBytesOfSize(int size, Random random) {
  final bytes = Uint8List(size);
  
  for (int i = 0; i < size; i++) {
    bytes[i] = random.nextInt(256);
  }
  
  return bytes;
}
