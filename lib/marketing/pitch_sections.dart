import 'package:flutter/material.dart';

/// Shared narrative sections used across the public landing page and the
/// investors page. Keep copy close to the pitch deck so the story stays
/// consistent between public marketing and investor materials.

class Brand {
  static const green = Color(0xFF2F6B3B);
  static const darkGreen = Color(0xFF0E2812);
  static const bg = Color(0xFFF2F5EF);
  static const cream = Color(0xFFF6EFE2);
  static const accent = Color(0xFFE8956A);
  static const gold = Color(0xFFD4A53A);
}

// ---------------------------------------------------------------------------
// Section scaffold: centered, capped width, consistent padding.
// ---------------------------------------------------------------------------

class PitchSection extends StatelessWidget {
  const PitchSection({
    super.key,
    required this.child,
    this.background,
    this.maxWidth = 1100,
    this.verticalPadding = 80,
  });

  final Widget child;
  final Color? background;
  final double maxWidth;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      padding: EdgeInsets.symmetric(
          horizontal: 32, vertical: verticalPadding.toDouble()),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

class PitchEyebrow extends StatelessWidget {
  const PitchEyebrow(this.text, {super.key, this.color = Brand.darkGreen});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class PitchHeadline extends StatelessWidget {
  const PitchHeadline(this.text, {super.key, this.color = Brand.darkGreen});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        height: 1.1,
        color: color,
      ),
    );
  }
}

class PitchSubhead extends StatelessWidget {
  const PitchSubhead(this.text,
      {super.key, this.color = Colors.black87, this.fontSize = 16.0});
  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: fontSize, height: 1.55, color: color),
    );
  }
}

// ---------------------------------------------------------------------------
// Problem: three cards explaining why enterprises are locked out.
// ---------------------------------------------------------------------------

class PitchProblem extends StatelessWidget {
  const PitchProblem({super.key});

  @override
  Widget build(BuildContext context) {
    return PitchSection(
      background: Brand.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PitchEyebrow('The Problem'),
          const SizedBox(height: 16),
          const PitchHeadline(
            'Enterprises are locked out of the\nAI development revolution.',
          ),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 820;
              final cards = [
                _ProblemCard(
                  icon: Icons.shield_outlined,
                  title: 'Security gaps',
                  body:
                      'Consumer AI tools like Lovable and v0 lack enterprise '
                      'security, compliance, and data governance.',
                ),
                _ProblemCard(
                  icon: Icons.settings_applications_outlined,
                  title: 'No control',
                  body:
                      "Orgs can't enforce coding standards, integrate private "
                      'APIs, or meet regulatory requirements.',
                ),
                _ProblemCard(
                  icon: Icons.insights_outlined,
                  title: 'No customer focus',
                  body:
                      'Existing tools treat enterprises like self-serve users '
                      '— no onboarding, no success team, no partnership.',
                ),
              ];
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final c in cards) ...[
                          Expanded(child: c),
                          if (c != cards.last) const SizedBox(width: 20),
                        ],
                      ],
                    )
                  : Column(children: [
                      for (final c in cards) ...[
                        c,
                        if (c != cards.last) const SizedBox(height: 20),
                      ],
                    ]);
            },
          ),
        ],
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard({
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
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Brand.accent, width: 4),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Brand.green.withAlpha(28),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Brand.green, size: 22),
          ),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Brand.darkGreen)),
          const SizedBox(height: 8),
          Text(body,
              style: const TextStyle(fontSize: 14.5, height: 1.55)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Process comparison: today's 6-step handoff chain and the Avokaido version.
// ---------------------------------------------------------------------------

class _Step {
  const _Step(this.n, this.title, this.body, this.tag, this.kept);
  final int n;
  final String title;
  final String body;
  final String tag;
  final bool kept;
}

const _processSteps = <_Step>[
  _Step(1, 'Business', 'Identifies\nthe need', 'KEEPS', true),
  _Step(2, 'Requirements', 'Documents &\nspecifies', 'AUTOMATED', false),
  _Step(3, 'Product Owner', 'Prioritizes\nin backlog', 'AUTOMATED', false),
  _Step(4, 'Dev Team', 'Builds the\nsolution', 'AI BUILDS', false),
  _Step(5, 'QA & Test', 'Tests\nquality', 'AUTO / ENG', false),
  _Step(6, 'Deployment', 'Deploys to\nproduction', 'AUTOMATED', true),
];

class PitchProcessToday extends StatelessWidget {
  const PitchProcessToday({super.key});

  @override
  Widget build(BuildContext context) {
    return PitchSection(
      background: const Color(0xFFE9EEF0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PitchHeadline('How does the process look today?',
              color: Brand.darkGreen),
          const SizedBox(height: 8),
          const PitchSubhead(
            'The traditional path from business need to technical delivery.',
            color: Colors.black54,
          ),
          const SizedBox(height: 32),
          _ProcessChain(greyed: false, highlightKept: false),
          const SizedBox(height: 28),
          _CalloutBar(
            color: Brand.gold,
            text:
                'Many handoffs = long lead times, high costs, and information loss.',
          ),
        ],
      ),
    );
  }
}

