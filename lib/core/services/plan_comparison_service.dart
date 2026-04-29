/// Service for comparing plan tiers in the Scholify platform
/// 
/// Feature: scholify-roadmap-tracker
/// Task: 3.5
/// 
/// This service implements plan comparison logic to determine if a plan upgrade
/// request is valid. The plan hierarchy is: starter < professional < enterprise.
/// 
/// Valid upgrades:
/// - starter → professional
/// - starter → enterprise
/// - professional → enterprise
/// 
/// Invalid (same or downgrade):
/// - starter → starter
/// - professional → starter
/// - professional → professional
/// - enterprise → starter
/// - enterprise → professional
/// - enterprise → enterprise
/// 
/// Requirements: B2.3

class PlanComparisonService {
  /// Plan hierarchy: starter < professional < enterprise
  static const Map<String, int> _planHierarchy = {
    'starter': 1,
    'professional': 2,
    'enterprise': 3,
  };

  /// Compares two plans and returns true if the requested plan is higher than the current plan
  /// 
  /// Parameters:
  /// - currentPlan: The current plan code (case-insensitive)
  /// - requestedPlan: The requested plan code (case-insensitive)
  /// 
  /// Returns:
  /// - true if requestedPlan > currentPlan in the hierarchy
  /// - false if requestedPlan <= currentPlan or if either plan is invalid
  /// 
  /// Examples:
  /// - comparePlans('starter', 'professional') → true
  /// - comparePlans('starter', 'enterprise') → true
  /// - comparePlans('professional', 'enterprise') → true
  /// - comparePlans('starter', 'starter') → false
  /// - comparePlans('professional', 'starter') → false
  /// - comparePlans('invalid', 'professional') → false
  bool comparePlans(String currentPlan, String requestedPlan) {
    // Normalize to lowercase for case-insensitive comparison
    final normalizedCurrent = currentPlan.toLowerCase().trim();
    final normalizedRequested = requestedPlan.toLowerCase().trim();

    // Get hierarchy values
    final currentValue = _planHierarchy[normalizedCurrent];
    final requestedValue = _planHierarchy[normalizedRequested];

    // If either plan is invalid, return false
    if (currentValue == null || requestedValue == null) {
      return false;
    }

    // Return true if requested plan is higher than current plan
    return requestedValue > currentValue;
  }

  /// Validates if a plan code is valid
  /// 
  /// Parameters:
  /// - planCode: The plan code to validate (case-insensitive)
  /// 
  /// Returns:
  /// - true if the plan code is one of: starter, professional, enterprise
  /// - false otherwise
  bool isValidPlan(String planCode) {
    final normalized = planCode.toLowerCase().trim();
    return _planHierarchy.containsKey(normalized);
  }

  /// Gets the hierarchy value for a plan
  /// 
  /// Parameters:
  /// - planCode: The plan code (case-insensitive)
  /// 
  /// Returns:
  /// - The hierarchy value (1 for starter, 2 for professional, 3 for enterprise)
  /// - null if the plan is invalid
  int? getPlanValue(String planCode) {
    final normalized = planCode.toLowerCase().trim();
    return _planHierarchy[normalized];
  }

  /// Gets all valid plan codes
  List<String> getValidPlans() {
    return _planHierarchy.keys.toList();
  }
}
