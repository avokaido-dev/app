import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

/// Workspace settings — what an org admin can control:
/// - Workspace display name
/// - AI provider API keys (Anthropic, OpenAI, Gemini) with optional lock
///
/// Non-admin members see everything read-only.
///
/// The keys written here flow to every team member's desktop app via
/// `workspaces/{id}.settings.aiProviderKeys` — the dev platform reads
/// that doc in `WorkspaceSettingsService` and, when locked, overrides
/// the user's local key.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _providers = <({String id, String label})>[
    (id: 'anthropic', label: 'Anthropic (Claude)'),
    (id: 'openai', label: 'OpenAI (GPT)'),
    (id: 'gemini', label: 'Google (Gemini)'),
  ];

  final _nameController = TextEditingController();
  final Map<String, TextEditingController> _keyControllers = {
    for (final p in _providers) p.id: TextEditingController(),
  };
  final Map<String, bool> _locked = {for (final p in _providers) p.id: false};

  bool _loaded = false;
  bool _savingName = false;
  bool _savingKeys = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _keyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncFromDoc(Map<String, dynamic> data) {
    _nameController.text = data['name'] as String? ?? '';
    final settings =
        (data['settings'] as Map?)?.cast<String, Object?>() ?? const {};
    final keys = (settings['aiProviderKeys'] as Map?)?.cast<String, Object?>() ??
        const {};
    for (final p in _providers) {
      final entry = (keys[p.id] as Map?)?.cast<String, Object?>();
      _keyControllers[p.id]!.text = (entry?['value'] as String?) ?? '';
      _locked[p.id] = (entry?['locked'] as bool?) ?? false;
    }
  }

  Future<void> _saveName() async {
    final wsId = widget.auth.workspaceId;
    if (wsId == null) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _savingName = true;
      _error = null;
      _notice = null;
    });
    try {
      await FirebaseFirestore.instance
          .collection('workspaces')
          .doc(wsId)
          .set({'name': name, 'updatedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
      _notice = 'Workspace name saved.';
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _saveKeys() async {
    final wsId = widget.auth.workspaceId;
    if (wsId == null) return;
    setState(() {
      _savingKeys = true;
      _error = null;
      _notice = null;
    });
    try {
      final keys = <String, dynamic>{};
      for (final p in _providers) {
        final value = _keyControllers[p.id]!.text.trim();
        keys[p.id] = {
          'value': value.isEmpty ? null : value,
          'locked': _locked[p.id] ?? false,
        };
      }
      await FirebaseFirestore.instance
          .collection('workspaces')
          .doc(wsId)
          .set({
        'settings': {'aiProviderKeys': keys},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _notice = 'API keys saved. Team members pick them up automatically.';
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _savingKeys = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wsId = widget.auth.workspaceId;
    if (wsId == null) return const SizedBox.shrink();
    final canEdit = widget.auth.isOrgAdmin;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
          _syncFromDoc(data);
          _loaded = true;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              if (!canEdit) ...[
                const SizedBox(height: 6),
                const Text(
                  'Only the org admin can change workspace settings.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 16),
              _NameCard(
                controller: _nameController,
                canEdit: canEdit,
                saving: _savingName,
                onSave: _saveName,
              ),
              const SizedBox(height: 20),
              _ApiKeysCard(
                providers: _providers,
                keyControllers: _keyControllers,
                locked: _locked,
                canEdit: canEdit,
                saving: _savingKeys,
                onLockedChanged: (id, v) => setState(() => _locked[id] = v),
                onClear: (id) =>
                    setState(() => _keyControllers[id]!.clear()),
                onSave: _saveKeys,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              if (_notice != null) ...[
                const SizedBox(height: 12),
                Text(_notice!, style: const TextStyle(color: Colors.green)),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Section: workspace name
// ---------------------------------------------------------------------------

class _NameCard extends StatelessWidget {
  const _NameCard({
    required this.controller,
    required this.canEdit,
    required this.saving,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool canEdit;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
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
              controller: controller,
              enabled: canEdit,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (canEdit) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: saving ? null : onSave,
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save name'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section: AI provider API keys
// ---------------------------------------------------------------------------

class _ApiKeysCard extends StatelessWidget {
  const _ApiKeysCard({
    required this.providers,
    required this.keyControllers,
    required this.locked,
    required this.canEdit,
    required this.saving,
    required this.onLockedChanged,
    required this.onClear,
    required this.onSave,
  });

  final List<({String id, String label})> providers;
  final Map<String, TextEditingController> keyControllers;
  final Map<String, bool> locked;
  final bool canEdit;
  final bool saving;
  final void Function(String id, bool locked) onLockedChanged;
  final void Function(String id) onClear;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'AI provider API keys',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              "Paste your organisation's API keys here. Every team member's "
              'desktop app picks them up automatically. Lock a key to force '
              'the team to use it instead of their local value.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            for (final p in providers)
              _ProviderKeyRow(
                label: p.label,
                controller: keyControllers[p.id]!,
                locked: locked[p.id] ?? false,
                enabled: canEdit,
                onLockedChanged: (v) => onLockedChanged(p.id, v),
                onClear: () => onClear(p.id),
              ),
            if (canEdit) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: saving ? null : onSave,
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save keys'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProviderKeyRow extends StatefulWidget {
  const _ProviderKeyRow({
    required this.label,
    required this.controller,
    required this.locked,
    required this.enabled,
    required this.onLockedChanged,
    required this.onClear,
  });

  final String label;
  final TextEditingController controller;
  final bool locked;
  final bool enabled;
  final ValueChanged<bool> onLockedChanged;
  final VoidCallback onClear;

  @override
  State<_ProviderKeyRow> createState() => _ProviderKeyRowState();
}

class _ProviderKeyRowState extends State<_ProviderKeyRow> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: widget.controller,
              enabled: widget.enabled,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: widget.label,
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show' : 'Hide',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                ),
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: widget.locked,
              onChanged: widget.enabled
                  ? (v) => widget.onLockedChanged(v ?? false)
                  : null,
              title: const Text('Lock', style: TextStyle(fontSize: 13)),
            ),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: widget.enabled ? widget.onClear : null,
            icon: const Icon(Icons.clear, size: 20),
          ),
        ],
      ),
    );
  }
}
