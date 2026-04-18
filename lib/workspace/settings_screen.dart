import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

/// Workspace settings — org admin controls the central config that every
/// team member's desktop app picks up via `workspaces/{id}.settings.*`.
///
/// Sections:
///  - Workspace name
///  - AI provider API keys (with per-provider lock)
///  - Budgets (daily / monthly / per-job, warning %, hard-stop)
///  - Model defaults (per-provider model id)
///  - Implementation routing (default + fallback provider)
///
/// Every settings block carries a `locked` flag. When locked, the desktop
/// app's `WorkspaceSettingsService` overrides the local value and the
/// member cannot change it from their machine.
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

  // Workspace name
  final _nameController = TextEditingController();

  // API keys
  final Map<String, TextEditingController> _keyControllers = {
    for (final p in _providers) p.id: TextEditingController(),
  };
  final Map<String, bool> _keyLocked = {
    for (final p in _providers) p.id: false,
  };

  // Budgets
  final _dailyLimitController = TextEditingController();
  final _monthlyLimitController = TextEditingController();
  final _perJobLimitController = TextEditingController();
  final _warningPctController = TextEditingController();
  bool _hardStop = false;
  bool _budgetsLocked = false;

  // Model defaults
  final Map<String, TextEditingController> _modelDefaultControllers = {
    for (final p in _providers) p.id: TextEditingController(),
  };
  bool _modelDefaultsLocked = false;

  // Routing
  String? _defaultProvider;
  String? _fallbackProvider;
  bool _routingLocked = false;

  bool _loaded = false;
  bool _savingName = false;
  bool _savingKeys = false;
  bool _savingBudgets = false;
  bool _savingModels = false;
  bool _savingRouting = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _keyControllers.values) {
      c.dispose();
    }
    _dailyLimitController.dispose();
    _monthlyLimitController.dispose();
    _perJobLimitController.dispose();
    _warningPctController.dispose();
    for (final c in _modelDefaultControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncFromDoc(Map<String, dynamic> data) {
    _nameController.text = data['name'] as String? ?? '';
    final settings =
        (data['settings'] as Map?)?.cast<String, Object?>() ?? const {};

    // API keys
    final keys =
        (settings['aiProviderKeys'] as Map?)?.cast<String, Object?>() ??
            const {};
    for (final p in _providers) {
      final entry = (keys[p.id] as Map?)?.cast<String, Object?>();
      _keyControllers[p.id]!.text = (entry?['value'] as String?) ?? '';
      _keyLocked[p.id] = (entry?['locked'] as bool?) ?? false;
    }

    // Budgets
    final budgets =
        (settings['budgets'] as Map?)?.cast<String, Object?>() ?? const {};
    _dailyLimitController.text = _numToString(budgets['dailyLimitUsd']);
    _monthlyLimitController.text = _numToString(budgets['monthlyLimitUsd']);
    _perJobLimitController.text = _numToString(budgets['perJobLimitUsd']);
    _warningPctController.text = _numToString(budgets['warningPct']);
    _hardStop = (budgets['hardStop'] as bool?) ?? false;
    _budgetsLocked = (budgets['locked'] as bool?) ?? false;

    // Model defaults
    final models =
        (settings['modelDefaults'] as Map?)?.cast<String, Object?>() ??
            const {};
    for (final p in _providers) {
      _modelDefaultControllers[p.id]!.text =
          (models[p.id] as String?) ?? '';
    }
    _modelDefaultsLocked = (models['locked'] as bool?) ?? false;

    // Routing
    final routing =
        (settings['routing'] as Map?)?.cast<String, Object?>() ?? const {};
    _defaultProvider = routing['defaultProvider'] as String?;
    _fallbackProvider = routing['fallbackProvider'] as String?;
    _routingLocked = (routing['locked'] as bool?) ?? false;
  }

  String _numToString(Object? v) {
    if (v == null) return '';
    if (v is num) {
      if (v == v.toInt()) return v.toInt().toString();
      return v.toString();
    }
    return v.toString();
  }

  double? _parseDouble(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  DocumentReference<Map<String, dynamic>> _wsRef() {
    return FirebaseFirestore.instance
        .collection('workspaces')
        .doc(widget.auth.workspaceId);
  }

  Future<void> _saveSection(
    String ok,
    Future<void> Function() op,
    void Function(bool) setSaving,
  ) async {
    setState(() {
      setSaving(true);
      _error = null;
      _notice = null;
    });
    try {
      await op();
      _notice = ok;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => setSaving(false));
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await _saveSection(
      'Workspace name saved.',
      () => _wsRef().set({
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      (v) => _savingName = v,
    );
  }

  Future<void> _saveKeys() async {
    final keys = <String, dynamic>{};
    for (final p in _providers) {
      final value = _keyControllers[p.id]!.text.trim();
      keys[p.id] = {
        'value': value.isEmpty ? null : value,
        'locked': _keyLocked[p.id] ?? false,
      };
    }
    await _saveSection(
      'API keys saved.',
      () => _wsRef().set({
        'settings': {'aiProviderKeys': keys},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      (v) => _savingKeys = v,
    );
  }

  Future<void> _saveBudgets() async {
    final payload = <String, Object?>{
      'dailyLimitUsd': _parseDouble(_dailyLimitController.text),
      'monthlyLimitUsd': _parseDouble(_monthlyLimitController.text),
      'perJobLimitUsd': _parseDouble(_perJobLimitController.text),
      'warningPct': _parseDouble(_warningPctController.text),
      'hardStop': _hardStop,
      'locked': _budgetsLocked,
    };
    await _saveSection(
      'Budgets saved.',
      () => _wsRef().set({
        'settings': {'budgets': payload},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      (v) => _savingBudgets = v,
    );
  }

  Future<void> _saveModels() async {
    final payload = <String, Object?>{
      'locked': _modelDefaultsLocked,
      for (final p in _providers)
        p.id: _modelDefaultControllers[p.id]!.text.trim().isEmpty
            ? null
            : _modelDefaultControllers[p.id]!.text.trim(),
    };
    await _saveSection(
      'Model defaults saved.',
      () => _wsRef().set({
        'settings': {'modelDefaults': payload},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      (v) => _savingModels = v,
    );
  }

  Future<void> _saveRouting() async {
    final payload = <String, Object?>{
      'defaultProvider': _defaultProvider,
      'fallbackProvider': _fallbackProvider,
      'locked': _routingLocked,
    };
    await _saveSection(
      'Routing saved.',
      () => _wsRef().set({
        'settings': {'routing': payload},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      (v) => _savingRouting = v,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wsId = widget.auth.workspaceId;
    if (wsId == null) return const SizedBox.shrink();
    final canEdit = widget.auth.isOrgAdmin;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _wsRef().snapshots(),
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
                locked: _keyLocked,
                canEdit: canEdit,
                saving: _savingKeys,
                onLockedChanged: (id, v) =>
                    setState(() => _keyLocked[id] = v),
                onClear: (id) =>
                    setState(() => _keyControllers[id]!.clear()),
                onSave: _saveKeys,
              ),
              const SizedBox(height: 20),
              _BudgetsCard(
                dailyController: _dailyLimitController,
                monthlyController: _monthlyLimitController,
                perJobController: _perJobLimitController,
                warningController: _warningPctController,
                hardStop: _hardStop,
                locked: _budgetsLocked,
                canEdit: canEdit,
                saving: _savingBudgets,
                onHardStopChanged: (v) => setState(() => _hardStop = v),
                onLockedChanged: (v) => setState(() => _budgetsLocked = v),
                onSave: _saveBudgets,
              ),
              const SizedBox(height: 20),
              _ModelDefaultsCard(
                providers: _providers,
                controllers: _modelDefaultControllers,
                locked: _modelDefaultsLocked,
                canEdit: canEdit,
                saving: _savingModels,
                onLockedChanged: (v) =>
                    setState(() => _modelDefaultsLocked = v),
                onSave: _saveModels,
              ),
              const SizedBox(height: 20),
              _RoutingCard(
                providers: _providers,
                defaultProvider: _defaultProvider,
                fallbackProvider: _fallbackProvider,
                locked: _routingLocked,
                canEdit: canEdit,
                saving: _savingRouting,
                onDefaultChanged: (v) =>
                    setState(() => _defaultProvider = v),
                onFallbackChanged: (v) =>
                    setState(() => _fallbackProvider = v),
                onLockedChanged: (v) => setState(() => _routingLocked = v),
                onSave: _saveRouting,
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
// Section: shared helpers
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black54)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.saving,
    required this.onSave,
    required this.label,
  });
  final bool saving;
  final VoidCallback onSave;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton(
        onPressed: saving ? null : onSave,
        child: saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}

class _LockCheckbox extends StatelessWidget {
  const _LockCheckbox({
    required this.locked,
    required this.enabled,
    required this.onChanged,
  });
  final bool locked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: locked,
      onChanged: enabled ? (v) => onChanged(v ?? false) : null,
      title: const Text('Lock', style: TextStyle(fontSize: 13)),
      subtitle: const Text(
        'Force this value on every member',
        style: TextStyle(fontSize: 11, color: Colors.black54),
      ),
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
    return _SectionCard(
      title: 'Workspace name',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            _SaveButton(
                saving: saving, onSave: onSave, label: 'Save name'),
          ],
        ],
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
    return _SectionCard(
      title: 'AI provider API keys',
      subtitle:
          "Paste your organisation's API keys here. Every team member's "
          'desktop app picks them up automatically. Lock a key to force '
          'the team to use it instead of their local value.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in providers)
            _ProviderKeyRow(
              label: p.label,
              controller: keyControllers[p.id]!,
              locked: locked[p.id] ?? false,
              enabled: canEdit,
              onLockedChanged: (v) => onLockedChanged(p.id, v),
              onClear: () => onClear(p.id),
            ),
          if (canEdit)
            _SaveButton(
                saving: saving, onSave: onSave, label: 'Save keys'),
        ],
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

// ---------------------------------------------------------------------------
// Section: budgets
// ---------------------------------------------------------------------------

class _BudgetsCard extends StatelessWidget {
  const _BudgetsCard({
    required this.dailyController,
    required this.monthlyController,
    required this.perJobController,
    required this.warningController,
    required this.hardStop,
    required this.locked,
    required this.canEdit,
    required this.saving,
    required this.onHardStopChanged,
    required this.onLockedChanged,
    required this.onSave,
  });

  final TextEditingController dailyController;
  final TextEditingController monthlyController;
  final TextEditingController perJobController;
  final TextEditingController warningController;
  final bool hardStop;
  final bool locked;
  final bool canEdit;
  final bool saving;
  final ValueChanged<bool> onHardStopChanged;
  final ValueChanged<bool> onLockedChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Cost budgets',
      subtitle:
          'Soft and hard spend limits enforced by each member\'s desktop '
          'app. Leave a field blank for no limit.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _MoneyField(
                  controller: dailyController,
                  label: 'Daily limit (USD)',
                  enabled: canEdit,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MoneyField(
                  controller: monthlyController,
                  label: 'Monthly limit (USD)',
                  enabled: canEdit,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MoneyField(
                  controller: perJobController,
                  label: 'Per-job limit (USD)',
                  enabled: canEdit,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MoneyField(
                  controller: warningController,
                  label: 'Warning at % of limit',
                  enabled: canEdit,
                  suffix: '%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: hardStop,
            onChanged: canEdit ? onHardStopChanged : null,
            title: const Text('Hard stop when a limit is hit'),
            subtitle: const Text(
              'When off, members see a warning but can continue.',
              style: TextStyle(fontSize: 11),
            ),
          ),
          _LockCheckbox(
            locked: locked,
            enabled: canEdit,
            onChanged: onLockedChanged,
          ),
          if (canEdit)
            _SaveButton(
                saving: saving, onSave: onSave, label: 'Save budgets'),
        ],
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    required this.controller,
    required this.label,
    required this.enabled,
    this.suffix,
  });
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixText: suffix,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section: model defaults
// ---------------------------------------------------------------------------

class _ModelDefaultsCard extends StatelessWidget {
  const _ModelDefaultsCard({
    required this.providers,
    required this.controllers,
    required this.locked,
    required this.canEdit,
    required this.saving,
    required this.onLockedChanged,
    required this.onSave,
  });

  final List<({String id, String label})> providers;
  final Map<String, TextEditingController> controllers;
  final bool locked;
  final bool canEdit;
  final bool saving;
  final ValueChanged<bool> onLockedChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Model defaults',
      subtitle:
          'Model id used for each provider, e.g. "claude-sonnet-4-6", '
          '"gpt-4-turbo", "gemini-1.5-pro".',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in providers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: controllers[p.id],
                enabled: canEdit,
                decoration: InputDecoration(
                  labelText: '${p.label} — model id',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          _LockCheckbox(
            locked: locked,
            enabled: canEdit,
            onChanged: onLockedChanged,
          ),
          if (canEdit)
            _SaveButton(
                saving: saving, onSave: onSave, label: 'Save models'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section: implementation routing
// ---------------------------------------------------------------------------

class _RoutingCard extends StatelessWidget {
  const _RoutingCard({
    required this.providers,
    required this.defaultProvider,
    required this.fallbackProvider,
    required this.locked,
    required this.canEdit,
    required this.saving,
    required this.onDefaultChanged,
    required this.onFallbackChanged,
    required this.onLockedChanged,
    required this.onSave,
  });

  final List<({String id, String label})> providers;
  final String? defaultProvider;
  final String? fallbackProvider;
  final bool locked;
  final bool canEdit;
  final bool saving;
  final ValueChanged<String?> onDefaultChanged;
  final ValueChanged<String?> onFallbackChanged;
  final ValueChanged<bool> onLockedChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Implementation routing',
      subtitle:
          'Which provider the desktop app tries first, and which one it '
          'falls back to on error.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: defaultProvider,
                  decoration: const InputDecoration(
                    labelText: 'Default provider',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Not set')),
                    for (final p in providers)
                      DropdownMenuItem(value: p.id, child: Text(p.label)),
                  ],
                  onChanged: canEdit ? onDefaultChanged : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: fallbackProvider,
                  decoration: const InputDecoration(
                    labelText: 'Fallback provider',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('None')),
                    for (final p in providers)
                      DropdownMenuItem(value: p.id, child: Text(p.label)),
                  ],
                  onChanged: canEdit ? onFallbackChanged : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _LockCheckbox(
            locked: locked,
            enabled: canEdit,
            onChanged: onLockedChanged,
          ),
          if (canEdit)
            _SaveButton(
                saving: saving, onSave: onSave, label: 'Save routing'),
        ],
      ),
    );
  }
}
