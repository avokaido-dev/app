import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../marketing/pitch_sections.dart';
import 'auth_service.dart';

/// Public landing page for avokaido-app.web.app.
///
/// Doubles as the sign-in screen — anyone can read the product pitch
/// without an account, then scroll down (or hit the top-right button)
/// to continue with GitHub / Google / Microsoft / Apple.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(onSignInPressed: () => _scrollToSignIn(context)),
            const _Hero(),
            const PitchProblem(),
            const PitchProcessToday(),
            const PitchProcessWithAvokaido(),
            const PitchLovableBridge(),
            const PitchSolution(),
            const PitchSegments(),
            const PitchPricing(),
            _SignInCard(auth: auth),
            const SizedBox(height: 48),
            const _Footer(),
          ],
        ),
      ),
    );
  }

  void _scrollToSignIn(BuildContext context) {
    Scrollable.ensureVisible(
      _signInKey.currentContext ?? context,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  static final _signInKey = GlobalKey();
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSignInPressed});
  final VoidCallback onSignInPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
        children: [
          const Text(
            'Avokaido',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Brand.green,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => context.go('/investors'),
            style: TextButton.styleFrom(
              foregroundColor: Brand.darkGreen,
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: const Text('For investors'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onSignInPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Brand.green,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            children: [
              const Text(
                'Lovable speed.\nEnterprise control.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: Brand.darkGreen,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Avokaido is the AI development platform for teams that need '
                'speed without losing control. Build with Lovable, operate '
                'with us — we add the security, compliance, and quality '
                'gates enterprises demand.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.55,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => Scrollable.ensureVisible(
                      SignInScreen._signInKey.currentContext ?? context,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                    ),
                    icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                    label: const Text('Create your workspace'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Brand.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/investors'),
                    icon: const Icon(Icons.trending_up, size: 18),
                    label: const Text('For investors'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Brand.green,
                      side: BorderSide(color: Brand.green.withAlpha(120)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sign-in card
// ---------------------------------------------------------------------------

class _SignInCard extends StatefulWidget {
  const _SignInCard({required this.auth});
  final AuthService auth;

  @override
  State<_SignInCard> createState() => _SignInCardState();
}

enum _EmailMode { signUp, signIn }

class _SignInCardState extends State<_SignInCard> {
  bool _showEmail = false;
  _EmailMode _mode = _EmailMode.signUp;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _emailBusy = false;
  bool _oauthBusy = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthUpdate);
  }

  void _onAuthUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthUpdate);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _tryOAuth(Future<void> Function() fn) async {
    setState(() => _oauthBusy = true);
    await fn();
    if (mounted) setState(() => _oauthBusy = false);
  }

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;
    setState(() => _emailBusy = true);
    if (_mode == _EmailMode.signUp) {
      await widget.auth.signUpWithEmail(email: email, password: password);
    } else {
      await widget.auth.signInWithEmail(email: email, password: password);
    }
    if (mounted) setState(() => _emailBusy = false);
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first.')),
      );
      return;
    }
    await widget.auth.sendPasswordResetEmail(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset sent to $email.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = widget.auth.user != null;
    final awaitingEmailLink = widget.auth.pendingEmailLinkNeedsEmail;
    return Container(
      key: SignInScreen._signInKey,
      color: Brand.bg,
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(14),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: signedIn
                ? _buildSignedIn(context)
                : awaitingEmailLink
                    ? _buildEmailLinkConfirm()
                    : _buildSignedOut(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailLinkConfirm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Finish signing in',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Brand.darkGreen,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Confirm the email address you were invited with to complete your '
          'sign-in. No password needed.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _completeEmailLink(),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _emailBusy ? null : _completeEmailLink,
          style: FilledButton.styleFrom(
            backgroundColor: Brand.green,
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          child: _emailBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Continue'),
        ),
        if (widget.auth.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.auth.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Future<void> _completeEmailLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _emailBusy = true);
    await widget.auth.completeEmailLinkSignIn(email);
    if (mounted) setState(() => _emailBusy = false);
  }

  Widget _buildSignedIn(BuildContext context) {
    final auth = widget.auth;
    final email = auth.user?.email ?? 'your account';
    final (title, body, cta, target) = switch (auth.status) {
      AuthStatus.signedOut => (
          'Signed out',
          'You were signed out. Sign in again to continue.',
          null,
          null,
        ),
      AuthStatus.signedInPending => (
          "You're signed in",
          'Loading your workspace…',
          null,
          null,
        ),
      AuthStatus.signedInNoWorkspace => (
          "You're signed in",
          'No workspace yet for $email. Create one to get started — you '
              'will become the org admin for your email domain.',
          'Create workspace',
          '/create-workspace',
        ),
      AuthStatus.signedInWithWorkspace => (
          "You're signed in",
          auth.isOrgAdmin
              ? 'Continue to your admin workspace.'
              : 'Continue to download the desktop app.',
          'Continue',
          auth.isOrgAdmin ? '/workspace/costs' : '/workspace/download',
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Brand.green.withAlpha(40),
              child: Text(
                (email.isNotEmpty ? email[0] : '?').toUpperCase(),
                style: const TextStyle(
                  color: Brand.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Brand.darkGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          body,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        if (auth.status == AuthStatus.signedInPending) ...[
          const SizedBox(height: 20),
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ],
        if (cta != null && target != null) ...[
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.go(target),
            style: FilledButton.styleFrom(
              backgroundColor: Brand.green,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            child: Text(cta),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: auth.signOut,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: Brand.darkGreen,
            side: BorderSide(color: Brand.green.withAlpha(90)),
          ),
          child: const Text('Sign out'),
        ),
        if (auth.errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            auth.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _buildSignedOut() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Sign in to Avokaido',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Brand.darkGreen,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Use your existing account — we never ask for passwords.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 24),
        _ProviderButton(
          label: 'Continue with GitHub',
          icon: Icons.code,
          loading: _oauthBusy,
          onPressed:
              _oauthBusy ? null : () => _tryOAuth(widget.auth.signInWithGithub),
        ),
        const SizedBox(height: 10),
        _ProviderButton(
          label: 'Continue with Google',
          icon: Icons.g_mobiledata,
          loading: _oauthBusy,
          onPressed:
              _oauthBusy ? null : () => _tryOAuth(widget.auth.signInWithGoogle),
        ),
        const SizedBox(height: 10),
        _ProviderButton(
          label: 'Continue with Microsoft',
          icon: Icons.business,
          loading: _oauthBusy,
          onPressed: _oauthBusy
              ? null
              : () => _tryOAuth(widget.auth.signInWithMicrosoft),
        ),
        const SizedBox(height: 10),
        _ProviderButton(
          label: 'Continue with Apple',
          icon: Icons.apple,
          loading: _oauthBusy,
          onPressed:
              _oauthBusy ? null : () => _tryOAuth(widget.auth.signInWithApple),
        ),
        const SizedBox(height: 18),
        if (!_showEmail)
          TextButton.icon(
            onPressed: () => setState(() => _showEmail = true),
            icon: const Icon(Icons.mail_outline, size: 16),
            label: const Text('Use email and password instead'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black54,
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          )
        else
          _EmailBlock(
            mode: _mode,
            emailController: _emailController,
            passwordController: _passwordController,
            busy: _emailBusy,
            obscure: _obscure,
            onObscureToggle: () => setState(() => _obscure = !_obscure),
            onModeToggle: () => setState(() => _mode =
                _mode == _EmailMode.signUp
                    ? _EmailMode.signIn
                    : _EmailMode.signUp),
            onSubmit: _submitEmail,
            onForgot: _forgotPassword,
            onHide: () => setState(() => _showEmail = false),
          ),
        if (widget.auth.errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.auth.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ],
        const SizedBox(height: 18),
        const Text(
          'By continuing you agree to the Avokaido terms.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: Colors.black45),
        ),
      ],
    );
  }
}

class _EmailBlock extends StatelessWidget {
  const _EmailBlock({
    required this.mode,
    required this.emailController,
    required this.passwordController,
    required this.busy,
    required this.obscure,
    required this.onObscureToggle,
    required this.onModeToggle,
    required this.onSubmit,
    required this.onForgot,
    required this.onHide,
  });

  final _EmailMode mode;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool busy;
  final bool obscure;
  final VoidCallback onObscureToggle;
  final VoidCallback onModeToggle;
  final VoidCallback onSubmit;
  final VoidCallback onForgot;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final isSignUp = mode == _EmailMode.signUp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or email & password',
                style: TextStyle(color: Colors.black45, fontSize: 12),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          obscureText: obscure,
          autofillHints: [
            isSignUp ? AutofillHints.newPassword : AutofillHints.password,
          ],
          decoration: InputDecoration(
            labelText: 'Password',
            helperText: isSignUp ? 'At least 6 characters' : null,
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: IconButton(
              icon: Icon(obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: onObscureToggle,
            ),
          ),
          onSubmitted: (_) => onSubmit(),
        ),
        if (!isSignUp) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onForgot,
              child: const Text('Forgot password?'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: Brand.green,
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle:
                const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
          ),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(isSignUp ? 'Create account' : 'Sign in'),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isSignUp
                  ? 'Already have an account? '
                  : "Don't have an account? ",
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            TextButton(
              onPressed: onModeToggle,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(isSignUp ? 'Sign in' : 'Sign up'),
            ),
          ],
        ),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: onHide,
            style: TextButton.styleFrom(
              foregroundColor: Colors.black45,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Back to OAuth providers'),
          ),
        ),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        foregroundColor: Brand.darkGreen,
        side: BorderSide(color: Brand.green.withAlpha(90)),
        textStyle:
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          Wrap(
            spacing: 20,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: () => context.go('/investors'),
                style: TextButton.styleFrom(
                  foregroundColor: Brand.darkGreen,
                  textStyle: const TextStyle(fontSize: 13),
                ),
                child: const Text('For investors'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '© ${DateTime.now().year} Avokaido',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
