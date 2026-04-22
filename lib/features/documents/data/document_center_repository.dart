import 'dart:convert';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

class DocumentCenterRepository {
  DocumentCenterRepository({
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
  });

  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;

  static const String contentTypeDownload = 'download_content';
  static const String contentTypeVideo = 'video_tutorial';
  static const String contentTypeMyDocument = 'my_document';

  Stream<List<DocumentCenterEntry>> watchDownloadContents({
    bool includeInactive = false,
  }) {
    return database.watchDocumentCenterItems(
      tenantId: _resolveTenantId(),
      contentType: contentTypeDownload,
      includeInactive: includeInactive,
    );
  }

  Stream<List<DocumentCenterEntry>> watchVideoTutorials({
    bool includeInactive = false,
  }) {
    return database.watchDocumentCenterItems(
      tenantId: _resolveTenantId(),
      contentType: contentTypeVideo,
      includeInactive: includeInactive,
    );
  }

  Stream<List<DocumentCenterEntry>> watchMyDocuments({
    bool includeInactive = false,
  }) {
    return database.watchDocumentCenterItems(
      tenantId: _resolveTenantId(),
      contentType: contentTypeMyDocument,
      includeInactive: includeInactive,
    );
  }

  Future<void> saveItem({
    String? itemId,
    required String contentType,
    required String title,
    String? description,
    String? fileUrl,
    String? thumbnailUrl,
    String? categoryLabel,
    String uploadState = 'uploaded',
    DateTime? publishedAt,
    bool isActive = true,
  }) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();
    final resolvedId =
        itemId ?? 'doc_${tenantId}_${now.microsecondsSinceEpoch}';

    await database.upsertDocumentCenterRecord(
      itemId: resolvedId,
      tenantId: tenantId,
      contentType: contentType,
      title: title,
      description: description,
      fileUrl: fileUrl,
      thumbnailUrl: thumbnailUrl,
      categoryLabel: categoryLabel,
      uploadState: uploadState,
      publishedAt: publishedAt?.toUtc() ?? now,
      isActive: isActive,
      source: 'local',
      updatedAt: now,
    );

    await syncEngine.enqueueOperation(
      entityType: 'document_center_item',
      entityId: resolvedId,
      operation: 'upsert',
      payload: jsonEncode({
        'itemId': resolvedId,
        'tenantId': tenantId,
        'contentType': contentType,
        'title': title,
        'description': description,
        'fileUrl': fileUrl,
        'thumbnailUrl': thumbnailUrl,
        'categoryLabel': categoryLabel,
        'uploadState': uploadState,
        'publishedAt': (publishedAt?.toUtc() ?? now).toIso8601String(),
        'isActive': isActive,
        'source': 'local',
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  Future<void> deleteItem(DocumentCenterEntry item) async {
    final tenantId = _resolveTenantId();
    final now = DateTime.now().toUtc();

    await database.deleteDocumentCenterRecord(
      tenantId: tenantId,
      itemId: item.id,
    );

    await syncEngine.enqueueOperation(
      entityType: 'document_center_item',
      entityId: item.id,
      operation: 'delete',
      payload: jsonEncode({
        'itemId': item.id,
        'tenantId': tenantId,
        'updatedAt': now.toIso8601String(),
      }),
    );
  }

  String _resolveTenantId() {
    if (tenantContext.tenantId != null && tenantContext.tenantId!.isNotEmpty) {
      return tenantContext.tenantId!;
    }
    return 'school_demo';
  }
}
