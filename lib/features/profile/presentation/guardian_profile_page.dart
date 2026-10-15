import 'package:flutter/material.dart';

import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../../../core/theme/scholify_colors.dart';

/// Guardian profile page: personal details, relationship with student,
/// contact info, and password change.
class GuardianProfilePage extends StatefulWidget {
  const GuardianProfilePage({
    super.key,
    required this.tenantContext,
    required this.syncEngine,
  });

  final TenantContext tenantContext;
  final SyncEngine syncEngine;

  @override
  State<GuardianProfilePage> createState() => _GuardianProfilePageState();
}

class _GuardianProfilePageState extends State<GuardianProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _relationshipController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String _email = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final gateway = widget.syncEngine.pocketbaseGateway;
      final userId = gateway.client.authStore.model?.id;
      if (userId == null || userId.isEmpty) {
        setState(() {
          _error = 'Not signed in';
          _isLoading = false;
        });
        return;
      }
      final record =
          await gateway.client.collection('users').getOne(userId);
      setState(() {
        _email = record.getStringValue('email');
        _nameController.text = record.getStringValue('name');
        _phoneController.text = record.getStringValue('phone');
        _addressController.text = record.getStringValue('address');
        _relationshipController.text =
            record.getStringValue('relationship');
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load profile: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final gateway = widget.syncEngine.pocketbaseGateway;
      final userId = gateway.client.authStore.model?.id;
      if (userId == null || userId.isEmpty) {
        throw Exception('Not signed in');
      }
      await gateway.client.collection('users').update(userId, body: {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'relationship': _relationshipController.text.trim(),
        'profile_completed': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showChangePassword() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (newController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('New passwords do not match')),
                );
                return;
              }
              if (newController.text.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Password must be at least 8 characters')),
                );
                return;
              }
              try {
                final gateway = widget.syncEngine.pocketbaseGateway;
                final userId =
                    gateway.client.authStore.model?.id;
                if (userId == null || userId.isEmpty) {
                  throw Exception('Not signed in');
                }
                await gateway.client
                    .collection('users')
                    .update(userId, body: {
                  'oldPassword': currentController.text,
                  'password': newController.text,
                  'passwordConfirm': newController.text,
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Password changed')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Could not change password: $e')),
                  );
                }
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(theme),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextField(
                  theme,
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  theme,
                  controller: TextEditingController(text: _email),
                  label: 'Email',
                  icon: Icons.email_outlined,
                  enabled: false,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  theme,
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Phone is required'
                          : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  theme,
                  controller: _relationshipController,
                  label: 'Relationship with Student',
                  icon: Icons.family_restroom_outlined,
                  hint: 'e.g. Father, Mother, Guardian',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Relationship is required'
                          : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  theme,
                  controller: _addressController,
                  label: 'Home Address',
                  icon: Icons.home_outlined,
                  maxLines: 2,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Address is required'
                          : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveProfile,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _showChangePassword,
              icon: const Icon(Icons.lock_outlined),
              label: const Text('Change Password'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ScholifyColors.academicNavy,
            ScholifyColors.navyLight,
            ScholifyColors.scholarTeal.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ScholifyColors.academicNavy.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Profile',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _nameController.text.isEmpty
                      ? 'Guardian'
                      : _nameController.text,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep your contact details up to date',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.person_outlined,
                color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    ThemeData theme, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: !enabled,
      ),
    );
  }
}
