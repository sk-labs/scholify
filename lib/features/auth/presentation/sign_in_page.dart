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
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppBranding.appName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text('Sign in to load your tenant workspace.'),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _identityController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email or username',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _handleSignIn(),
                      ),
                      if (error != null && error.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: isBusy ? null : _handleSignIn,
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
                          onPressed: isBusy
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ForgotPasswordPage(),
                                    ),
                                  );
                                },
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: isBusy ? null : _handleSignUp,
                          icon: const Icon(Icons.school),
                          label: const Text('Create a school account'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
