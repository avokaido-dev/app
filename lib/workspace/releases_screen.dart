import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../auth/auth_service.dart';

/// Admin view: what desktop versions are available, and what each team
/// member is actually running.
///
/// Installations are written by the desktop app on launch (see the
/// `desktop-heartbeat` Linear ticket) into
/// `workspaces/{wsId}/installations/{uid}` with shape:
///   { userId, email, platform, appVersion, lastSeen (ms), os, hostname? }
class ReleasesScreen extends StatelessWidget {
  const ReleasesScreen({super.key, required this.auth});
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
          const Text(
            'Desktop versions',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'What the team is running and what is available to ship.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          const _AvailableReleases(),
          const SizedBox(height: 32),
          _Installations(workspaceId: wsId),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Available releases
// ---------------------------------------------------------------------------

class _AvailableReleases extends StatelessWidget {
  const _AvailableReleases();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('releases').snapshots(),
      builder: (context, snap) {
        return _Section(
          title: 'Available releases',
          subtitle: 'Latest build published per platform.',
          child: _buildBody(snap),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap) {
    if (snap.hasError) {
      return Text(
        'Failed to load releases: ${snap.error}',
        style: const TextStyle(color: Colors.red),
      );
    }
    if (!snap.hasData) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: CircularProgressIndicator(),
      );
    }
    final docs = snap.data!.docs;
    if (docs.isEmpty) {
      return const Text(
        'No releases published yet.',
        style: TextStyle(color: Colors.black54),
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final d in docs)
          _ReleaseCard(
            platform: d.id,
            version: d.data()['version'] as String? ?? '',
            releasedAt: (d.data()['releasedAt'] as num?)?.toInt(),
            notes: d.data()['notes'] as String?,
            downloadUrl: d.data()['downloadUrl'] as String? ?? '',
          ),
      ],
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({
    required this.platform,
    required this.version,
    required this.releasedAt,
    required this.notes,
    required this.downloadUrl,
  });

  final String platform;
  final String version;
  final int? releasedAt;
  final String? notes;
  final String downloadUrl;

  String get _label => switch (platform) {
    'macos' => 'macOS',
    'linux' => 'Linux',
    'windows' => 'Windows',
    'web' => 'Web',
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
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icon, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    _label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                version.isEmpty ? '—' : 'v$version',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (releasedAt != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Released ${_formatDate(releasedAt!)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              if (notes != null && notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  notes!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: downloadUrl.isEmpty
                    ? null
                    : () => web.window.location.href = downloadUrl,
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

// ---------------------------------------------------------------------------
// Installations (per-user)
// ---------------------------------------------------------------------------

class _Installations extends StatelessWidget {
  const _Installations({required this.workspaceId});
  final String workspaceId;

  @override
  Widget build(BuildContext context) {
    final installations = FirebaseFirestore.instance
        .collection('workspaces')
        .doc(workspaceId)
        .collection('installations')
        .orderBy('lastSeen', descending: true)
        .snapshots();

    final releases = FirebaseFirestore.instance
        .collection('releases')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: releases,
      builder: (context, releasesSnap) {
        final latestByPlatform = <String, String>{
          for (final d in (releasesSnap.data?.docs ?? []))
            d.id: (d.data()['version'] as String?) ?? '',
        };
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: installations,
          builder: (context, snap) {
            return _Section(
              title: 'Team installations',
              subtitle:
                  'Each member\'s most recent desktop app check-in. Populated '
                  'by the desktop app on launch.',
              child: _buildBody(snap, latestByPlatform),
            );
          },
        );
      },
    );
  }

  Widget _buildBody(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap,
    Map<String, String> latestByPlatform,
  ) {
    if (snap.hasError) {
      return Text(
        'Failed to load installations: ${snap.error}',
        style: const TextStyle(color: Colors.red),
      );
    }
    if (!snap.hasData) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: CircularProgressIndicator(),
      );
    }
    final docs = snap.data!.docs;
    if (docs.isEmpty) {
      return const _EmptyInstallations();
    }

    return Card(
      child: Column(
        children: [
          for (var i = 0; i < docs.length; i++) ...[
            _InstallationRow(
              data: docs[i].data(),
              latestForPlatform:
                  latestByPlatform[docs[i].data()['platform'] as String? ?? ''],
            ),
            if (i < docs.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _InstallationRow extends StatelessWidget {
  const _InstallationRow({required this.data, required this.latestForPlatform});
  final Map<String, dynamic> data;
  final String? latestForPlatform;

  @override
  Widget build(BuildContext context) {
    final email = data['email'] as String? ?? data['userId'] as String? ?? '—';
    final platform = data['platform'] as String? ?? '';
    final version = data['appVersion'] as String? ?? '';
    final lastSeen = (data['lastSeen'] as num?)?.toInt();
    final outdated =
        latestForPlatform != null &&
        latestForPlatform!.isNotEmpty &&
        version.isNotEmpty &&
        version != latestForPlatform;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(_platformIcon(platform), size: 20, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _platformLabel(platform),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Text(
                  version.isEmpty ? '—' : 'v$version',
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                if (outdated)
                  Tooltip(
                    message:
                        'Latest v$latestForPlatform is available for this platform.',
                    child: const Chip(
                      label: Text('Outdated', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Color(0xFFFFF3E0),
                      side: BorderSide(color: Color(0xFFFFB74D)),
                    ),
                  )
                else if (version.isNotEmpty && latestForPlatform != null)
                  const Chip(
                    label: Text('Up to date', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Color(0xFFE8F5E9),
                    side: BorderSide(color: Color(0xFF81C784)),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              lastSeen == null ? '—' : _formatRelative(lastSeen),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  IconData _platformIcon(String p) => switch (p) {
    'macos' => Icons.laptop_mac,
    'linux' => Icons.computer,
    'windows' => Icons.window,
    _ => Icons.devices_other,
  };

  String _platformLabel(String p) => switch (p) {
    'macos' => 'macOS',
    'linux' => 'Linux',
    'windows' => 'Windows',
    '' => 'Unknown platform',
    _ => p,
  };
}

class _EmptyInstallations extends StatelessWidget {
  const _EmptyInstallations();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: const Row(
        children: [
          Icon(Icons.devices_other, color: Colors.black45),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No desktop installations have checked in yet. '
              'Once team members launch the desktop app, their version and '
              'platform show up here.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12.5, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

String _formatDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
  return '${d.year}-${_two(d.month)}-${_two(d.day)}';
}

String _two(int n) => n.toString().padLeft(2, '0');

String _formatRelative(int ms) {
  final now = DateTime.now();
  final then = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
  final diff = now.difference(then);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return _formatDate(ms);
}
