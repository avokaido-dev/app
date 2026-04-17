import 'package:flutter/material.dart';

import 'auth_service.dart';

/// Public landing page for avokaido-app.web.app.
///
/// Doubles as the sign-in screen — anyone can read the product pitch
/// without an account, then scroll down (or hit the top-right button)
/// to continue with GitHub / Microsoft / Apple.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, required this.auth});
  final AuthService auth;

  static const _brandGreen = Color(0xFF2F6B3B);
  static const _brandBg = Color(0xFFF2F5EF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _brandBg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(onSignInPressed: () => _scrollToSignIn(context)),
            const _Hero(),
            const SizedBox(height: 48),
            const _FeatureGrid(),
            const SizedBox(height: 64),
            _HowItWorks(),
            const SizedBox(height: 64),
            _SignInCard(auth: auth),
            const SizedBox(height: 48),
            const _Footer(),
          ],
        ),
      ),
    );
  }

  void _scrollToSignIn(BuildContext context) {
    // Crude but effective for a one-page landing: scroll to bottom where
    // the sign-in card lives.
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
              color: SignInScreen._brandGreen,
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onSignInPressed,
            style: FilledButton.styleFrom(
              backgroundColor: SignInScreen._brandGreen,
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
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              const Text(
                'The dev platform\nthat ships for you.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: Color(0xFF0E2812),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Avokaido turns a ticket into a pull request. Plan, '
                'implement, and verify across every repo in your workspace — '
                'backed by Claude, GPT, and Gemini. Your team stays in the '
                'loop; the grunt work gets done.',
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
                      backgroundColor: SignInScreen._brandGreen,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Link out to product docs once live; placeholder for now.
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('See a demo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SignInScreen._brandGreen,
                      side: BorderSide(
                          color: SignInScreen._brandGreen.withAlpha(120)),
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
// Feature grid
// ---------------------------------------------------------------------------

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 820;
              final features = [
                _FeatureCard(
                  icon: Icons.hub_outlined,
                  title: 'Multi-repo orchestration',
                  body: 'One cockpit for every repo in your workspace. '
                      'Plan, implement, QA, and push to staging without '
                      'juggling ten windows.',
                ),
                _FeatureCard(
                  icon: Icons.auto_awesome_outlined,
                  title: 'AI that actually ships',
                  body: 'Hand off tickets to Claude or GPT. Watch them '
                      'code, run your tests, and open a pull request '
                      'while you review the plan.',
                ),
                _FeatureCard(
                  icon: Icons.shield_outlined,
                  title: 'Secure by default',
                  body: 'Admin-managed API keys. Per-workspace settings '
                      'locks. SSO for the whole team. Your keys never '
                      'leave the org.',
                ),
              ];
              return wide
                  ? Row(
                      children: [
                        for (final f in features) ...[
                          Expanded(child: f),
                          if (f != features.last) const SizedBox(width: 20),
                        ],
                      ],
                    )
                  : Column(
                      children: [
                        for (final f in features) ...[
                          f,
                          if (f != features.last) const SizedBox(height: 20),
                        ],
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SignInScreen._brandGreen.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: SignInScreen._brandGreen, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0E2812),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// How it works
// ---------------------------------------------------------------------------

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = <(int, String, String)>[
    (
      1,
      'Sign in',
      'GitHub, Microsoft, or Apple. No email/password — use the accounts '
          'your team already has.',
    ),
    (
      2,
      'Create your workspace',
      'Name it, invite your team, and connect your repos. You are the '
          'workspace admin by default.',
    ),
    (
      3,
      'Ship',
      'Download the desktop app, connect a ticket provider, and hand your '
          'first ticket to the AI. Review the PR when it opens.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'How it works',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0E2812),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'From landing here to your first shipped ticket in under ten minutes.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 720;
                  final widgets = [
                    for (final s in _steps)
                      _StepTile(number: s.$1, title: s.$2, body: s.$3),
                  ];
                  return wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final w in widgets) ...[
                              Expanded(child: w),
                              if (w != widgets.last) const SizedBox(width: 24),
                            ],
                          ],
                        )
                      : Column(
                          children: [
                            for (final w in widgets) ...[
                              w,
                              if (w != widgets.last) const SizedBox(height: 20),
                            ],
                          ],
                        );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.number,
    required this.title,
    required this.body,
  });

  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SignInScreen._brandGreen,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0E2812),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: const TextStyle(fontSize: 14.5, height: 1.5),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sign-in card
// ---------------------------------------------------------------------------

class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: SignInScreen._signInKey,
      padding: const EdgeInsets.symmetric(horizontal: 32),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sign in to Avokaido',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E2812),
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
                  onPressed: auth.signInWithGithub,
                ),
                const SizedBox(height: 10),
                _ProviderButton(
                  label: 'Continue with Microsoft',
                  icon: Icons.business,
                  onPressed: auth.signInWithMicrosoft,
                ),
                const SizedBox(height: 10),
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
        foregroundColor: const Color(0xFF0E2812),
        side: BorderSide(color: SignInScreen._brandGreen.withAlpha(90)),
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
          Text(
            '© ${DateTime.now().year} Avokaido',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
