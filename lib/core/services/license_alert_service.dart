import '../database/local_database.dart';

/// Alert tier classification for license expiry warnings.
/// 
/// Requirements: H4.2, H4.3, H4.4, H4.5
enum AlertTier {
  /// No alert - more than 30 days remaining
  none,
  
  /// Warning - 30 or fewer days remaining
  warning30,
  
  /// Alert - 14 or fewer days remaining
  alert14,
  
  /// Urgent - 7 or fewer days remaining
  urgent7,
  
  /// License has expired
  expired,
}

/// Represents a license expiry alert for a single tenant.
/// 
/// Requirements: H4.1
class LicenseAlert {
  const LicenseAlert({
    required this.tenantId,
    required this.tenantName,
    required this.expiresAt,
    required this.daysRemaining,
    required this.tier,
  });

  final String tenantId;
  final String tenantName;
  final DateTime expiresAt;
  final int daysRemaining;
  final AlertTier tier;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LicenseAlert &&
          runtimeType == other.runtimeType &&
          tenantId == other.tenantId &&
          tenantName == other.tenantName &&
          expiresAt == other.expiresAt &&
          daysRemaining == other.daysRemaining &&
          tier == other.tier;

  @override
  int get hashCode =>
      tenantId.hashCode ^
      tenantName.hashCode ^
      expiresAt.hashCode ^
      daysRemaining.hashCode ^
      tier.hashCode;
}

/// Service for computing and monitoring license expiry alerts.
/// 
/// This service computes days remaining until expiry for all active licenses
/// and classifies them into alert tiers (30d, 14d, 7d, expired) for display
/// on the Superadmin Dashboard.
/// 
/// Requirements: H4.1, H4.2, H4.3, H4.4, H4.5, H4.6
class LicenseAlertService {
  final AppLocalDatabase _database;

  const LicenseAlertService({
    required AppLocalDatabase database,
  }) : _database = database;

  /// Provides a reactive stream of license alerts.
  /// 
  /// The stream emits a new list of alerts whenever the underlying
  /// TenantLicenseEntries data changes. Only active licenses are included.
  /// 
  /// Requirements: H4.1, H4.7
  Stream<List<LicenseAlert>> watchAlerts() {
    return _database.watchTenantLicenseViews().map((licenses) {
      final now = DateTime.now();
      return computeAlerts(licenses, now);
    });
  }

  /// Computes alert states for a list of licenses at a given point in time.
  /// 
  /// This is a pure function that takes a list of licenses and a timestamp,
  /// and returns a list of alerts for licenses that require attention.
  /// 
  /// Only active licenses with non-null expiry dates are included in the result.
  /// Licenses with null expiry dates are treated as having no expiry and generate no alerts.
  /// 
  /// Parameters:
  /// - [licenses]: List of tenant licenses to evaluate
  /// - [now]: The current timestamp to use for computing days remaining
  /// 
  /// Returns: List of LicenseAlert objects for licenses requiring attention (tier != none)
  /// 
  /// Requirements: H4.1, H4.2, H4.3, H4.4, H4.5, H4.6
  List<LicenseAlert> computeAlerts(
    List<TenantLicenseView> licenses,
    DateTime now,
  ) {
    final alerts = <LicenseAlert>[];

    for (final license in licenses) {
      // Skip inactive licenses
      if (!license.isActive) continue;

      // Skip licenses with no expiry date (H4.6)
      if (license.expiresAt == null) continue;

      final expiresAt = license.expiresAt!;
      final tier = computeAlertTier(expiresAt, now);

      // Only include licenses that require attention (not 'none')
      if (tier != AlertTier.none) {
        final daysRemaining = expiresAt.difference(now).inDays;
        alerts.add(LicenseAlert(
          tenantId: license.tenantId,
          tenantName: license.tenantName,
          expiresAt: expiresAt,
          daysRemaining: daysRemaining,
          tier: tier,
        ));
      }
    }

    return alerts;
  }

  /// Computes the alert tier for a license based on expiry date and current time.
  /// 
  /// This is a pure function implementing the alert tier thresholds:
  /// - expired: expiresAt < now
  /// - urgent7: 0 <= daysRemaining <= 7
  /// - alert14: 8 <= daysRemaining <= 14
  /// - warning30: 15 <= daysRemaining <= 30
  /// - none: daysRemaining > 30
  /// 
  /// Requirements: H4.2, H4.3, H4.4, H4.5
  AlertTier computeAlertTier(DateTime expiresAt, DateTime now) {
    final daysRemaining = expiresAt.difference(now).inDays;

    if (daysRemaining < 0) {
      return AlertTier.expired;
    } else if (daysRemaining <= 7) {
      return AlertTier.urgent7;
    } else if (daysRemaining <= 14) {
      return AlertTier.alert14;
    } else if (daysRemaining <= 30) {
      return AlertTier.warning30;
    } else {
      return AlertTier.none;
    }
  }
}
