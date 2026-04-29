#!/usr/bin/env dart
// PocketBase Rules Verification Script
// Validates that live PocketBase instance has correct tenant-isolation rules

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Expected rules for each collection based on docs/POCKETBASE_TENANT_RULES.md
final Map<String, Map<String, String?>> expectedRules = {
  'tenants': {
    'listRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
    'viewRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
    'createRule': "@request.auth.id != '' && @request.auth.is_superadmin = true",
    'updateRule': "@request.auth.id != '' && @request.auth.is_superadmin = true",
    'deleteRule': "@request.auth.id != '' && @request.auth.is_superadmin = true",
  },
  'tenant_licenses': {
    'listRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
    'viewRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
    'createRule': "@request.auth.id != '' && @request.auth.is_superadmin = true",
    'updateRule': "@request.auth.id != '' && @request.auth.is_superadmin = true",
    'deleteRule': "@request.auth.id != '' && @request.auth.is_superadmin = true",
  },
  'school_owners': {
    'listRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
    'viewRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
    'createRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
    'updateRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
    'deleteRule': "@request.auth.id != '' && @request.auth.is_superadmin = true",
  },
  'student_profiles': {
    'listRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
    'viewRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
    'createRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
    'updateRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
    'deleteRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
  },
  'student_attendance': {
    'listRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
    'viewRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
    'createRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
    'updateRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
    'deleteRule': "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)",
  },
};

/// Normalize rule strings by removing extra whitespace and newlines
String normalizeRule(String? rule) {
  if (rule == null || rule.isEmpty) return '';
  return rule
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Fetch collection rules from PocketBase Admin API
Future<Map<String, dynamic>?> fetchCollectionRules(
  String baseUrl,
  String adminEmail,
  String adminPassword,
  String collectionName,
) async {
  final client = HttpClient();
  
  try {
    // First, authenticate as admin
    final authRequest = await client.postUrl(Uri.parse('$baseUrl/api/admins/auth-with-password'));
    authRequest.headers.contentType = ContentType.json;
    authRequest.write(jsonEncode({
      'identity': adminEmail,
      'password': adminPassword,
    }));
    
    final authResponse = await authRequest.close();
    if (authResponse.statusCode != 200) {
      stderr.writeln('Failed to authenticate as admin: ${authResponse.statusCode}');
      return null;
    }
    
    final authBody = await authResponse.transform(utf8.decoder).join();
    final authData = jsonDecode(authBody) as Map<String, dynamic>;
    final token = authData['token'] as String;
    
    // Fetch collection details
    final collectionRequest = await client.getUrl(
      Uri.parse('$baseUrl/api/collections/$collectionName'),
    );
    collectionRequest.headers.add('Authorization', token);
    
    final collectionResponse = await collectionRequest.close();
    if (collectionResponse.statusCode != 200) {
      stderr.writeln('Failed to fetch collection $collectionName: ${collectionResponse.statusCode}');
      return null;
    }
    
    final collectionBody = await collectionResponse.transform(utf8.decoder).join();
    return jsonDecode(collectionBody) as Map<String, dynamic>;
  } catch (e) {
    stderr.writeln('Error fetching collection $collectionName: $e');
    return null;
  } finally {
    client.close();
  }
}

void main(List<String> args) async {
  // Get PocketBase URL and admin credentials from environment or args
  final baseUrl = Platform.environment['POCKETBASE_URL'] ?? 'http://127.0.0.1:8090';
  final adminEmail = Platform.environment['POCKETBASE_ADMIN_EMAIL'] ?? 'admin@scholify.local';
  final adminPassword = Platform.environment['POCKETBASE_ADMIN_PASSWORD'] ?? '';
  
  if (adminPassword.isEmpty) {
    stderr.writeln('Error: POCKETBASE_ADMIN_PASSWORD environment variable is required');
    stderr.writeln('Usage: POCKETBASE_ADMIN_PASSWORD=your_password dart run bin/verify_pocketbase_rules.dart');
    exit(1);
  }
  
  print('Verifying PocketBase rules...');
  print('PocketBase URL: $baseUrl');
  print('');
  
  var hasErrors = false;
  var mismatchCount = 0;
  
  for (final entry in expectedRules.entries) {
    final collectionName = entry.key;
    final expectedCollectionRules = entry.value;
    
    // Fetch actual rules from PocketBase
    final collectionData = await fetchCollectionRules(
      baseUrl,
      adminEmail,
      adminPassword,
      collectionName,
    );
    
    if (collectionData == null) {
      print('✗ $collectionName: failed to fetch collection data');
      hasErrors = true;
      mismatchCount++;
      continue;
    }
    
    // Compare each rule type
    var collectionHasMismatch = false;
    final mismatches = <String>[];
    
    for (final ruleType in ['listRule', 'viewRule', 'createRule', 'updateRule', 'deleteRule']) {
      final expectedRule = normalizeRule(expectedCollectionRules[ruleType]);
      final actualRule = normalizeRule(collectionData[ruleType] as String?);
      
      if (expectedRule != actualRule) {
        collectionHasMismatch = true;
        mismatches.add('  $ruleType mismatch:');
        mismatches.add('    Expected: ${expectedCollectionRules[ruleType] ?? "(empty)"}');
        mismatches.add('    Actual:   ${collectionData[ruleType] ?? "(empty)"}');
      }
    }
    
    if (collectionHasMismatch) {
      print('✗ $collectionName: rule mismatches detected');
      for (final mismatch in mismatches) {
        print(mismatch);
      }
      print('');
      hasErrors = true;
      mismatchCount++;
    } else {
      print('✓ $collectionName: all rules match');
    }
  }
  
  print('');
  if (hasErrors) {
    print('Summary: $mismatchCount collection(s) with mismatches or errors');
    exit(1);
  } else {
    print('All rules verified ✓');
    exit(0);
  }
}
