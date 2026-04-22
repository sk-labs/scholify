import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/teacher_repository.dart';

class TeachersPage extends StatefulWidget {
  const TeachersPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage> {
  late final TeacherRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = TeacherRepository(
      database: widget.syncEngine.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teachers')),
      body: StreamBuilder<List<TeacherEntry>>(
        stream: _repository.watchTeachers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final teachers = snapshot.data ?? const <TeacherEntry>[];
          if (teachers.isEmpty) {
            return const Center(child: Text('No teachers found.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: teachers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _buildTeacherCard(teachers[index]),
          );
        },
      ),
    );
  }

  Widget _buildTeacherCard(TeacherEntry teacher) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    teacher.fullName.isNotEmpty
                        ? teacher.fullName[0].toUpperCase()
                        : 'T',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              teacher.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (teacher.isClassTeacher)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Class Teacher',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (teacher.subjectName?.isNotEmpty == true)
                        Text(
                          teacher.subjectName!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (teacher.employeeNo?.isNotEmpty == true)
                  _detail(Icons.badge_outlined, 'ID: ${teacher.employeeNo}'),
                if (teacher.qualification?.isNotEmpty == true)
                  _detail(Icons.school_outlined, teacher.qualification!),
                if (teacher.email?.isNotEmpty == true)
                  _detail(Icons.email_outlined, teacher.email!),
                if (teacher.phone?.isNotEmpty == true)
                  _detail(Icons.phone_outlined, teacher.phone!),
                if (teacher.designation?.isNotEmpty == true)
                  _detail(Icons.work_outline, teacher.designation!),
                const SizedBox(height: 8),
                // Rating display / submit
                if (teacher.hasReviewed) ...[
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (i) => Icon(
                          i < teacher.ratingScore
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        teacher.reviewComment ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => _showRatingDialog(teacher),
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Edit review'),
                  ),
                ] else
                  FilledButton.tonalIcon(
                    onPressed: () => _showRatingDialog(teacher),
                    icon: const Icon(Icons.star_outline, size: 16),
                    label: const Text('Add Review'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Future<void> _showRatingDialog(TeacherEntry teacher) async {
    int rating = teacher.ratingScore;
    final commentController = TextEditingController(
      text: teacher.reviewComment ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: Text('Review: ${teacher.fullName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    icon: Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () => setInner(() => rating = i + 1),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: rating == 0
                  ? null
                  : () => Navigator.of(context).pop(true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    commentController.dispose();
    if (confirmed != true || rating == 0) return;

    try {
      await _repository.submitReview(
        teacher: teacher,
        ratingScore: rating,
        reviewComment: commentController.text.trim().isEmpty
            ? null
            : commentController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted and queued.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $e')),
        );
      }
    }
  }
}
