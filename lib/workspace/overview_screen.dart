import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import '../auth/auth_service.dart';

/// Workspace overview — shows name, created date, and desktop app download
/// links pulled from `releases/{platform}`.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    final wsId = auth.workspaceId;
    if (wsId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('workspaces')
                .doc(wsId)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                );
              }
              final data = snap.data!.data() ?? const {};
              final name = data['name'] as String? ?? wsId;
              final createdAtMs = (data['createdAt'] as num?)?.toInt();
              final created = createdAtMs == null
                  ? ''
                  : DateTime.fromMillisecondsSinceEpoch(createdAtMs)
                      .toLocal()
                      .toIso8601String()
                      .split('T')
                      .first;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            wsId,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Copy workspace ID',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: wsId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Workspace ID copied'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      if (created.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Created $created',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                      if (auth.isOrgAdmin) ...[
                        const SizedBox(height: 12),
                        const Chip(
                          label: Text('You are the org admin'),
                          avatar: Icon(Icons.shield_outlined, size: 16),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Download the desktop app',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const _DesktopDownloads(),
        ],
      ),
    );
  }
}

class _DesktopDownloads extends StatelessWidget {
  const _DesktopDownloads();

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
          return const Text('No releases available yet.',
              style: TextStyle(color: Colors.black54));
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
              Text(_label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('v$version',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
