import 'package:flutter/material.dart';

import '../../../core/database/local_database.dart';
import '../../../core/remote/pocketbase_gateway.dart';
import '../../../core/services/signup_validation_service.dart';
import '../../../core/sync/sync_engine.dart';
import '../../../core/tenant/tenant_context.dart';
import '../data/signup_service.dart';

/// Self-Service Tenant Signup Page
/// 
/// Feature: scholify-roadmap-tracker
/// Requirements: B1.1, B1.2, B1.3, B1.4, B1.5, B1.6, B1.7, B1.8
/// 
/// This page allows school administrators to register their school on Scholify
/// without contacting the platform operator. The signup flow:
/// 1. Collects school name, owner full name, owner email, and password
/// 2. Validates inputs (email format, password length >= 8)
/// 3. Checks email uniqueness in PocketBase
/// 4. Creates PocketBase user account
/// 5. Creates TenantRecord with isActive=true
/// 6. Creates TenantLicenseEntry with planCode='starter', seatLimit=100
/// 7. Auto-signs-in user and navigates to Foundation Shell
/// 8. Rolls back all records on failure
class SelfServiceSignupPage extends StatefulWidget {
  const SelfServiceSignupPage({
    super.key,
    required this.pocketbaseGateway,
    required this.database,
    required this.syncEngine,
    required this.tenantContext,
    required this.onSignupSuccess,
  });

  final PocketbaseGateway pocketbaseGateway;
  final AppLocalDatabase database;
  final SyncEngine syncEngine;
  final TenantContext tenantContext;
  final VoidCallback onSignupSuccess;

  @override
  State<SelfServiceSignupPage> createState() => _SelfServiceSignupPageState();
}

class _SelfServiceSignupPageState extends State<SelfServiceSignupPage> {
  late final SignupValidationService _validationService;
  late final SignupService _signupService;

  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _validationService = SignupValidationService();
    _signupService = SignupService(
      pocketbaseGateway: widget.pocketbaseGateway,
      database: widget.database,
      syncEngine: widget.syncEngine,
      tenantContext: widget.tenantContext,
      validationService: _validationService,
    );
  }

  @override
  void dispose() {
    _schoolNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up for Scholify'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  const Icon(
                    Icons.school,
                    size: 64,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Create Your School Account',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start using Scholify immediately on the starter plan',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // School Name Field (B1.2)
                  TextFormField(
                    controller: _schoolNameController,
                    decoration: const InputDecoration(
                      labelText: 'School Name',
                      hintText: 'e.g., Springfield High School',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'School name is required';
                      }
                      if (!_validationService.validateSchoolName(value)) {
                        return 'Please enter a valid school name';
                      }
                      return null;
                    },
                    enabled: !_isSubmitting,
                  ),
                  const SizedBox(height: 16),

                  // Owner Full Name Field (B1.2)
                  TextFormField(
                    controller: _ownerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Full Name',
                      hintText: 'e.g., John Smith',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Your full name is required';
                      }
                      if (!_validationService.validateOwnerFullName(value)) {
                        return 'Please enter a valid name';
                      }
                      return null;
                    },
                    enabled: !_isSubmitting,
                  ),
                  const SizedBox(height: 16),

                  // Email Field (B1.2, B1.3)
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'e.g., admin@springfield.edu',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email address is required';
                      }
                      if (!_validationService.validateEmail(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                    enabled: !_isSubmitting,
                  ),
                  const SizedBox(height: 16),

                  // Password Field (B1.2, B1.8)
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Minimum 8 characters',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      if (!_validationService.validatePassword(value)) {
                        return 'Password must be at least 8 characters';
                      }
                      return null;
                    },
                    enabled: !_isSubmitting,
                  ),
                  const SizedBox(height: 24),

                  // Error Message (B1.4, B1.7)
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_errorMessage != null) const SizedBox(height: 16),

                  // Submit Button (B1.5, B1.6)
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _handleSignup,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(
                      _isSubmitting ? 'Creating Account...' : 'Create Account',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info Text
                  Text(
                    'By signing up, you agree to start with a Starter plan '
                    '(100 seats, 365 days validity)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignup() async {
    // Clear previous error
    setState(() {
      _errorMessage = null;
    });

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Call signup service (B1.3, B1.4, B1.5, B1.6, B1.7)
      final result = await _signupService.signUp(
        schoolName: _schoolNameController.text.trim(),
        ownerFullName: _ownerNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result.success) {
        // Navigate to Foundation Shell (B1.6)
        widget.onSignupSuccess();
      } else {
        // Display error message (B1.4, B1.7)
        setState(() {
          _errorMessage = result.errorMessage ?? 'Signup failed. Please try again.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
