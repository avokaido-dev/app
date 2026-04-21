import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../auth/auth_service.dart';

/// Landing screen for regular (non-admin) org members. Their only job on the
/// web app is to grab the right desktop build for their platform.
class DownloadScreen extends StatelessWidget {
  const DownloadScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    final wsId = auth.workspaceId;
    if (wsId == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WorkspaceHeader(workspaceId: wsId),
          const SizedBox(height: 24),
          const Text(
            'Get the desktop app',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pick the build for your platform. Sign in with the same account '
            'you used here and the app joins this workspace automatically.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          const _PlatformDownloads(),
        ],
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.workspaceId});
  final String workspaceId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('workspaces')
          .doc(workspaceId)
          .snapshots(),
      builder: (context, snap) {
        final name = snap.data?.data()?['name'] as String? ?? workspaceId;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.workspaces_outlined, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'You are a member of',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlatformDownloads extends StatelessWidget {
  const _PlatformDownloads();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('releases').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Text(
            'No releases available yet. Check back shortly.',
            style: TextStyle(color: Colors.black54),
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final d in docs)
              _PlatformDownloadCard(
                platform: d.id,
                version: d.data()['version'] as String? ?? '',
                url: d.data()['downloadUrl'] as String? ?? '',
              ),
          ],
        );
      },
    );
  }
}

class _PlatformDownloadCard extends StatelessWidget {
  const _PlatformDownloadCard({
    required this.platform,
    required this.version,
    required this.url,
  });

  final String platform;
  final String version;
  final String url;

  String get _label => switch (platform) {
    'macos' => 'macOS',
    'linux' => 'Linux',
    'windows' => 'Windows',
    'web' => 'Web (zip)',
    _ => platform,
  };

  IconData get _icon => switch (platform) {
    'macos' => Icons.laptop_mac,
    'linux' => Icons.computer,
    'windows' => Icons.window,
    'web' => Icons.language,
    _ => Icons.download,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon, size: 28),
              const SizedBox(height: 8),
              Text(_label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                'v$version',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: url.isEmpty
                    ? null
                    : () => web.window.location.href = url,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Download'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
