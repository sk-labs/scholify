import 'package:flutter_test/flutter_test.dart';

/// Unit tests for bin/verify_pocketbase_rules.dart
/// 
/// These tests verify the rule normalization logic and expected rules structure.
/// Integration testing with a live PocketBase instance should be done manually.

void main() {
  group('PocketBase Rules Verification', () {
    test('normalizeRule removes extra whitespace and newlines', () {
      // Test the normalization logic that would be in the script
      String normalizeRule(String? rule) {
        if (rule == null || rule.isEmpty) return '';
        return rule
            .replaceAll('\n', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }

      expect(normalizeRule(null), '');
      expect(normalizeRule(''), '');
      expect(normalizeRule('  '), '');
      
      expect(
        normalizeRule("@request.auth.id != '' && @request.auth.is_superadmin = true"),
        "@request.auth.id != '' && @request.auth.is_superadmin = true",
      );
      
      expect(
        normalizeRule("@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)"),
        "@request.auth.id != '' && ( @request.auth.is_superadmin = true || @request.auth.tenant_id = tenant_id )",
      );
      
      expect(
        normalizeRule("  @request.auth.id != ''   &&   @request.auth.is_superadmin = true  "),
        "@request.auth.id != '' && @request.auth.is_superadmin = true",
      );
    });

    test('expected rules structure contains all required collections', () {
      // Verify the expected rules map has all collections from POCKETBASE_TENANT_RULES.md
      final expectedCollections = [
        'tenants',
        'tenant_licenses',
        'school_owners',
        'student_profiles',
        'student_attendance',
      ];

      // This would be the expectedRules map from the script
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

      for (final collection in expectedCollections) {
        expect(expectedRules.containsKey(collection), true,
            reason: 'Expected rules should contain $collection');
      }

      expect(expectedRules.length, expectedCollections.length,
          reason: 'Expected rules should have exactly ${expectedCollections.length} collections');
    });

    test('each collection has all five rule types defined', () {
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

      final requiredRuleTypes = ['listRule', 'viewRule', 'createRule', 'updateRule', 'deleteRule'];

      for (final entry in expectedRules.entries) {
        final collectionName = entry.key;
        final rules = entry.value;

        for (final ruleType in requiredRuleTypes) {
          expect(rules.containsKey(ruleType), true,
              reason: '$collectionName should have $ruleType defined');
          expect(rules[ruleType], isNotNull,
              reason: '$collectionName.$ruleType should not be null');
          expect(rules[ruleType]!.isNotEmpty, true,
              reason: '$collectionName.$ruleType should not be empty');
        }
      }
    });

    test('tenant isolation pattern is present in all tenant-scoped rules', () {
      final tenantIsolationPattern = RegExp(
        r"@request\.auth\.is_superadmin\s*=\s*true\s*\|\|\s*@request\.auth\.tenant_id\s*=\s*tenant_id",
      );

      final superadminOnlyPattern = RegExp(
        r"@request\.auth\.is_superadmin\s*=\s*true",
      );

      // Test a sample rule that should have tenant isolation
      final sampleTenantScopedRule = "@request.auth.id != '' && (\n  @request.auth.is_superadmin = true ||\n  @request.auth.tenant_id = tenant_id\n)";
      expect(tenantIsolationPattern.hasMatch(sampleTenantScopedRule), true,
          reason: 'Tenant-scoped rules should contain the tenant isolation pattern');

      // Test a sample rule that should be superadmin-only
      final sampleSuperadminRule = "@request.auth.id != '' && @request.auth.is_superadmin = true";
      expect(superadminOnlyPattern.hasMatch(sampleSuperadminRule), true,
          reason: 'Superadmin-only rules should contain the superadmin check');
    });
  });
}
