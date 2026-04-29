import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';

/// Branding Settings Page for School Owners
/// 
/// Feature: scholify-roadmap-tracker
/// Requirements: B3.1, B3.2, B3.6, B3.7
/// 
/// This page allows school owners to customize their school's branding by
/// uploading a logo and setting a display name.
class BrandingSettingsPage extends StatefulWidget {
  const BrandingSettingsPage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<BrandingSettingsPage> createState() => _BrandingSettingsPageState();
}

class _BrandingSettingsPageState extends State<BrandingSettingsPage> {
  final TextEditingController _displayNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  TenantBrandingEntry? _currentBranding;
  Uint8List? _selectedLogoBytes;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentBranding();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentBranding() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tenantId = widget.tenantContext.tenantId;
      if (tenantId == null) {
        setState(() {
          _errorMessage = 'No tenant context available';
          _isLoading = false;
        });
        return;
      }

      // Load existing branding
      final branding = await (widget.syncEngine.database
              .select(widget.syncEngine.database.tenantBrandingEntries)
            ..where((tbl) => tbl.tenantId.equals(tenantId))
            ..limit(1))
          .getSingleOrNull();

      // Load tenant name as default display name
      final tenant = await (widget.syncEngine.database
              .select(widget.syncEngine.database.tenantRecords)
            ..where((tbl) => tbl.id.equals(tenantId))
            ..limit(1))
          .getSingleOrNull();

      setState(() {
        _currentBranding = branding;
        _displayNameController.text = branding?.displayName ?? tenant?.name ?? '';
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to load branding: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Branding Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadCurrentBranding,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            const Icon(
                              Icons.palette,
                              size: 64,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Customize Your School Branding',
                              style: Theme.of(context).textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Set your school\'s display name and logo',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // Display Name Field (B3.1)
                            TextFormField(
                              controller: _displayNameController,
                              decoration: const InputDecoration(
                                labelText: 'Display Name',
                                hintText: 'e.g., Springfield High School',
                                prefixIcon: Icon(Icons.business),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Display name is required';
                                }
                                return null;
                              },
                              enabled: !_isSaving,
                            ),
                            const SizedBox(height: 24),

                            // Logo Section (B3.1)
                            Text(
                              'School Logo',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload a PNG or JPEG image (max 2 MB)',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                            const SizedBox(height: 16),

                            // Logo Preview
                            _buildLogoPreview(),
                            const SizedBox(height: 16),

                            // Upload Button
                            OutlinedButton.icon(
                              onPressed: _isSaving ? null : _pickLogo,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Upload Logo'),
                            ),
                            const SizedBox(height: 8),

                            // Remove Logo Button (B3.6)
                            if (_currentBranding?.logoBase64 != null || _selectedLogoBytes != null)
                              OutlinedButton.icon(
                                onPressed: _isSaving ? null : _removeLogo,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Remove Logo'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            const SizedBox(height: 32),

                            // Save Button (B3.2)
                            FilledButton.icon(
                              onPressed: _isSaving ? null : _handleSave,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(
                                _isSaving ? 'Saving...' : 'Save Branding',
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildLogoPreview() {
    Widget logoWidget;

    if (_selectedLogoBytes != null) {
      // Show newly selected logo
      logoWidget = Image.memory(
        _selectedLogoBytes!,
        height: 120,
        fit: BoxFit.contain,
      );
    } else if (_currentBranding?.logoBase64 != null) {
      // Show existing logo
      try {
        final bytes = base64Decode(_currentBranding!.logoBase64!);
        logoWidget = Image.memory(
          bytes,
          height: 120,
          fit: BoxFit.contain,
        );
      } catch (e) {
        logoWidget = const Icon(
          Icons.broken_image,
          size: 120,
          color: Colors.grey,
        );
      }
    } else {
      // Show placeholder
      logoWidget = const Icon(
        Icons.image_outlined,
        size: 120,
        color: Colors.grey,
      );
    }

    return Container(
      height: 150,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: Center(child: logoWidget),
    );
  }

  Future<void> _pickLogo() async {
    // For now, show a message that file picking requires additional setup
    // In a real implementation, you would use file_picker package or platform-specific file dialogs
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Logo upload requires file_picker package. '
          'Add "file_picker" to pubspec.yaml to enable this feature.',
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
    
    // TODO: Implement file picking when file_picker package is added
    // Example implementation:
    // final result = await FilePicker.platform.pickFiles(
    //   type: FileType.image,
    //   allowMultiple: false,
    // );
    // if (result != null && result.files.isNotEmpty) {
    //   final bytes = result.files.first.bytes;
    //   if (bytes != null && bytes.length <= _maxLogoSizeBytes) {
    //     setState(() {
    //       _selectedLogoBytes = bytes;
    //     });
    //   }
    // }
  }

  void _removeLogo() {
    setState(() {
      _selectedLogoBytes = null;
    });
  }

  Future<void> _handleSave() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final tenantId = widget.tenantContext.tenantId!;
      final displayName = _displayNameController.text.trim();
      final now = DateTime.now().toUtc();

      // Encode logo to base64 if selected (B3.2)
      String? logoBase64;
      if (_selectedLogoBytes != null) {
        logoBase64 = base64Encode(_selectedLogoBytes!);
      } else if (_currentBranding?.logoBase64 != null) {
        // Keep existing logo if not changed
        logoBase64 = _currentBranding!.logoBase64;
      }

      final brandingId = 'branding_$tenantId';

      // Upsert TenantBrandingEntry (B3.2)
      await widget.syncEngine.database
          .into(widget.syncEngine.database.tenantBrandingEntries)
          .insertOnConflictUpdate(
            TenantBrandingEntriesCompanion.insert(
              id: brandingId,
              tenantId: tenantId,
              displayName: displayName,
              logoBase64: Value(logoBase64),
            ),
          );

      // Enqueue sync operation (B3.2)
      await widget.syncEngine.enqueueOperation(
        entityType: 'tenant_branding',
        entityId: brandingId,
        operation: 'upsert',
        payload: jsonEncode({
          'id': brandingId,
          'tenantId': tenantId,
          'displayName': displayName,
          'logoBase64': logoBase64,
          'updatedAt': now.toIso8601String(),
        }),
      );

      // Notify TenantContext to refresh (B3.2)
      // The shell will reload branding on next build

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Branding saved successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload to show updated branding
      await _loadCurrentBranding();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save branding: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
