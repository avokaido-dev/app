import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_service.dart';

/// Invite + list + remove members of the current workspace.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _emailController = TextEditingController();
  bool _sending = false;
  String? _error;
  String? _lastLandingUrl;
  List<_Member> _members = const [];
  bool _loadingMembers = true;

  @override
  void initState() {
    super.initState();
    _refreshMembers();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _refreshMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('listWorkspaceMembers')
          .call<Map<String, dynamic>>();
      final raw = (result.data['members'] as List?) ?? const [];
      _members = raw
          .map((m) => _Member.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList();
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? e.code;
    } finally {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _invite() async {
    final email = _emailController.text.trim();
    final wsId = widget.auth.workspaceId;
    if (email.isEmpty || wsId == null) return;
    setState(() {
      _sending = true;
      _error = null;
      _lastLandingUrl = null;
    });
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('sendInvite')
          .call<Map<String, dynamic>>({'email': email, 'workspaceId': wsId});
      setState(() {
        _lastLandingUrl = result.data['landingUrl'] as String?;
        _emailController.clear();
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _remove(_Member m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from workspace?'),
        content: Text(
          '${m.email ?? m.uid} will lose access to this workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFunctions.instance
          .httpsCallable('removeWorkspaceMember')
          .call<Map<String, dynamic>>({'uid': m.uid});
      await _refreshMembers();
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? e.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = widget.auth.isOrgAdmin;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Team',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (canManage) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Invite a teammate',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'They receive a link to join this workspace. Links '
                      'are single-use and valid for 7 days.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            onSubmitted: (_) => _invite(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _sending ? null : _invite,
                          child: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Send invite'),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    if (_lastLandingUrl != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Invite created — share this link:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            SelectableText(_lastLandingUrl!),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: _lastLandingUrl!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Link copied'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy link'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Row(
            children: [
              const Text(
                'Members',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Text('${_members.length}',
                  style: const TextStyle(color: Colors.black54)),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loadingMembers ? null : _refreshMembers,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loadingMembers
                ? const Center(child: CircularProgressIndicator())
                : _members.isEmpty
                    ? const Center(child: Text('Just you so far.'))
                    : ListView.separated(
                        itemCount: _members.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final m = _members[i];
                          final isSelf = m.uid == widget.auth.user?.uid;
                          return ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                m.workspaceRole == 'admin'
                                    ? Icons.shield_outlined
                                    : Icons.person_outline,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(m.email ?? m.uid),
                                if (isSelf) ...[
                                  const SizedBox(width: 8),
                                  const Chip(
                                    label: Text('You',
                                        style: TextStyle(fontSize: 11)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                                if (m.workspaceRole == 'admin') ...[
                                  const SizedBox(width: 8),
                                  const Chip(
                                    label: Text('Org admin',
                                        style: TextStyle(fontSize: 11)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ],
                            ),
                            subtitle: m.joinedAt == null
                                ? null
                                : Text('Joined ${m.joinedAtFormatted()}'),
                            trailing: (canManage && !isSelf)
                                ? IconButton(
                                    tooltip: 'Remove',
                                    onPressed: () => _remove(m),
                                    icon: const Icon(Icons.person_remove,
                                        color: Colors.red),
                                  )
                                : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _Member {
  const _Member({
    required this.uid,
    this.email,
    this.workspaceRole = 'member',
    this.joinedAt,
  });

  final String uid;
  final String? email;
  final String workspaceRole;
  final int? joinedAt;

  factory _Member.fromJson(Map<String, dynamic> json) => _Member(
        uid: json['uid'] as String,
        email: json['email'] as String?,
        workspaceRole: (json['workspaceRole'] as String?) ?? 'member',
        joinedAt: (json['joinedAt'] as num?)?.toInt(),
      );

  String joinedAtFormatted() {
    if (joinedAt == null) return '';
    return DateTime.fromMillisecondsSinceEpoch(joinedAt!)
        .toLocal()
        .toIso8601String()
        .split('T')
        .first;
  }
}