class PitchProcessWithAvokaido extends StatelessWidget {
  const PitchProcessWithAvokaido({super.key});

  @override
  Widget build(BuildContext context) {
    return PitchSection(
      background: const Color(0xFFE9EEF0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PitchHeadline('What Avokaido eliminates.',
              color: Brand.darkGreen),
          const SizedBox(height: 8),
          const PitchSubhead(
            'Same six steps — but look at what disappears.',
            color: Colors.black54,
          ),
          const SizedBox(height: 32),
          _ProcessChain(greyed: true, highlightKept: true),
          const SizedBox(height: 28),
          _CalloutBar(
            color: Brand.gold,
            text:
                '4 of 6 steps automated  •  Business stays in control  •  Engineers configure quality gates.',
          ),
        ],
      ),
    );
  }
}

class _ProcessChain extends StatelessWidget {
  const _ProcessChain({required this.greyed, required this.highlightKept});
  final bool greyed;
  final bool highlightKept;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 900;
        final tiles = [
          for (final s in _processSteps)
            _StepTile(
                step: s,
                greyed: greyed && !s.kept,
                showTag: greyed,
                highlightKept: highlightKept && s.kept),
        ];
        if (!wide) {
          return Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                tiles[i],
                if (i < tiles.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              Expanded(child: tiles[i]),
              if (i < tiles.length - 1)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Icon(Icons.arrow_forward,
                      size: 18, color: Colors.black45),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.greyed,
    required this.showTag,
    required this.highlightKept,
  });

  final _Step step;
  final bool greyed;
  final bool showTag;
  final bool highlightKept;

  @override
  Widget build(BuildContext context) {
    final circleColor =
        greyed ? Colors.black26 : (highlightKept ? Brand.green : Brand.green);
    final topBar = greyed ? Brand.accent : Brand.green;
    final tagColor = step.tag == 'KEEPS' || step.tag == 'AUTOMATED' && step.kept
        ? Brand.green
        : Brand.accent;
    final titleColor = greyed ? Colors.black45 : Brand.darkGreen;
    final bodyColor = greyed ? Colors.black38 : Colors.black87;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(top: BorderSide(color: topBar, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: circleColor, shape: BoxShape.circle),
            child: Text('${step.n}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
          const SizedBox(height: 10),
          Text(step.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: titleColor)),
          const SizedBox(height: 4),
          Text(step.body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: bodyColor, height: 1.3)),
          if (showTag) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: tagColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                step.tag,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalloutBar extends StatelessWidget {
  const _CalloutBar({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Brand.darkGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w700, fontSize: 14.5),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lovable bridge — positioning as the enterprise-ready operator on top of
// consumer AI builders.
// ---------------------------------------------------------------------------

class PitchLovableBridge extends StatelessWidget {
  const PitchLovableBridge({super.key});

  @override
  Widget build(BuildContext context) {
    return PitchSection(
      background: Brand.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PitchEyebrow('Build with Lovable, operate with Avokaido'),
          const SizedBox(height: 16),
          const PitchHeadline(
              "We don't replace Lovable.\nWe make it enterprise-ready."),
          const SizedBox(height: 32),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 900;
            final cards = [
              _BridgeCard(
                number: '1',
                numberColor: Brand.accent,
                title: 'Build in Lovable',
                body:
                    'Users prototype with Lovable\'s AI builder. Natural '
                    'language to working code, fast.',
                footer: 'Exports code to GitHub →',
              ),
              _BridgeCard(
                number: '2',
                numberColor: Brand.darkGreen,
                title: 'GitHub repository',
                body:
                    'Code lives in a standard GitHub repo. Full version '
                    'control, branch history, transparency.',
                footer: 'Avokaido connects here →',
              ),
              _BridgeCard(
                number: '3',
                numberColor: Brand.green,
                title: 'Avokaido operates',
                body: '• Reads & analyses the codebase\n'
                    '• Sets coding standards & rules\n'
                    '• Runs quality & regression tests\n'
                    '• Manages UAT & staging\n'
                    '• Controls deployment gates\n'
                    '• Full audit trail & governance',
              ),
            ];
            if (!wide) {
              return Column(children: [
                for (final c in cards) ...[
                  c,
                  if (c != cards.last) const SizedBox(height: 16),
                ],
              ]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  Expanded(child: cards[i]),
                  if (i < cards.length - 1)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Icon(Icons.arrow_forward, color: Brand.green),
                    ),
                ],
              ],
            );
          }),
          const SizedBox(height: 24),
          _CalloutBar(
            color: const Color(0xFF9BD3A6),
            text:
                'Lovable for speed.  Avokaido for control.  GitHub as the bridge.',
          ),
        ],
      ),
    );
  }
}

