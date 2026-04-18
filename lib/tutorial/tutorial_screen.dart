import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../marketing/pitch_sections.dart';

/// Public step-by-step tutorial at `/tutorial`. Walks a new user through
/// signing up, creating a workspace, inviting their team, and shipping
/// their first ticket.
class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            _TutorialTopBar(),
            _TutorialHero(),
            _TutorialSteps(),
            _TutorialFaq(),
            _TutorialCta(),
            _TutorialFooter(),
          ],
        ),
      ),
    );
  }
}

class _TutorialTopBar extends StatelessWidget {
  const _TutorialTopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/signin'),
            child: const Text(
              'Avokaido',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Brand.green,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => context.go('/signin'),
            style: TextButton.styleFrom(
              foregroundColor: Brand.darkGreen,
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: const Text('Back to product'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.go('/signin'),
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

class _TutorialHero extends StatelessWidget {
  const _TutorialHero();

  @override
  Widget build(BuildContext context) {
    return PitchSection(
      verticalPadding: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PitchEyebrow('Getting started'),
          const SizedBox(height: 16),
          const PitchHeadline(
              'From empty account to\nyour first pull request.'),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: const PitchSubhead(
              'Six short steps. Expect to be through the whole flow in under '
              'fifteen minutes — most of that is just the desktop download.',
              fontSize: 17.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _Step {
  const _Step(this.n, this.title, this.body, this.icon);
  final int n;
  final String title;
  final String body;
  final IconData icon;
}

const _tutorialSteps = <_Step>[
  _Step(
    1,
    'Sign in',
    'Continue with GitHub, Google, Microsoft or Apple — or use email and '
        'password. We never ask for a password you already use elsewhere.',
    Icons.login,
  ),
  _Step(
    2,
    'Create your workspace',
    'Name your workspace and pick an email domain. You automatically '
        'become the org admin for everyone sharing that domain.',
    Icons.workspace_premium_outlined,
  ),
  _Step(
    3,
    'Add your AI provider keys',
    'Under Settings, paste your Claude, OpenAI and Gemini API keys. '
        'Charges flow directly from the provider to you — we add a flat '
        '2% markup, nothing else.',
    Icons.vpn_key_outlined,
  ),
  _Step(
    4,
    'Invite your team',
    'Under Team, enter teammates\' emails. We create Firebase accounts '
        'for them and email a passwordless sign-in link. No provisioning '
        'forms, no admin chasing.',
    Icons.group_add_outlined,
  ),
  _Step(
    5,
    'Download the desktop app',
    'Everyone on the team downloads Avokaido Desktop from the Download '
        'page. It signs in with the same workspace and pulls your team '
        'settings automatically.',
    Icons.download_outlined,
  ),
  _Step(
    6,
    'Ship your first ticket',
    'Connect a repo, hand the AI a ticket, and review the plan. Claude '
        'or GPT writes the code, runs your tests, and opens a pull '
        'request. You review and merge.',
    Icons.rocket_launch_outlined,
  ),
];

class _TutorialSteps extends StatelessWidget {
  const _TutorialSteps();

  @override
  Widget build(BuildContext context) {
    return PitchSection(
      background: Brand.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _tutorialSteps.length; i++) ...[
            _StepRow(step: _tutorialSteps[i]),
            if (i < _tutorialSteps.length - 1) const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});
  final _Step step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Brand.green, width: 4)),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth > 640;
        final number = Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration:
              const BoxDecoration(color: Brand.green, shape: BoxShape.circle),
          child: Text('${step.n}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
        );
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(step.icon, color: Brand.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(step.title,
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Brand.darkGreen)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(step.body,
                style: const TextStyle(fontSize: 14.5, height: 1.55)),
          ],
        );
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              number,
              const SizedBox(height: 16),
              text,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            number,
            const SizedBox(width: 20),
            Expanded(child: text),
          ],
        );
      }),
    );
  }
}

class _TutorialFaq extends StatelessWidget {
  const _TutorialFaq();

  @override
  Widget build(BuildContext context) {
    const faqs = <(String, String)>[
      (
        'Do I need to bring my own API keys?',
        'Yes. You add your Claude, OpenAI and Gemini keys once in '
            'Settings. The provider bills you directly for token usage; '
            'Avokaido adds a flat 2% platform markup on top of that spend.',
      ),
      (
        'Can teammates use the platform without being admins?',
        'Yes. Org admins manage settings and invite team members; everyone '
            'else signs in, downloads the desktop app, and ships. Members '
            'inherit the workspace\'s provider keys automatically.',
      ),
      (
        'What if my teammate clicks the invite link on a different device?',
        'Supported. They\'ll be asked to confirm the email address they '
            'were invited with, and the sign-in completes without a '
            'password.',
      ),
      (
        'Where is my code stored?',
        'In your own GitHub repository. Avokaido reads it, runs your tests '
            'and quality gates, and opens pull requests — we never host '
            'your source.',
      ),
    ];
    return PitchSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PitchEyebrow('Frequently asked'),
          const SizedBox(height: 16),
          const PitchHeadline('Quick answers before you dive in.'),
          const SizedBox(height: 32),
          for (final (q, a) in faqs) ...[
            _FaqItem(question: q, answer: a),
            if ((q, a) != faqs.last) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: Brand.darkGreen),
          ),
          const SizedBox(height: 6),
          Text(answer,
              style: const TextStyle(fontSize: 14, height: 1.55)),
        ],
      ),
    );
  }
}

class _TutorialCta extends StatelessWidget {
  const _TutorialCta();

  @override
  Widget build(BuildContext context) {
    return PitchSection(
      background: Brand.darkGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const PitchHeadline('Ready to ship?', color: Colors.white),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: const Text(
              'Create a workspace now — the first ticket is on you, '
              'the plumbing is on us.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFFB6C9BB),
                  fontSize: 16,
                  height: 1.55),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => context.go('/signin'),
            icon: const Icon(Icons.rocket_launch_outlined),
            label: const Text('Start free'),
            style: FilledButton.styleFrom(
              backgroundColor: Brand.green,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialFooter extends StatelessWidget {
  const _TutorialFooter();

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
                onPressed: () => context.go('/signin'),
                child: const Text('Product'),
              ),
              TextButton(
                onPressed: () => context.go('/investors'),
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
