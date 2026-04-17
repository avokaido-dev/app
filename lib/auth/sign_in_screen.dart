import 'package:flutter/material.dart';

import 'auth_service.dart';

/// First screen the end user sees. Three OAuth buttons — no email/password.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Avokaido',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to create or join a workspace.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 32),
                _ProviderButton(
                  label: 'Continue with GitHub',
                  icon: Icons.code,
                  onPressed: auth.signInWithGithub,
                ),
                const SizedBox(height: 12),
                _ProviderButton(
                  label: 'Continue with Microsoft',
                  icon: Icons.business,
                  onPressed: auth.signInWithMicrosoft,
                ),
                const SizedBox(height: 12),
                _ProviderButton(
                  label: 'Continue with Apple',
                  icon: Icons.apple,
                  onPressed: auth.signInWithApple,
                ),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    auth.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'By continuing you agree to the Avokaido terms.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    );
  }
}
