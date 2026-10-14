import 'package:flutter/material.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/theme/scholify_colors.dart';
import 'package:scholify/core/widgets/scholify_skeleton.dart';

/// The metric a summary card represents. Used for tap-to-filter navigation.
enum DashboardMetricType {
  total,
  active,
  atRisk,
  expiringSoon,
}

/// Dashboard Summary Cards (Q4)
///
/// Displays four summary metric cards showing platform health at a glance:
/// - Total Tenants
/// - Active Tenants
/// - At Risk Tenants
/// - Expiring Soon (≤30 days)
///
/// Requirements: Q4.1, Q4.2, Q4.3, Q4.4, Q4.5, Q4.6, Q4.7
class DashboardSummaryCards extends StatelessWidget {
  final SyncEngine syncEngine;

  /// Optional callback invoked when a card is tapped, enabling
  /// tap-to-filter navigation (e.g. open the licensing list filtered).
  final void Function(DashboardMetricType type)? onCardTap;

  const DashboardSummaryCards({
    super.key,
    required this.syncEngine,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    // Q4.2, Q4.7: Compute card values from TenantUsageBillingView stream
    return StreamBuilder<List<TenantUsageBillingView>>(
      stream: syncEngine.database.watchTenantUsageBillingViews(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCards();
        }

        if (snapshot.hasError) {
          return _ErrorCards(error: snapshot.error.toString());
        }

        final tenants = snapshot.data ?? [];
        final metrics = _computeMetrics(tenants);

        return _buildCards(context, metrics);
      },
    );
  }

  /// Q4.2: Compute card values from local data without network call
  DashboardMetrics _computeMetrics(List<TenantUsageBillingView> tenants) {
    final now = DateTime.now();
    final thirtyDaysFromNow = now.add(const Duration(days: 30));

    // Q4.3: Total Tenants - count of all tenants
    final totalTenants = tenants.length;

    // Q4.4: Active - count where licenseActive = true
    final activeTenants = tenants
        .where((t) => t.licenseActive == true)
        .length;

    // Q4.5: At Risk - seat utilization >= 90% OR overdueInvoices > 0 OR outstandingAmount > 0
    final atRiskTenants = tenants.where((t) {
      // Check overdue invoices
      if ((t.overdueInvoices ?? 0) > 0) return true;

      // Check outstanding amount
      if ((t.outstandingAmount ?? 0) > 0) return true;

      // Check seat utilization >= 90%
      final seatLimit = t.seatLimit;
      final activeStudents = t.activeStudents ?? 0;
      if (seatLimit != null && seatLimit > 0) {
        final utilization = activeStudents / seatLimit;
        if (utilization >= 0.9) return true;
      }

      return false;
    }).length;

    // Q4.6: Expiring Soon - active tenants with expiresAt <= now + 30 days
    final expiringSoonTenants = tenants.where((t) {
      if (t.licenseActive != true) return false;
      final expiresAt = t.licenseExpiresAt;
      if (expiresAt == null) return false;
      return expiresAt.isBefore(thirtyDaysFromNow) ||
             expiresAt.isAtSameMomentAs(thirtyDaysFromNow);
    }).length;

    return DashboardMetrics(
      totalTenants: totalTenants,
      activeTenants: activeTenants,
      atRiskTenants: atRiskTenants,
      expiringSoonTenants: expiringSoonTenants,
    );
  }

  Widget _buildCards(BuildContext context, DashboardMetrics metrics) {
    final tap = onCardTap;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive layout: 2 columns on mobile, 4 columns on desktop
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
        final childAspectRatio = constraints.maxWidth > 800 ? 1.35 : 1.15;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            // Q4.1, Q4.3: Total Tenants card
            _SummaryCard(
              title: 'Total Tenants',
              value: metrics.totalTenants.toString(),
              subtitle: metrics.totalTenants == 1 ? 'school onboard' : 'schools onboard',
              icon: Icons.business,
              color: ScholifyColors.academicNavy,
              // Progress of active vs total gives the card visual depth.
              progress: metrics.totalTenants == 0
                  ? 0
                  : metrics.activeTenants / metrics.totalTenants,
              progressLabel: '${metrics.activeTenants} active',
              onTap: tap == null ? null : () => tap(DashboardMetricType.total),
            ),

            // Q4.1, Q4.4: Active card
            _SummaryCard(
              title: 'Active',
              value: metrics.activeTenants.toString(),
              subtitle: metrics.totalTenants == 0
                  ? 'no tenants yet'
                  : '${((metrics.activeTenants / metrics.totalTenants) * 100).round()}% of total',
              icon: Icons.check_circle,
              color: ScholifyColors.scholarTeal,
              progress: metrics.totalTenants == 0
                  ? 0
                  : metrics.activeTenants / metrics.totalTenants,
              progressLabel: 'license health',
              onTap: tap == null ? null : () => tap(DashboardMetricType.active),
            ),

            // Q4.1, Q4.5: At Risk card
            _SummaryCard(
              title: 'At Risk',
              value: metrics.atRiskTenants.toString(),
              subtitle: metrics.atRiskTenants == 0
                  ? 'all clear'
                  : 'need attention',
              icon: Icons.warning,
              color: ScholifyColors.achievementAmber,
              progress: metrics.totalTenants == 0
                  ? 0
                  : metrics.atRiskTenants / metrics.totalTenants,
              progressLabel: 'of tenants',
              onTap: tap == null ? null : () => tap(DashboardMetricType.atRisk),
            ),

            // Q4.1, Q4.6: Expiring Soon card
            _SummaryCard(
              title: 'Expiring Soon (≤30d)',
              value: metrics.expiringSoonTenants.toString(),
              subtitle: metrics.expiringSoonTenants == 0
                  ? 'no renewals due'
                  : 'renewals due',
              icon: Icons.schedule,
              color: ScholifyColors.error,
              progress: metrics.activeTenants == 0
                  ? 0
                  : metrics.expiringSoonTenants / metrics.activeTenants,
              progressLabel: 'of active',
              onTap: tap == null
                  ? null
                  : () => tap(DashboardMetricType.expiringSoon),
            ),
          ],
        );
      },
    );
  }
}

/// Loading state for cards
class _LoadingCards extends StatelessWidget {
  const _LoadingCards();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.15,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: List.generate(
        4,
        (index) => const ScholifyCardSkeleton(),
      ),
    );
  }
}

/// Error state for cards
class _ErrorCards extends StatelessWidget {
  final String error;

  const _ErrorCards({required this.error});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Failed to load metrics: $error',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual summary card widget.
///
/// Professional design: gradient header band with icon, large display metric
/// value, title, contextual subtitle, and a progress bar. Tappable when
/// [onTap] is set.
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double progress;
  final String progressLabel;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.progress,
    required this.progressLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final card = Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : ScholifyColors.tint(color, 0.25),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gradient header band with icon + tap affordance
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color,
                  color.withValues(alpha: 0.75),
                ],
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Colors.white70,
                  ),
              ],
            ),
          ),
          // Body: value + subtitle + progress
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: isDark ? Colors.white : color,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor:
                                ScholifyColors.tint(color, isDark ? 0.2 : 0.12),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        progressLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: card,
    );
  }
}

/// Dashboard metrics data class
class DashboardMetrics {
  final int totalTenants;
  final int activeTenants;
  final int atRiskTenants;
  final int expiringSoonTenants;

  const DashboardMetrics({
    required this.totalTenants,
    required this.activeTenants,
    required this.atRiskTenants,
    required this.expiringSoonTenants,
  });
}
