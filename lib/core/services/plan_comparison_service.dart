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

  /// Checks if the requested plan is higher than the current plan
  /// 
  /// Property 14: Plan upgrade comparison
  /// For any pair of plans (current, requested), the comparison SHALL return:
  /// - true if requested plan tier > current plan tier
  /// - false if requested plan tier <= current plan tier
  /// 
  /// Requirements: B2.3
  bool isUpgrade(String currentPlan, String requestedPlan) {
    final currentIndex = _planHierarchy.indexOf(currentPlan.toLowerCase());
    final requestedIndex = _planHierarchy.indexOf(requestedPlan.toLowerCase());

    // If either plan is not found, treat as invalid (not an upgrade)
    if (currentIndex == -1 || requestedIndex == -1) {
      return false;
    }

    return requestedIndex > currentIndex;
  }

  /// Gets all plans that are higher than the current plan
  /// 
  /// Returns a list of plan codes that represent valid upgrade options
  List<String> getUpgradeOptions(String currentPlan) {
    final currentIndex = _planHierarchy.indexOf(currentPlan.toLowerCase());

    // If current plan not found, return empty list
    if (currentIndex == -1) {
      return [];
    }

    // Return all plans with higher index
    return _planHierarchy.sublist(currentIndex + 1);
  }

  /// Gets the display name for a plan code
  String getPlanDisplayName(String planCode) {
    switch (planCode.toLowerCase()) {
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
