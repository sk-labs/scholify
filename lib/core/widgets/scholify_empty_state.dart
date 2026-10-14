import 'package:flutter/material.dart';

import '../theme/scholify_colors.dart';

/// A polished, illustrated empty state.
///
/// Replaces plain "No X yet" text with a branded visual: a large icon in a
/// tinted medallion, a title, a helpful message, and an optional action
/// button that makes the product feel alive instead of unfinished.
class ScholifyEmptyState extends StatelessWidget {
  const ScholifyEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accentColor = accent ?? scheme.secondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustrated medallion
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: ScholifyColors.tint(accentColor, 0.12),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: ScholifyColors.tint(accentColor, 0.16),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Icon(icon, size: 40, color: accentColor),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
