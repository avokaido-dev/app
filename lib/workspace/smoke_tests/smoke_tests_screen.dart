import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'smoke_test_editor.dart';
import 'smoke_test_models.dart';
import 'smoke_test_review_dialog.dart';
import 'smoke_tests_service.dart';

/// Admin screen that lists all smoke tests for a workspace and provides
/// author / review / revoke actions.
class SmokeTestsScreen extends StatefulWidget {
  const SmokeTestsScreen({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  State<SmokeTestsScreen> createState() => _SmokeTestsScreenState();
}

class _SmokeTestsScreenState extends State<SmokeTestsScreen> {
  final _service = SmokeTestsService();
  bool _loading = true;
  String? _error;
  List<SmokeTest> _tests = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tests = await _service.list(workspaceId: widget.workspaceId);
      if (!mounted) return;
      setState(() {
        _tests = tests;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = '$err';
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({SmokeTest? existing}) async {
    final spec = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => SmokeTestEditor(initial: existing),
    );
    if (spec == null) return;
    try {
      final result = await _service.propose(
        workspaceId: widget.workspaceId,
        testId: existing?.id,
        spec: spec,
      );
      if (!mounted) return;
      final msg = result.status == 'rejected'
          ? 'Submitted. Scanner blocked (${result.scannerReport?.risk.name}). '
              'See the test for findings.'
          : 'Submitted. Version ${result.version} is pending a second '
              'admin\'s review.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _reload();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $err')));
    }
  }

  Future<void> _openReview(SmokeTest t) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final outcome = await showDialog<ReviewOutcome?>(
      context: context,
      builder: (_) => SmokeTestReviewDialog(test: t, currentUid: uid),
    );
    if (outcome == null) return;
    try {
      if (outcome.decision == ReviewDecision.approve) {
        await _service.approve(workspaceId: widget.workspaceId, testId: t.id);
      } else {
        await _service.reject(
          workspaceId: widget.workspaceId,
          testId: t.id,
          reason: outcome.reason,
        );
      }
      if (!mounted) return;
      await _reload();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${outcome.decision.name} failed: $err')),
      );
    }
  }

  Future<void> _revoke(SmokeTest t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Revoke "${t.name}"?'),
        content: const Text(
          'Desktops will stop running this test on their next refresh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.revoke(workspaceId: widget.workspaceId, testId: t.id);
      if (!mounted) return;
      await _reload();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Revoke failed: $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smoke tests'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: FilledButton.icon(
              onPressed: _loading ? null : () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('New test'),
            ),
          ),
        ],
      ),
      body: Builder(
        builder: (_) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null) {
            return Center(child: Text(_error!));
          }
          if (_tests.isEmpty) {
            return const Center(
              child: Text('No smoke tests yet. Click "New test" to author one.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _tests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _TestRow(
              test: _tests[i],
              workspaceId: widget.workspaceId,
              onReview: () => _openReview(_tests[i]),
              onEdit: () => _openEditor(existing: _tests[i]),
              onRevoke: () => _revoke(_tests[i]),
            ),
          );
        },
      ),
    );
  }
}

class _TestRow extends StatelessWidget {
  const _TestRow({
    required this.test,
    required this.workspaceId,
    required this.onReview,
    required this.onEdit,
    required this.onRevoke,
  });

  final SmokeTest test;
  final String workspaceId;
  final VoidCallback onReview;
  final VoidCallback onEdit;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            test.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusChip(status: test.status),
                          const SizedBox(width: 8),
                          _KindChip(kind: test.kind),
                        ],
                      ),
                      if (test.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            test.description,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        'Platforms: ${test.platforms.map((p) => p.name).join(", ")}  •  '
                        'Version ${test.version}  •  '
                        'Author: ${test.authorUid}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      if (test.scannerReport != null)
                        Text(
                          'Scanner: ${test.scannerReport!.risk.name}'
                          '${test.scannerReport!.findings.isEmpty ? "" : " (${test.scannerReport!.findings.length} finding${test.scannerReport!.findings.length == 1 ? "" : "s"})"}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (test.status == SmokeTestStatus.pending)
                      TextButton(
                        onPressed: onReview,
                        child: const Text('Review'),
                      ),
                    if (test.status == SmokeTestStatus.rejected ||
                        test.status == SmokeTestStatus.pending)
                      TextButton(
                        onPressed: onEdit,
                        child: const Text('Edit'),
                      ),
                    if (test.status == SmokeTestStatus.approved)
                      TextButton(
                        onPressed: onRevoke,
                        child: const Text('Revoke'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _RecentRunsStrip(
              workspaceId: workspaceId,
              testId: test.id,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final SmokeTestStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, String label) = switch (status) {
      SmokeTestStatus.pending => (Colors.amber.shade700, 'pending'),
      SmokeTestStatus.approved => (Colors.green.shade700, 'approved'),
      SmokeTestStatus.rejected => (Colors.red.shade700, 'rejected'),
      SmokeTestStatus.revoked => (Colors.grey.shade700, 'revoked'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind});
  final SmokeTestKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(kind.name, style: const TextStyle(fontSize: 11)),
    );
  }
}

/// Compact inline view of the 5 most recent runs for a test.
class _RecentRunsStrip extends StatelessWidget {
  const _RecentRunsStrip({required this.workspaceId, required this.testId});
  final String workspaceId;
  final String testId;

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('workspaces')
        .doc(workspaceId)
        .collection('smokeTestRuns')
        .where('testId', isEqualTo: testId)
        .orderBy('createdAt', descending: true)
        .limit(5);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Text(
            'No runs yet.',
            style: TextStyle(fontSize: 12, color: Colors.black45),
          );
        }
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final d in docs)
              _RunDot(status: d.data()['status']?.toString() ?? ''),
          ],
        );
      },
    );
  }
}

class _RunDot extends StatelessWidget {
  const _RunDot({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (Color color, String tip) = switch (status) {
      'passed' => (Colors.green, 'passed'),
      'failed' => (Colors.red, 'failed'),
      'errored' => (Colors.orange, 'errored'),
      'refused' => (Colors.grey, 'refused (desktop rejected)'),
      _ => (Colors.black26, status),
    };
    return Tooltip(
      message: tip,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
