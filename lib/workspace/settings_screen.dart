import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

/// Workspace settings. v1: just the workspace display name. Only editable
/// by the org admin; regular members see it read-only.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final wsId = widget.auth.workspaceId;
    if (wsId == null) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      await FirebaseFirestore.instance
          .collection('workspaces')
          .doc(wsId)
          .set({'name': name, 'updatedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
      _notice = 'Saved.';
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wsId = widget.auth.workspaceId;
    if (wsId == null) return const SizedBox.shrink();
    final canEdit = widget.auth.isOrgAdmin;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('workspaces')
            .doc(wsId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data() ?? const {};
          if (!_loaded) {
            _nameController.text = data['name'] as String? ?? '';
            _loaded = true;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Workspace name',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        enabled: canEdit,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!canEdit)
                        const Text(
                          'Only the org admin can change workspace settings.',
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ],
                      if (_notice != null) ...[
                        const SizedBox(height: 8),
                        Text(_notice!,
                            style: const TextStyle(color: Colors.green)),
                      ],
                      if (canEdit) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Save'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
