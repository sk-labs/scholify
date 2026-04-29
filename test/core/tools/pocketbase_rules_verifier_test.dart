import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/tools/pocketbase_rules_verifier.dart';

/// Tests for the PocketBase rules verifier logic.
///
/// Feature: scholify-roadmap-tracker
/// Requirements: A1.1, A1.2, A1.3, A1.4, A1.5, A1.6
///
/// These tests cover:
/// - normalizeRule: whitespace/newline normalisation
/// - verifyCollectionRules: correct rule scenario
/// - verifyCollectionRules: wrong rule scenario (mismatch detection)
/// - verifyAllCollections: connection error scenario
/// - verifyAllCollections: mixed results (some ok, some mismatched, some errors)
/// - allResultsOk: summary predicate
void main() {
  // ── normalizeRule ──────────────────────────────────────────────────────────

  group('normalizeRule', () {
    test('returns empty string for null input', () {
      expect(normalizeRule(null), equals(''));
    });

    test('returns empty string for empty string', () {
      expect(normalizeRule(''), equals(''));
    });

    test('trims leading and trailing whitespace', () {
      expect(normalizeRule('  hello  '), equals('hello'));
    });

    test('collapses multiple spaces to one', () {
      expect(normalizeRule('a  b   c'), equals('a b c'));
    });

    test('replaces newlines with spaces', () {
      expect(
        normalizeRule("@request.auth.id != '' &&\n  @request.auth.is_superadmin = true"),
        equals("@request.auth.id != '' && @request.auth.is_superadmin = true"),
      );
    });

    test('collapses mixed newlines and spaces', () {
      final multiLine = "@request.auth.id != '' && (\n"
          "  @request.auth.is_superadmin = true ||\n"
          "  @request.auth.tenant_id = tenant_id\n"
          ")";
      final expected =
          "@request.auth.id != '' && ( @request.auth.is_superadmin = true || @request.auth.tenant_id = tenant_id )";
      expect(normalizeRule(multiLine), equals(expected));
    });

    test('two differently-formatted but semantically equal rules normalise to the same string',
        () {
      final multiLine = "@request.auth.id != '' && (\n"
          "  @request.auth.is_superadmin = true ||\n"
          "  @request.auth.tenant_id = tenant_id\n"
          ")";
      final singleLine =
          "@request.auth.id != '' && ( @request.auth.is_superadmin = true || @request.auth.tenant_id = tenant_id )";
      expect(normalizeRule(multiLine), equals(normalizeRule(singleLine)));
    });
  });

  // ── verifyCollectionRules — correct scenario ───────────────────────────────

  group('verifyCollectionRules — correct rule scenario (A1.3)', () {
    const tenantIsolationRule = "@request.auth.id != '' && (\n"
        "  @request.auth.is_superadmin = true ||\n"
        "  @request.auth.tenant_id = tenant_id\n"
        ")";
    const superadminOnlyRule =
        "@request.auth.id != '' && @request.auth.is_superadmin = true";

    final expectedRules = <String, String?>{
      'listRule': tenantIsolationRule,
      'viewRule': tenantIsolationRule,
      'createRule': superadminOnlyRule,
      'updateRule': superadminOnlyRule,
      'deleteRule': superadminOnlyRule,
    };

    test('returns no mismatches when actual rules exactly match expected', () {
      final actualData = <String, dynamic>{
        'listRule': tenantIsolationRule,
        'viewRule': tenantIsolationRule,
        'createRule': superadminOnlyRule,
        'updateRule': superadminOnlyRule,
        'deleteRule': superadminOnlyRule,
      };

      final result = verifyCollectionRules(
        collection: 'tenants',
        expectedRules: expectedRules,
        actualData: actualData,
      );

      expect(result.isOk, isTrue);
      expect(result.mismatches, isEmpty);
      expect(result.fetchError, isNull);
    });

    test('returns no mismatches when actual rules differ only in whitespace', () {
      // API returns single-line version of the same rule
      final singleLine =
          "@request.auth.id != '' && ( @request.auth.is_superadmin = true || @request.auth.tenant_id = tenant_id )";

      final actualData = <String, dynamic>{
        'listRule': singleLine,
        'viewRule': singleLine,
        'createRule': superadminOnlyRule,
        'updateRule': superadminOnlyRule,
        'deleteRule': superadminOnlyRule,
      };

      final result = verifyCollectionRules(
        collection: 'tenants',
        expectedRules: expectedRules,
        actualData: actualData,
      );

      expect(result.isOk, isTrue);
      expect(result.mismatches, isEmpty);
    });

    test('isOk is true and hasMismatches is false for a matching collection', () {
      final actualData = <String, dynamic>{
        'listRule': tenantIsolationRule,
        'viewRule': tenantIsolationRule,
        'createRule': superadminOnlyRule,
        'updateRule': superadminOnlyRule,
        'deleteRule': superadminOnlyRule,
      };

      final result = verifyCollectionRules(
        collection: 'tenant_licenses',
        expectedRules: expectedRules,
        actualData: actualData,
      );

      expect(result.isOk, isTrue);
      expect(result.hasMismatches, isFalse);
    });
  });

  // ── verifyCollectionRules — wrong rule scenario ────────────────────────────

  group('verifyCollectionRules — wrong rule scenario (A1.4)', () {
    const tenantIsolationRule = "@request.auth.id != '' && (\n"
        "  @request.auth.is_superadmin = true ||\n"
        "  @request.auth.tenant_id = tenant_id\n"
        ")";
    const superadminOnlyRule =
        "@request.auth.id != '' && @request.auth.is_superadmin = true";

    test('detects a single mismatch on createRule', () {
      final expectedRules = <String, String?>{
        'listRule': tenantIsolationRule,
        'viewRule': tenantIsolationRule,
        'createRule': superadminOnlyRule, // expected: superadmin only
        'updateRule': superadminOnlyRule,
        'deleteRule': superadminOnlyRule,
      };

      final actualData = <String, dynamic>{
        'listRule': tenantIsolationRule,
        'viewRule': tenantIsolationRule,
        'createRule': tenantIsolationRule, // actual: wrong — too permissive
        'updateRule': superadminOnlyRule,
        'deleteRule': superadminOnlyRule,
      };

      final result = verifyCollectionRules(
        collection: 'tenants',
        expectedRules: expectedRules,
        actualData: actualData,
      );

      expect(result.isOk, isFalse);
      expect(result.hasMismatches, isTrue);
      expect(result.mismatches.length, equals(1));
      expect(result.mismatches.first.ruleType, equals('createRule'));
      expect(result.mismatches.first.collection, equals('tenants'));
    });

    test('detects mismatches on all five rule types', () {
      final expectedRules = <String, String?>{
        'listRule': superadminOnlyRule,
        'viewRule': superadminOnlyRule,
        'createRule': superadminOnlyRule,
        'updateRule': superadminOnlyRule,
        'deleteRule': superadminOnlyRule,
      };

      final actualData = <String, dynamic>{
        'listRule': tenantIsolationRule,
        'viewRule': tenantIsolationRule,
        'createRule': tenantIsolationRule,
        'updateRule': tenantIsolationRule,
        'deleteRule': tenantIsolationRule,
      };

      final result = verifyCollectionRules(
        collection: 'student_profiles',
        expectedRules: expectedRules,
        actualData: actualData,
      );

      expect(result.mismatches.length, equals(5));
      expect(
        result.mismatches.map((m) => m.ruleType).toList(),
        containsAll(kRuleTypes),
      );
    });

    test('detects empty actual rule as mismatch against non-empty expected', () {
      final expectedRules = <String, String?>{
        'listRule': tenantIsolationRule,
        'viewRule': tenantIsolationRule,
        'createRule': superadminOnlyRule,
        'updateRule': superadminOnlyRule,
        'deleteRule': superadminOnlyRule,
      };

      // API returns null for all rules (collection has no rules set)
      final actualData = <String, dynamic>{
        'listRule': null,
        'viewRule': null,
        'createRule': null,
        'updateRule': null,
        'deleteRule': null,
      };

      final result = verifyCollectionRules(
        collection: 'tenants',
        expectedRules: expectedRules,
        actualData: actualData,
      );

      expect(result.mismatches.length, equals(5));
    });

    test('mismatch includes correct expected and actual values', () {
      final expectedRules = <String, String?>{
        'listRule': superadminOnlyRule,
        'viewRule': tenantIsolationRule,
        'createRule': superadminOnlyRule,
        'updateRule': superadminOnlyRule,
        'deleteRule': superadminOnlyRule,
      };

      final actualData = <String, dynamic>{
        'listRule': 'wrong rule',
        'viewRule': tenantIsolationRule,
        'createRule': superadminOnlyRule,
        'updateRule': superadminOnlyRule,
        'deleteRule': superadminOnlyRule,
      };

      final result = verifyCollectionRules(
        collection: 'school_owners',
        expectedRules: expectedRules,
        actualData: actualData,
      );

      expect(result.mismatches.length, equals(1));
      final mismatch = result.mismatches.first;
      expect(mismatch.ruleType, equals('listRule'));
      expect(mismatch.expected, equals(superadminOnlyRule));
      expect(mismatch.actual, equals('wrong rule'));
    });
  });

  // ── verifyAllCollections — connection error scenario ───────────────────────

  group('verifyAllCollections — connection error scenario (A1.6)', () {
    test('records fetchError when fetchCollection returns null', () async {
      final expectedRulesMap = {
        'tenants': <String, String?>{
          'listRule': 'some rule',
          'viewRule': 'some rule',
          'createRule': 'some rule',
          'updateRule': 'some rule',
          'deleteRule': 'some rule',
        },
      };

      final results = await verifyAllCollections(
        expectedRulesMap: expectedRulesMap,
        fetchCollection: (_) async => null, // simulate connection error
      );

      expect(results.length, equals(1));
      expect(results.first.hasError, isTrue);
      expect(results.first.fetchError, isNotNull);
      expect(results.first.isOk, isFalse);
    });

    test('allResultsOk returns false when any collection has a fetch error', () async {
      final expectedRulesMap = {
        'tenants': <String, String?>{
          'listRule': 'rule',
          'viewRule': 'rule',
          'createRule': 'rule',
          'updateRule': 'rule',
          'deleteRule': 'rule',
        },
        'tenant_licenses': <String, String?>{
          'listRule': 'rule',
          'viewRule': 'rule',
          'createRule': 'rule',
          'updateRule': 'rule',
          'deleteRule': 'rule',
        },
      };

      final results = await verifyAllCollections(
        expectedRulesMap: expectedRulesMap,
        fetchCollection: (collection) async {
          if (collection == 'tenants') {
            return {
              'listRule': 'rule',
              'viewRule': 'rule',
              'createRule': 'rule',
              'updateRule': 'rule',
              'deleteRule': 'rule',
            };
          }
          return null; // tenant_licenses fails
        },
      );

      expect(allResultsOk(results), isFalse);
      expect(results.where((r) => r.hasError).length, equals(1));
      expect(results.where((r) => r.isOk).length, equals(1));
    });

    test('all collections report errors when every fetch fails', () async {
      final expectedRulesMap = {
        'tenants': <String, String?>{
          'listRule': 'rule',
          'viewRule': 'rule',
          'createRule': 'rule',
          'updateRule': 'rule',
          'deleteRule': 'rule',
        },
        'tenant_licenses': <String, String?>{
          'listRule': 'rule',
          'viewRule': 'rule',
          'createRule': 'rule',
          'updateRule': 'rule',
          'deleteRule': 'rule',
        },
        'school_owners': <String, String?>{
          'listRule': 'rule',
          'viewRule': 'rule',
          'createRule': 'rule',
          'updateRule': 'rule',
          'deleteRule': 'rule',
        },
      };

      final results = await verifyAllCollections(
        expectedRulesMap: expectedRulesMap,
        fetchCollection: (_) async => null,
      );

      expect(results.length, equals(3));
      expect(results.every((r) => r.hasError), isTrue);
      expect(allResultsOk(results), isFalse);
    });
  });

  // ── verifyAllCollections — mixed results ───────────────────────────────────

  group('verifyAllCollections — mixed results', () {
    const correctRule =
        "@request.auth.id != '' && @request.auth.is_superadmin = true";
    const wrongRule = 'wrong rule';

    test('processes multiple collections and returns one result per collection',
        () async {
      final expectedRulesMap = {
        'tenants': <String, String?>{
          'listRule': correctRule,
          'viewRule': correctRule,
          'createRule': correctRule,
          'updateRule': correctRule,
          'deleteRule': correctRule,
        },
        'tenant_licenses': <String, String?>{
          'listRule': correctRule,
          'viewRule': correctRule,
          'createRule': correctRule,
          'updateRule': correctRule,
          'deleteRule': correctRule,
        },
      };

      final results = await verifyAllCollections(
        expectedRulesMap: expectedRulesMap,
        fetchCollection: (_) async => {
          'listRule': correctRule,
          'viewRule': correctRule,
          'createRule': correctRule,
          'updateRule': correctRule,
          'deleteRule': correctRule,
        },
      );

      expect(results.length, equals(2));
      expect(results.every((r) => r.isOk), isTrue);
      expect(allResultsOk(results), isTrue);
    });

    test('correctly identifies which collections pass and which fail', () async {
      final expectedRulesMap = {
        'tenants': <String, String?>{
          'listRule': correctRule,
          'viewRule': correctRule,
          'createRule': correctRule,
          'updateRule': correctRule,
          'deleteRule': correctRule,
        },
        'tenant_licenses': <String, String?>{
          'listRule': correctRule,
          'viewRule': correctRule,
          'createRule': correctRule,
          'updateRule': correctRule,
          'deleteRule': correctRule,
        },
        'school_owners': <String, String?>{
          'listRule': correctRule,
          'viewRule': correctRule,
          'createRule': correctRule,
          'updateRule': correctRule,
          'deleteRule': correctRule,
        },
      };

      final results = await verifyAllCollections(
        expectedRulesMap: expectedRulesMap,
        fetchCollection: (collection) async {
          if (collection == 'tenant_licenses') {
            // This collection has a wrong rule
            return {
              'listRule': wrongRule,
              'viewRule': correctRule,
              'createRule': correctRule,
              'updateRule': correctRule,
              'deleteRule': correctRule,
            };
          }
          return {
            'listRule': correctRule,
            'viewRule': correctRule,
            'createRule': correctRule,
            'updateRule': correctRule,
            'deleteRule': correctRule,
          };
        },
      );

      expect(results.length, equals(3));
      expect(allResultsOk(results), isFalse);

      final tenants = results.firstWhere((r) => r.collection == 'tenants');
      final licenses =
          results.firstWhere((r) => r.collection == 'tenant_licenses');
      final owners =
          results.firstWhere((r) => r.collection == 'school_owners');

      expect(tenants.isOk, isTrue);
      expect(licenses.hasMismatches, isTrue);
      expect(licenses.mismatches.first.ruleType, equals('listRule'));
      expect(owners.isOk, isTrue);
    });
  });

  // ── allResultsOk ───────────────────────────────────────────────────────────

  group('allResultsOk', () {
    test('returns true for empty results list', () {
      expect(allResultsOk([]), isTrue);
    });

    test('returns true when all results are ok', () {
      final results = [
        const CollectionVerificationResult(
          collection: 'a',
          mismatches: [],
        ),
        const CollectionVerificationResult(
          collection: 'b',
          mismatches: [],
        ),
      ];
      expect(allResultsOk(results), isTrue);
    });

    test('returns false when any result has mismatches', () {
      final results = [
        const CollectionVerificationResult(
          collection: 'a',
          mismatches: [],
        ),
        CollectionVerificationResult(
          collection: 'b',
          mismatches: [
            const RuleMismatch(
              collection: 'b',
              ruleType: 'listRule',
              expected: 'x',
              actual: 'y',
            ),
          ],
        ),
      ];
      expect(allResultsOk(results), isFalse);
    });

    test('returns false when any result has a fetch error', () {
      final results = [
        const CollectionVerificationResult(
          collection: 'a',
          mismatches: [],
        ),
        const CollectionVerificationResult(
          collection: 'b',
          mismatches: [],
          fetchError: 'connection refused',
        ),
      ];
      expect(allResultsOk(results), isFalse);
    });
  });
}
