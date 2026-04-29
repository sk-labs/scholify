/// Service for comparing plan tiers
/// 
/// Feature: scholify-roadmap-tracker
/// Requirements: B2.3
/// 
/// This service provides plan comparison logic to determine if a requested plan
/// is an upgrade, downgrade, or the same as the current plan.
class PlanComparisonService {
  /// Plan hierarchy (lower index = lower tier)
  static const List<String> _planHierarchy = [
    'starter',
    'professional',
    'enterprise',
  ];

  /// Compares two plans and returns true if requested > current
  /// 
  /// This is an alias for isUpgrade() to match test expectations.
  /// 
  /// Property 14: Plan upgrade comparison
  /// For any pair of plans (current, requested), the comparison SHALL return:
  /// - true if requested plan tier > current plan tier
  /// - false if requested plan tier <= current plan tier
  /// 
  /// Requirements: B2.3
  bool comparePlans(String currentPlan, String requestedPlan) {
    return isUpgrade(currentPlan, requestedPlan);
  }

  /// Checks if the requested plan is higher than the current plan
  /// 
  /// Property 14: Plan upgrade comparison
  /// For any pair of plans (current, requested), the comparison SHALL return:
  /// - true if requested plan tier > current plan tier
  /// - false if requested plan tier <= current plan tier
  /// 
  /// Requirements: B2.3
  bool isUpgrade(String currentPlan, String requestedPlan) {
    final currentIndex = _getPlanIndex(currentPlan);
    final requestedIndex = _getPlanIndex(requestedPlan);

    // If either plan is not found, treat as invalid (not an upgrade)
    if (currentIndex == -1 || requestedIndex == -1) {
      return false;
    }

    return requestedIndex > currentIndex;
  }

  /// Checks if a plan code is valid
  bool isValidPlan(String planCode) {
    return _getPlanIndex(planCode) != -1;
  }

  /// Gets the numeric value/tier of a plan (1=starter, 2=professional, 3=enterprise)
  /// Returns -1 if plan is invalid
  int getPlanValue(String planCode) {
    final index = _getPlanIndex(planCode);
    return index == -1 ? -1 : index + 1;
  }

  /// Gets the list of all valid plan codes
  List<String> getValidPlans() {
    return List.unmodifiable(_planHierarchy);
  }

  /// Gets the plan index in the hierarchy, handling case and whitespace
  int _getPlanIndex(String planCode) {
    final normalized = planCode.trim().toLowerCase();
    return _planHierarchy.indexOf(normalized);
  }

  /// Gets all plans that are higher than the current plan
  /// 
  /// Returns a list of plan codes that represent valid upgrade options
  List<String> getUpgradeOptions(String currentPlan) {
    final currentIndex = _getPlanIndex(currentPlan);

    // If current plan not found, return empty list
    if (currentIndex == -1) {
      return [];
    }

    // Return all plans with higher index
    return _planHierarchy.sublist(currentIndex + 1);
  }

  /// Gets the display name for a plan code
  String getPlanDisplayName(String planCode) {
    switch (planCode.toLowerCase().trim()) {
      case 'starter':
        return 'Starter';
      case 'professional':
        return 'Professional';
      case 'enterprise':
        return 'Enterprise';
      default:
        return planCode;
    }
  }
}
