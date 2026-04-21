import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../marketing/pitch_sections.dart';

/// Public investor pitch at `/investors`. Tells the full deck story with
/// market, roadmap, ownership and contact sections in addition to the
/// shared product narrative.
class InvestorsScreen extends StatelessWidget {
  const InvestorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            _InvestorTopBar(),
            _InvestorHero(),
            PitchProblem(),
            PitchProcessComparison(),
            PitchBuildersBridge(),
            PitchSolution(),
            PitchSegments(),
            PitchPricing(),
            PitchMarket(),
            PitchRoadmap(),
            PitchContact(),
            _InvestorFooter(),
          ],
        ),
      ),
    );
  }
}

class _InvestorTopBar extends StatelessWidget {
  const _InvestorTopBar();

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
            onPressed: () => context.go('/tutorial'),
            style: TextButton.styleFrom(
              foregroundColor: Brand.darkGreen,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Tutorial'),
          ),
          TextButton(
            onPressed: () => context.go('/signin'),
            style: TextButton.styleFrom(
              foregroundColor: Brand.darkGreen,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Back to product'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.go('/signin'),
            style: FilledButton.styleFrom(
              backgroundColor: Brand.green,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

class _InvestorHero extends StatelessWidget {
  const _InvestorHero();

  @override
  Widget build(BuildContext context) {
    return PitchSection(
      verticalPadding: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PitchEyebrow('Investor pitch'),
          const SizedBox(height: 16),
          const PitchHeadline(
            'Avokaido — consumer speed,\nenterprise control.',
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: const PitchSubhead(
              'Consumer AI builders ship in minutes; enterprises ship in '
              'months. Avokaido closes the gap — the AI development '
              'platform with the security, compliance, and quality '
              'gates companies actually need.',
              fontSize: 17.0,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _HeroPill('Seed round open'),
              _HeroPill('Founder-led'),
              _HeroPill('2% on tokens used — no seat fees'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Brand.green.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Brand.green.withAlpha(60)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Brand.darkGreen,
        ),
      ),
    );
  }
}

class _InvestorFooter extends StatelessWidget {
  const _InvestorFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          Text(
            '© ${DateTime.now().year} Avokaido — Investor pitch. '
            'Forward-looking statements; not a prospectus.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
