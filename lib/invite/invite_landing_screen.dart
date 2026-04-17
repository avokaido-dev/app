import 'dart:async';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Public landing page linked from invite emails:
/// `https://admin.avokaido.app/invite/<token>`
///
/// Auto-attempts the `avokaido://claim?token=<token>` deep link and shows a
/// download CTA as a fallback.
class InviteLandingScreen extends StatefulWidget {
  const InviteLandingScreen({super.key, required this.token});
  final String token;

  @override
  State<InviteLandingScreen> createState() => _InviteLandingScreenState();
}

class _InviteLandingScreenState extends State<InviteLandingScreen> {
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openDeepLink());
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  void _openDeepLink() {
    final url = 'avokaido://claim?token=${Uri.encodeComponent(widget.token)}';
    web.window.location.href = url;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.download, size: 72),
                const SizedBox(height: 16),
                const Text(
                  'Opening Avokaido…',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                const Text(
                  "If the app doesn't open automatically, download it below "
                  'and click the invite link again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => web.window.location.href =
                      'https://github.com/avokaido/releases/latest',
                  icon: const Icon(Icons.download),
                  label: const Text('Download Avokaido'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _openDeepLink,
                  child: const Text('Try opening the app again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
