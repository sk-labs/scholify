import 'package:flutter/material.dart';

import '../../../app/app_runtime.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/constants/branding.dart';
import 'forgot_password_page.dart';
import 'self_service_signup_page.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key, required this.sessionManager});

  final SessionManager sessionManager;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController _identityController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.sessionManager,
      builder: (context, _) {
        final isBusy = widget.sessionManager.isSigningIn;
        final error = widget.sessionManager.errorMessage;

        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              // Split branding layout on wide screens, centered card on narrow.
              if (constraints.maxWidth >= 900) {
                return Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _BrandingPanel(),
                    ),
                    Expanded(
                      flex: 6,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 420),
                            child: _SignInForm(
                              identityController: _identityController,
                              passwordController: _passwordController,
                              isBusy: isBusy,
                              error: error,
                              onSignIn: _handleSignIn,
                              onForgotPassword: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ForgotPasswordPage(),
                                  ),
                                );
                              },
                              onSignUp: _handleSignUp,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Card(
                      margin: const EdgeInsets.all(16),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _SignInForm(
                          identityController: _identityController,
                          passwordController: _passwordController,
                          isBusy: isBusy,
                          error: error,
                          onSignIn: _handleSignIn,
                          onForgotPassword: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ForgotPasswordPage(),
                              ),
                            );
                          },
                          onSignUp: _handleSignUp,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleSignIn() async {
    final identity = _identityController.text.trim();
    final password = _passwordController.text;

    if (identity.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identity and password are required.')),
      );
      return;
    }

    await widget.sessionManager.signIn(identity: identity, password: password);
  }

  Future<void> _handleSignUp() async {
    final syncEngine = AppRuntime.syncEngine;
    final tenantContext = AppRuntime.tenantContext;
    if (syncEngine == null || tenantContext == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SelfServiceSignupPage(
          pocketbaseGateway: syncEngine.pocketbaseGateway,
          database: syncEngine.database,
          syncEngine: syncEngine,
          tenantContext: tenantContext,
          onSignupSuccess: () {
            // Signup auto-signs-in; pop back so the app shell is shown.
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
    );
  }
}

/// Branding panel shown beside the sign-in form on wide screens.
/// Uses the seed color as a full-height backdrop with product messaging.
class _BrandingPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;

    return Container(
      color: primary,
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: onPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.school,
              size: 48,
              color: onPrimary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            AppBranding.appName,
            style: theme.textTheme.displaySmall?.copyWith(
              color: onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'The complete school management platform — admissions to alumni, in one workspace.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: onPrimary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 40),
          _BrandingBullet(
            icon: Icons.offline_bolt_outlined,
            text: 'Offline-first — works without internet, syncs when connected',
          ),
          const SizedBox(height: 16),
          _BrandingBullet(
            icon: Icons.groups_outlined,
            text: 'Multi-tenant — one platform for every school you manage',
          ),
          const SizedBox(height: 16),
          _BrandingBullet(
            icon: Icons.security_outlined,
            text: 'Role-based access for admins, teachers, and guardians',
          ),
        ],
      ),
    );
  }
}

class _BrandingBullet extends StatelessWidget {
  const _BrandingBullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: onPrimary.withValues(alpha: 0.9), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: onPrimary.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }
}

/// The sign-in form itself, shared between wide and narrow layouts.
class _SignInForm extends StatelessWidget {
  const _SignInForm({
    required this.identityController,
    required this.passwordController,
    required this.isBusy,
    required this.error,
    required this.onSignIn,
    required this.onForgotPassword,
    required this.onSignUp,
  });

  final TextEditingController identityController;
  final TextEditingController passwordController;
  final bool isBusy;
  final String? error;
  final VoidCallback onSignIn;
  final VoidCallback onForgotPassword;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to load your tenant workspace.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: identityController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email or username',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock_outline),
          ),
          onSubmitted: (_) => onSignIn(),
        ),
        if (error != null && error!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 20,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isBusy ? null : onSignIn,
            icon: isBusy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.login),
            label: Text(isBusy ? 'Signing in...' : 'Sign In'),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: isBusy ? null : onForgotPassword,
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: 4),
        const Divider(),
        const SizedBox(height: 4),
        Center(
          child: TextButton.icon(
            onPressed: isBusy ? null : onSignUp,
            icon: const Icon(Icons.school),
            label: const Text('Create a school account'),
          ),
        ),
      ],
    );
  }
}
