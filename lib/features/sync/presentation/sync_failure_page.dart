import 'package:flutter/material.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/app/app_runtime.dart';

/// Sync Failure Page (A2: Sync Failure Visibility)
/// 
/// Displays all failed sync operations where retryCount > 0 and status != 'synced'
/// 
/// Requirements:
/// - A2.1: Display all failed SyncQueueEntries ordered by updatedAt DESC
/// - A2.2: Display entity type, entity ID, operation, retry count, error message, timestamp
/// - A2.3: Provide "Retry All" action to re-enqueue all failed entries
/// - A2.4: Provide per-entry "Dismiss" action to remove entry from failed list
/// - A2.6: Display "All operations synced successfully" when no failures
class SyncFailurePage extends StatelessWidget {
  const SyncFailurePage({super.key});

  @override
  Widget build(BuildContext context) {
    final syncEngine = AppRuntime.syncEngine;
    
    if (syncEngine == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sync Failures'),
        ),
        body: const Center(
          child: Text('Sync engine not initialized'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Failures'),
        elevation: 2,
        actions: [
          // Retry All button (A2.3)
          StreamBuilder<List<SyncQueueEntry>>(
            stream: syncEngine.database.watchFailedSyncEntries(),
            builder: (context, snapshot) {
              final hasFailures = (snapshot.data?.isNotEmpty ?? false);
              
              if (!hasFailures) {
                return const SizedBox.shrink();
              }
              
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton.icon(
                  onPressed: () => _handleRetryAll(context, syncEngine),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry All'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<SyncQueueEntry>>(
        stream: syncEngine.database.watchFailedSyncEntries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading sync failures',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final failedEntries = snapshot.data ?? [];

          // Empty state: no failures (A2.6)
          if (failedEntries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.green[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'All operations synced successfully',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.green[700],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No sync failures to display',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            );
          }

          // Display failed entries (A2.1, A2.2)
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: failedEntries.length,
            itemBuilder: (context, index) {
              final entry = failedEntries[index];
              return _FailedSyncEntryCard(
                entry: entry,
                onDismiss: () => _handleDismiss(context, syncEngine, entry),
              );
            },
          );
        },
      ),
    );
  }

  /// Handle "Retry All" action (A2.3)
  Future<void> _handleRetryAll(BuildContext context, SyncEngine syncEngine) async {
    try {
      // Reset all failed entries to pending state
      final count = await syncEngine.database.retryAllFailedEntries();
      
      if (!context.mounted) return;
      
      // Show confirmation snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Retrying $count ${count == 1 ? 'operation' : 'operations'}...'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Trigger manual sync to process the reset entries
      await syncEngine.manualSync();
      
      if (!context.mounted) return;
      
      // Show completion snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sync completed'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to retry operations: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Handle "Dismiss" action for a single entry (A2.4)
  Future<void> _handleDismiss(
    BuildContext context,
    SyncEngine syncEngine,
    SyncQueueEntry entry,
  ) async {
    try {
      // Delete the entry from the queue
      final deleted = await syncEngine.database.dismissSyncEntry(entry.id);
      
      if (!context.mounted) return;
      
      if (deleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dismissed ${_formatEntityType(entry.entityType)} sync operation'),
            backgroundColor: Colors.grey[700],
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry not found'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to dismiss entry: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Format entity type for display
  String _formatEntityType(String entityType) {
    return entityType
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

/// Card widget displaying a single failed sync entry
/// 
/// Displays (A2.2):
/// - Entity type
/// - Entity ID
/// - Operation
/// - Retry count
/// - Error message (placeholder since not stored in current schema)
/// - Last attempted timestamp
/// 
/// Actions (A2.4):
/// - Dismiss button to remove entry from queue
class _FailedSyncEntryCard extends StatelessWidget {
  final SyncQueueEntry entry;
  final VoidCallback onDismiss;

  const _FailedSyncEntryCard({
    required this.entry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Format timestamp
    final timestamp = entry.lastAttemptAt ?? entry.createdAt;
    final formattedTime = _formatTimestamp(timestamp);

    // Determine severity color based on retry count
    final severityColor = _getSeverityColor(entry.retryCount);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Entity type and retry count badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatEntityType(entry.entityType),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: severityColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh,
                        size: 14,
                        color: severityColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${entry.retryCount} ${entry.retryCount == 1 ? 'retry' : 'retries'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: severityColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Entity ID
            _InfoRow(
              icon: Icons.fingerprint,
              label: 'Entity ID',
              value: entry.entityId,
            ),
            const SizedBox(height: 8),
            
            // Operation
            _InfoRow(
              icon: Icons.sync_alt,
              label: 'Operation',
              value: _formatOperation(entry.operation),
            ),
            const SizedBox(height: 8),
            
            // Timestamp
            _InfoRow(
              icon: Icons.access_time,
              label: 'Last Attempt',
              value: formattedTime,
            ),
            const SizedBox(height: 8),
            
            // Status
            _InfoRow(
              icon: Icons.info_outline,
              label: 'Status',
              value: entry.status.toUpperCase(),
            ),
            
            // Error message section
            // Note: Current schema doesn't store error messages
            // This is a placeholder for future enhancement
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red[200]!,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 20,
                    color: Colors.red[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Error Message',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sync operation failed after ${entry.retryCount} ${entry.retryCount == 1 ? 'attempt' : 'attempts'}. The operation will be retried automatically.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Dismiss button (A2.4)
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Dismiss'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[400]!),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format entity type for display
  String _formatEntityType(String entityType) {
    return entityType
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Format operation for display
  String _formatOperation(String operation) {
    return operation.toUpperCase();
  }

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      // Format as date
      return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Get severity color based on retry count
  Color _getSeverityColor(int retryCount) {
    if (retryCount >= 4) {
      return Colors.red;
    } else if (retryCount >= 2) {
      return Colors.orange;
    } else {
      return Colors.amber;
    }
  }
}

/// Info row widget for displaying label-value pairs
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