class _BridgeCard extends StatelessWidget {
  const _BridgeCard({
    required this.number,
    required this.numberColor,
    required this.title,
    required this.body,
    this.footer,
  });

  final String number;
  final Color numberColor;
  final String title;
  final String body;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: numberColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: numberColor, shape: BoxShape.circle),
                child: Text(number,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Brand.darkGreen)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(fontSize: 14, height: 1.5)),
          if (footer != null) ...[
            const SizedBox(height: 12),
            Text(footer!,
                style: TextStyle(
                    color: numberColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Solution pillars: 4 value props.
// ---------------------------------------------------------------------------

class PitchSolution extends StatelessWidget {
  const PitchSolution({super.key});

  @override
  Widget build(BuildContext context) {
    return PitchSection(
      background: Brand.darkGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PitchEyebrow('The solution', color: Brand.green),
          const SizedBox(height: 16),
          const PitchHeadline(
            'Lovable, but built for enterprise.',
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          const PitchSubhead(
            'An AI-powered development platform that combines the speed of '
            'consumer tools with the security, support, and long-term '
            'partnership enterprises expect.',
            color: Color(0xFFB6C9BB),
          ),
          const SizedBox(height: 40),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 820;
            final cards = [
              _Pillar(Icons.rocket_launch_outlined, 'AI app builder',
                  'Natural language to production-ready code with enterprise frameworks and patterns.'),
              _Pillar(Icons.verified_user_outlined, 'Compliance first',
                  'Built-in GDPR, SOC 2, ISO 27001 templates and audit logging.'),
              _Pillar(Icons.handshake_outlined, 'Customer success',
                  'Dedicated onboarding, hands-on support, and long-term success partnerships — not just a self-serve tool.'),
              _Pillar(Icons.lock_outline, 'Private & secure',
                  'Self-hosted option, SSO/SAML, encrypted at rest, no training on your code.'),
            ];
            if (!wide) {
              return Column(children: [
                for (final c in cards) ...[
                  c,
                  if (c != cards.last) const SizedBox(height: 20),
                ],
              ]);
            }
            return GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 3.2,
              children: cards,
            );
          }),
        ],
      ),
    );
  }
}

class _Pillar extends StatelessWidget {
  const _Pillar(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Brand.green.withAlpha(60), shape: BoxShape.circle),
          child: Icon(icon, color: const Color(0xFF9BD3A6), size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text(body,
                  style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFFC5D4C9))),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Customer segments.
// ---------------------------------------------------------------------------

class PitchSegments extends StatelessWidget {
  const PitchSegments({super.key});

