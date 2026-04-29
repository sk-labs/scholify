import 'package:flutter/material.dart';
import 'package:scholify/core/services/impersonation_service.dart';

/// Impersonation Banner Widget (Q3.3)
/// 
/// Displays a persistent banner when superadmin is impersonating a tenant.
/// Tapping the banner ends the impersonation session.
/// 
/// Requirements: Q3.3, Q3.4
class ImpersonationBanner extends StatelessWidget {
  final ImpersonationService impersonationService;

  const ImpersonationBanner({
    super.key,
    required this.impersonationService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: impersonationService,
      builder: (context, child) {
        // Q3.3: Only show banner when impersonation is active
        if (!impersonationService.isImpersonating) {
          return const SizedBox.shrink();
        }

        return Material(
          color: Colors.orange.shade700,
          child: InkWell(
            onTap: () => _handleEndImpersonation(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Impersonating: ${impersonationService.impersonatedTenantName} — tap to exit',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Q3.4: End impersonation and restore superadmin context
  Future<void> _handleEndImpersonation(BuildContext context) async {
    try {
      await impersonationService.endImpersonation();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impersonation ended'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end impersonation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
