// Pure logic for PocketBase rules verification.
//
// Extracted from bin/verify_pocketbase_rules.dart so it can be unit-tested
// without a live PocketBase instance.
//
// Feature: scholify-roadmap-tracker
// Requirements: A1.1, A1.2, A1.3, A1.4

// ── Data types ────────────────────────────────────────────────────────────────

/// The five rule types PocketBase exposes per collection.
const List<String> kRuleTypes = [
  'listRule',
  'viewRule',
  'createRule',
  'updateRule',
  'deleteRule',
];

/// Result of comparing a single rule type for one collection.
class RuleMismatch {
  const RuleMismatch({
    required this.collection,
    required this.ruleType,
    required this.expected,
    required this.actual,
  });

  final String collection;
  final String ruleType;
  final String? expected;
  final String? actual;

  @override
  String toString() =>
      '$collection.$ruleType: expected="${expected ?? "(empty)"}" '
      'actual="${actual ?? "(empty)"}"';
}

/// Outcome of verifying a single collection.
class CollectionVerificationResult {
  const CollectionVerificationResult({
    required this.collection,
    required this.mismatches,
    this.fetchError,
  });

  final String collection;
  final List<RuleMismatch> mismatches;

  /// Non-null when the collection data could not be fetched (network/auth error).
  final String? fetchError;

  bool get hasError => fetchError != null;
  bool get hasMismatches => mismatches.isNotEmpty;
  bool get isOk => !hasError && !hasMismatches;
}

// ── Core logic ────────────────────────────────────────────────────────────────

/// Normalises a PocketBase rule string for comparison.
///
/// Collapses all whitespace (including newlines) to single spaces and trims.
/// This makes comparison robust against formatting differences between the
/// expected rules (which use multi-line formatting) and the actual rules
/// returned by the API (which may be single-line).
String normalizeRule(String? rule) {
  if (rule == null || rule.isEmpty) return '';
  return rule
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Compares expected rules against actual collection data returned by the API.
///
/// [expectedRules] maps ruleType → expected rule string (may be null).
/// [actualData]    is the raw JSON map returned by the PocketBase API.
///
/// Returns a [CollectionVerificationResult] with any mismatches found.
CollectionVerificationResult verifyCollectionRules({
  required String collection,
  required Map<String, String?> expectedRules,
  required Map<String, dynamic> actualData,
}) {
  final mismatches = <RuleMismatch>[];

  for (final ruleType in kRuleTypes) {
    final expected = normalizeRule(expectedRules[ruleType]);
    final actual = normalizeRule(actualData[ruleType] as String?);

    if (expected != actual) {
      mismatches.add(RuleMismatch(
        collection: collection,
        ruleType: ruleType,
        expected: expectedRules[ruleType],
        actual: actualData[ruleType] as String?,
      ));
    }
  }

  return CollectionVerificationResult(
    collection: collection,
    mismatches: mismatches,
  );
}

/// Verifies all collections and returns one result per collection.
///
/// [expectedRulesMap] maps collection name → (ruleType → expected rule).
/// [fetchCollection]  is a callback that returns the raw API data for a
///                    collection, or null on error.
Future<List<CollectionVerificationResult>> verifyAllCollections({
  required Map<String, Map<String, String?>> expectedRulesMap,
  required Future<Map<String, dynamic>?> Function(String collection)
      fetchCollection,
}) async {
  final results = <CollectionVerificationResult>[];

  for (final entry in expectedRulesMap.entries) {
    final collection = entry.key;
    final expectedRules = entry.value;

    final actualData = await fetchCollection(collection);

    if (actualData == null) {
      results.add(CollectionVerificationResult(
        collection: collection,
        mismatches: const [],
        fetchError: 'Failed to fetch collection data',
      ));
      continue;
    }

    results.add(verifyCollectionRules(
      collection: collection,
      expectedRules: expectedRules,
      actualData: actualData,
    ));
  }

  return results;
}

/// Returns true if all results are OK (no errors, no mismatches).
bool allResultsOk(List<CollectionVerificationResult> results) =>
    results.every((r) => r.isOk);
