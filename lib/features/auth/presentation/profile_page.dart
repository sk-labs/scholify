import 'package:flutter/material.dart';

import '../../../app/app_runtime.dart';
import '../../../core/tenant/tenant_context.dart';
import 'change_password_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final gateway = AppRuntime.syncEngine?.pocketbaseGateway;
      if (gateway == null || !gateway.isAuthenticated) {
        throw Exception('Not signed in.');
      }

      final userId =
          gateway.client.authStore.model?['id']?.toString() ?? '';
      if (userId.isEmpty) throw Exception('Session expired.');

      final record =
          await gateway.client.collection('users').getOne(userId);
      setState(() {
        _profileData = record.toJson();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantContext = AppRuntime.tenantContext;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildTenantCard(tenantContext),
                    const SizedBox(height: 16),
                    if (_profileData != null) _buildProfileCard(_profileData!),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ChangePasswordPage(),
                          ),
                        ),
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Change Password'),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTenantCard(TenantContext? ctx) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Workspace', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Tenant: ${ctx?.tenantName ?? 'Unknown'}'),
            Text('Role: ${ctx?.role ?? 'Unknown'}'),
            if (ctx?.isSuperAdmin == true)
              const Text('Superadmin: Yes'),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> data) {
    final email = data['email']?.toString() ?? 'N/A';
    final username = data['username']?.toString() ?? '';
    final name = data['name']?.toString() ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (name.isNotEmpty) Text('Name: $name'),
            Text('Email: $email'),
            if (username.isNotEmpty) Text('Username: $username'),
          ],
        ),
      ),
    );
  }
}