  @override
  Widget build(BuildContext context) {
    return PitchSection(
      background: Brand.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PitchEyebrow('Our customers'),
          const SizedBox(height: 16),
          const PitchHeadline('Three customer segments.'),
          const SizedBox(height: 32),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 820;
            final cards = [
              _SegmentCard(
                color: const Color(0xFF6EB47F),
                icon: Icons.person_outline,
                title: 'Solo builders',
                subtitle: 'Single-person businesses',
                bullets: const [
                  'Freelancers & consultants building their own tools',
                  'Enterprise-grade quality without a dev team',
                  'From idea to production-ready app, with guardrails',
                ],
              ),
              _SegmentCard(
                color: Brand.gold,
                icon: Icons.apartment_outlined,
                title: 'SME to enterprise',
                subtitle: 'Company applications',
                bullets: const [
                  'Internal tools, workflows, and customer-facing apps',
                  'IT sets quality gates, business users do UAT',
                  'Compliance, testing and deployment standards built in',
                ],
              ),
              _SegmentCard(
                color: Brand.accent,
                icon: Icons.favorite_border,
                title: 'Lovable graduates',
                subtitle: 'Apps built in Lovable',
                bullets: const [
                  'Export from Lovable → import into Avokaido',
                  'Add quality control, testing and governance',
                  'Bridge the gap from prototype to production',
                ],
              ),
            ];
            if (!wide) {
              return Column(children: [
                for (final c in cards) ...[
                  c,
                  if (c != cards.last) const SizedBox(height: 20),
                ]
              ]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in cards) ...[
                  Expanded(child: c),
                  if (c != cards.last) const SizedBox(width: 20),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _SegmentCard extends StatelessWidget {
  const _SegmentCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bullets,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Brand.darkGreen)),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ),
          const SizedBox(height: 16),
          for (final b in bullets) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: Brand.green)),
                Expanded(
                  child: Text(b,
                      style: const TextStyle(fontSize: 13.5, height: 1.5)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pricing: 2% on tokens used.
// ---------------------------------------------------------------------------

class PitchPricing extends StatelessWidget {
  const PitchPricing({super.key});

  @override
  Widget build(BuildContext context) {
    return PitchSection(
      background: Brand.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const PitchEyebrow('Pricing'),
          const SizedBox(height: 16),
          const PitchHeadline('2% on tokens used. That\'s it.'),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: const PitchSubhead(
              'No seat licences, no usage tiers, no hidden platform fees. You '
              'bring your own AI provider keys; we add 2% on top of what you '
              'spend with Claude, GPT and Gemini. Pricing scales with the value '
              'we help you ship — nothing else.',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              _PriceFact(Icons.key_outlined, 'Bring your own keys',
                  'Claude, OpenAI, Gemini — billed directly by the provider.'),
              _PriceFact(Icons.percent, '2% markup',
                  'Added transparently on top of token spend.'),
              _PriceFact(Icons.toggle_off_outlined, 'No seats, no tiers',
                  'Invite your whole team. Pricing never gets in the way.'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceFact extends StatelessWidget {
  const _PriceFact(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withAlpha(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Brand.green),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Brand.darkGreen)),
            const SizedBox(height: 6),
            Text(body,
                style: const TextStyle(fontSize: 13.5, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Market opportunity (investor-only).
// ---------------------------------------------------------------------------

class PitchMarket extends StatelessWidget {
  const PitchMarket({super.key});

  @override
  Widget build(BuildContext context) {
    return PitchSection(
      background: Brand.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PitchEyebrow('Market opportunity'),
          const SizedBox(height: 16),
          const PitchHeadline('A massive and growing market.'),
          const SizedBox(height: 32),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 760;
            final cards = [
              _MarketStat('\$155B', 'AI software market by 2030',
                  'Source: Grand View Research'),
              _MarketStat('59%', 'of enterprises plan AI dev adoption',
                  'Source: Gartner 2025'),
              _MarketStat('10×', 'productivity gain with AI coding tools',
                  'Reputation / unverified predictions'),
            ];
            if (!wide) {
              return Column(children: [
                for (final c in cards) ...[
                  c,
                  if (c != cards.last) const SizedBox(height: 16),
                ],
              ]);
            }
            return Row(
              children: [
                for (final c in cards) ...[
                  Expanded(child: c),
                  if (c != cards.last) const SizedBox(width: 20),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _MarketStat extends StatelessWidget {
  const _MarketStat(this.headline, this.label, this.source);
  final String headline;
  final String label;
  final String source;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(headline,
              style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Brand.green)),
          const SizedBox(height: 12),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Text(source,
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black45,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Roadmap (investor-only).
// ---------------------------------------------------------------------------

class PitchRoadmap extends StatelessWidget {
  const PitchRoadmap({super.key});

  @override
  Widget build(BuildContext context) {
    return PitchSection(
      background: Brand.cream,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PitchEyebrow('Roadmap & milestones'),
          const SizedBox(height: 16),
          const PitchHeadline("What we'll deliver with your investment."),
          const SizedBox(height: 32),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 820;
            final cards = [
              _RoadmapCard(Brand.green, 'Q2 2026', 'Demo clients',
                  'Early testing with select enterprise partners, feedback loops, core validation.'),
              _RoadmapCard(Brand.darkGreen, 'Q3 2026', 'MVP launch',
                  'Public AI app builder, templates, onboarding flows.'),
              _RoadmapCard(Brand.gold, 'Q4 2026', 'Team & compliance',
                  'SSO, role-based access, GDPR & SOC 2 templates, audit logging.'),
              _RoadmapCard(Brand.accent, 'Q1 2027', 'Enterprise GA',
                  'Self-hosted option, custom integrations, partner program.'),
            ];
            if (!wide) {
              return Column(children: [
                for (final c in cards) ...[
                  c,
                  if (c != cards.last) const SizedBox(height: 16),
                ],
              ]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in cards) ...[
                  Expanded(child: c),
                  if (c != cards.last) const SizedBox(width: 16),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard(this.color, this.quarter, this.title, this.body);
  final Color color;
  final String quarter;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quarter,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.8)),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Brand.darkGreen)),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(fontSize: 13.5, height: 1.5)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ownership (investor-only).
// ---------------------------------------------------------------------------

class PitchOwnership extends StatelessWidget {
  const PitchOwnership({super.key});

  @override
  Widget build(BuildContext context) {
    return PitchSection(
      background: Brand.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PitchEyebrow('Ownership structure'),
          const SizedBox(height: 16),
          const PitchHeadline('Aligned incentives, shared upside.'),
          const SizedBox(height: 32),
          _OwnerRow(Brand.green, '30%', 'Johannes Skagius', 'CEO & co-founder'),
          const SizedBox(height: 16),
          _OwnerRow(Brand.gold, '30%', 'Kasper Berg', 'CTO & co-founder'),
          const SizedBox(height: 16),
          _OwnerRow(const Color(0xFF6EB47F), '40%', 'Investors',
              'Seed round allocation'),
          const SizedBox(height: 24),
          const Text(
            'Founders retain 60% combined equity, ensuring long-term '
            'commitment. Investor-friendly 40% allocation with standard '
            'protections and pro-rata rights.',
            style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.black54,
                fontSize: 13,
                height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _OwnerRow extends StatelessWidget {
  const _OwnerRow(this.color, this.pct, this.name, this.role);
  final Color color;
  final String pct;
  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 20),
        SizedBox(
          width: 90,
          child: Text(pct,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Brand.darkGreen)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Brand.darkGreen)),
              Text(role,
                  style: const TextStyle(
                      fontSize: 13.5, color: Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Contact (investor-only).
// ---------------------------------------------------------------------------

class PitchContact extends StatelessWidget {
  const PitchContact({super.key});

  @override
  Widget build(BuildContext context) {
    return PitchSection(
      background: Brand.darkGreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PitchHeadline(
            "We're looking for a partner,\nnot just an investor.",
            color: Colors.white,
          ),
          const SizedBox(height: 20),
          const PitchSubhead(
            'Avokaido is built on the belief that enterprise tools should be '
            'accessible to every team — and that lasting businesses are built '
            'on real customer relationships, not just code.',
            color: Color(0xFFB6C9BB),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Brand.green.withAlpha(60),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ContactRow('Johannes Skagius',
                    'johannes.skagius@avokaido.com'),
                SizedBox(height: 12),
                _ContactRow('Kasper Berg', 'kasper.berg@avokaido.com'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow(this.name, this.email);
  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(height: 2),
        SelectableText(email,
            style: const TextStyle(
                fontSize: 14, color: Color(0xFFC5D4C9))),
      ],
    );
  }
}
