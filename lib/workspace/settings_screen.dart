import 'package:cloud_functions/cloud_functions.dart';
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

  // Workspace integrations
  final _githubTokenController = TextEditingController();
  final _linearApiKeyController = TextEditingController();
  bool _hasGithubToken = false;
  bool _hasLinearApiKey = false;

  // Repository access
  final List<TextEditingController> _repoControllers = [];
  List<_WorkspaceMemberAccess> _workspaceMembers = const [];
  Map<String, Set<String>> _repoAccessByUser = {};

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
  bool _savingIntegrations = false;
  bool _savingRepoAccess = false;
  bool _importingRepos = false;
  bool _savingBudgets = false;
  bool _savingModels = false;
  bool _savingRouting = false;
  bool _loadingAdminConfig = false;
  String? _adminConfigWorkspaceId;
  String? _error;
  String? _notice;

  static final RegExp _repoSlugRe =
      RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$');

  @override
  void dispose() {
    _nameController.dispose();
    _githubTokenController.dispose();
    _linearApiKeyController.dispose();
    for (final c in _keyControllers.values) {
      c.dispose();
    }
    for (final c in _repoControllers) {
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

  void _setRepoControllers(List<String> repos) {
    for (final controller in _repoControllers) {
      controller.dispose();
    }
    _repoControllers
      ..clear()
      ..addAll(
        (repos.isEmpty ? [''] : repos).map((repo) => TextEditingController(text: repo)),
      );
  }

  Future<void> _loadAdminConfig(String wsId) async {
    if (_loadingAdminConfig && _adminConfigWorkspaceId == wsId) return;
    setState(() {
      _loadingAdminConfig = true;
      _adminConfigWorkspaceId = wsId;
    });
    try {
      final membersFuture = FirebaseFunctions.instance
          .httpsCallable('listWorkspaceMembers')
          .call<Map<String, dynamic>>({'workspaceId': wsId});
      final integrationsFuture = FirebaseFunctions.instance
          .httpsCallable('getWorkspaceIntegrationStatus')
          .call<Map<String, dynamic>>({'workspaceId': wsId});
      final repoAccessFuture = FirebaseFunctions.instance
          .httpsCallable('getWorkspaceRepoAccess')
          .call<Map<String, dynamic>>({'workspaceId': wsId});

      final results = await Future.wait([
        membersFuture,
        integrationsFuture,
        repoAccessFuture,
      ]);

      final rawMembers = (results[0].data['members'] as List?) ?? const [];
      final members = rawMembers
          .map((m) => _WorkspaceMemberAccess.fromJson(
              Map<String, dynamic>.from(m as Map)))
          .toList()
        ..sort((a, b) {
          if (a.workspaceRole != b.workspaceRole) {
            return a.workspaceRole == 'admin' ? -1 : 1;
          }
          return (a.email ?? a.uid).compareTo(b.email ?? b.uid);
        });

      final integrations = results[1].data;
      final rawRepos = (results[2].data['repos'] as List?) ?? const [];
      final repos = rawRepos
          .map((value) => value?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toList();
      final rawRepoAccess =
          (results[2].data['repoAccessByUser'] as Map?) ?? const {};
      final repoSet = repos.toSet();
      final repoAccessByUser = <String, Set<String>>{
        for (final entry in rawRepoAccess.entries)
          entry.key.toString(): ((entry.value as List?) ?? const [])
              .map((value) => value?.toString().trim() ?? '')
              .where((value) => repoSet.contains(value))
              .toSet(),
      };

      if (!mounted) return;
      setState(() {
        _workspaceMembers = members;
        _hasGithubToken = integrations['hasGithubToken'] as bool? ?? false;
        _hasLinearApiKey = integrations['hasLinearApiKey'] as bool? ?? false;
        _setRepoControllers(repos);
        _repoAccessByUser = repoAccessByUser;
      });
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingAdminConfig = false);
    }
  }

  Future<void> _saveIntegrations() async {
    final wsId = widget.auth.workspaceId;
    if (wsId == null) return;
    await _saveSection(
      'Workspace integrations saved.',
      () async {
        final result = await FirebaseFunctions.instance
            .httpsCallable('saveWorkspaceIntegrationSecrets')
            .call<Map<String, dynamic>>({
          'workspaceId': wsId,
          'githubToken': _githubTokenController.text.trim(),
          'linearApiKey': _linearApiKeyController.text.trim(),
        });
        _hasGithubToken = result.data['hasGithubToken'] as bool? ?? false;
        _hasLinearApiKey = result.data['hasLinearApiKey'] as bool? ?? false;
        _githubTokenController.clear();
        _linearApiKeyController.clear();
      },
      (v) => _savingIntegrations = v,
    );
  }

  void _addRepoField() {
    setState(() => _repoControllers.add(TextEditingController()));
  }

  void _removeRepoField(int index) {
    final controller = _repoControllers.removeAt(index);
    controller.dispose();
    if (_repoControllers.isEmpty) {
      _repoControllers.add(TextEditingController());
    }
    setState(() {
      final repos = _currentRepoSlugs();
      for (final entry in _repoAccessByUser.entries) {
        entry.value.removeWhere((repo) => !repos.contains(repo));
      }
    });
  }

  List<String> _currentRepoSlugs() {
    final seen = <String>{};
    final repos = <String>[];
    for (final controller in _repoControllers) {
      final value = controller.text.trim();
      if (value.isEmpty || !seen.add(value)) continue;
      repos.add(value);
    }
    return repos;
  }

  Future<void> _saveRepoAccess() async {
    final wsId = widget.auth.workspaceId;
    if (wsId == null) return;
    final repos = _currentRepoSlugs();
    final invalid = repos.where((repo) => !_repoSlugRe.hasMatch(repo)).toList();
    if (invalid.isNotEmpty) {
      setState(() {
        _error =
            'Repositories must use owner/repo format. Invalid: ${invalid.join(', ')}';
        _notice = null;
      });
      return;
    }
    final repoSet = repos.toSet();
    final payload = <String, List<String>>{
      for (final member in _workspaceMembers)
        member.uid: (_repoAccessByUser[member.uid] ?? const <String>{})
            .where(repoSet.contains)
            .toList()
          ..sort(),
    };
    await _saveSection(
      'Repository access saved.',
      () async {
        final result = await FirebaseFunctions.instance
            .httpsCallable('saveWorkspaceRepoAccess')
            .call<Map<String, dynamic>>({
          'workspaceId': wsId,
          'repos': repos,
          'repoAccessByUser': payload,
        });
        final savedRepos = ((result.data['repos'] as List?) ?? const [])
            .map((value) => value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toList();
        final savedRepoSet = savedRepos.toSet();
        final savedRawAccess =
            (result.data['repoAccessByUser'] as Map?) ?? const {};
        _setRepoControllers(savedRepos);
        _repoAccessByUser = {
          for (final entry in savedRawAccess.entries)
            entry.key.toString(): ((entry.value as List?) ?? const [])
                .map((value) => value?.toString().trim() ?? '')
                .where((value) => savedRepoSet.contains(value))
                .toSet(),
        };
      },
      (v) => _savingRepoAccess = v,
    );
  }

  Future<void> _importGithubRepos() async {
    final wsId = widget.auth.workspaceId;
    if (wsId == null) return;
    setState(() {
      _importingRepos = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('importWorkspaceGithubRepos')
          .call<Map<String, dynamic>>({'workspaceId': wsId});
      final repos = ((result.data['repos'] as List?) ?? const [])
          .map((value) => value?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toList();
      final repoSet = repos.toSet();
      if (!mounted) return;
      setState(() {
        _setRepoControllers(repos);
        for (final entry in _repoAccessByUser.entries) {
          entry.value.removeWhere((repo) => !repoSet.contains(repo));
        }
        _notice = repos.isEmpty
            ? 'GitHub import returned no accessible repositories.'
            : 'Imported ${repos.length} repositories from GitHub.';
      });
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _importingRepos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wsId = widget.auth.workspaceId;
    if (wsId == null) return const SizedBox.shrink();
    final canEdit = widget.auth.isOrgAdmin;
    if (canEdit && _adminConfigWorkspaceId != wsId && !_loadingAdminConfig) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAdminConfig(wsId));
    }

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
              _IntegrationsCard(
                githubTokenController: _githubTokenController,
                linearApiKeyController: _linearApiKeyController,
                hasGithubToken: _hasGithubToken,
                hasLinearApiKey: _hasLinearApiKey,
                canEdit: canEdit,
                saving: _savingIntegrations,
                loading: _loadingAdminConfig,
                onSave: _saveIntegrations,
              ),
              const SizedBox(height: 20),
              _RepoAccessCard(
                repoControllers: _repoControllers,
                members: _workspaceMembers,
                repoAccessByUser: _repoAccessByUser,
                canEdit: canEdit,
                loading: _loadingAdminConfig,
                saving: _savingRepoAccess,
                importing: _importingRepos,
                currentUserUid: widget.auth.user?.uid,
                onAddRepo: _addRepoField,
                onImportGithubRepos: _importGithubRepos,
                onRemoveRepo: _removeRepoField,
                onToggleAccess: (uid, repo, enabled) => setState(() {
                  final set = _repoAccessByUser.putIfAbsent(uid, () => <String>{});
                  if (enabled) {
                    set.add(repo);
                  } else {
                    set.remove(repo);
                  }
                }),
                onSave: _saveRepoAccess,
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
// Section: workspace integrations
// ---------------------------------------------------------------------------

class _IntegrationsCard extends StatelessWidget {
  const _IntegrationsCard({
    required this.githubTokenController,
    required this.linearApiKeyController,
    required this.hasGithubToken,
    required this.hasLinearApiKey,
    required this.canEdit,
    required this.saving,
    required this.loading,
    required this.onSave,
  });

  final TextEditingController githubTokenController;
  final TextEditingController linearApiKeyController;
  final bool hasGithubToken;
  final bool hasLinearApiKey;
  final bool canEdit;
  final bool saving;
  final bool loading;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Workspace integrations',
      subtitle:
          'Securely store organisation-level GitHub and Linear credentials '
          'for this workspace. Saved secrets are not shown again here; '
          'enter a new value to rotate or clear one.',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SecretField(
                  controller: githubTokenController,
                  label: 'GitHub token',
                  enabled: canEdit,
                  configured: hasGithubToken,
                ),
                const SizedBox(height: 12),
                _SecretField(
                  controller: linearApiKeyController,
                  label: 'Linear API key',
                  enabled: canEdit,
                  configured: hasLinearApiKey,
                ),
                if (canEdit) ...[
                  const SizedBox(height: 8),
                  _SaveButton(
                    saving: saving,
                    onSave: onSave,
                    label: 'Save integrations',
                  ),
                ],
              ],
            ),
    );
  }
}

class _SecretField extends StatefulWidget {
  const _SecretField({
    required this.controller,
    required this.label,
    required this.enabled,
    required this.configured,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final bool configured;

  @override
  State<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<_SecretField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.configured
                ? 'Configured. Enter a new value to rotate or clear.'
                : 'Not configured yet',
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Show' : 'Hide',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            label: Text(
              widget.configured ? 'Configured' : 'Not configured',
              style: const TextStyle(fontSize: 11),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section: repository access
// ---------------------------------------------------------------------------

class _RepoAccessCard extends StatelessWidget {
  const _RepoAccessCard({
    required this.repoControllers,
    required this.members,
    required this.repoAccessByUser,
    required this.canEdit,
    required this.loading,
    required this.saving,
    required this.importing,
    required this.currentUserUid,
    required this.onAddRepo,
    required this.onImportGithubRepos,
    required this.onRemoveRepo,
    required this.onToggleAccess,
    required this.onSave,
  });

  final List<TextEditingController> repoControllers;
  final List<_WorkspaceMemberAccess> members;
  final Map<String, Set<String>> repoAccessByUser;
  final bool canEdit;
  final bool loading;
  final bool saving;
  final bool importing;
  final String? currentUserUid;
  final VoidCallback onAddRepo;
  final VoidCallback onImportGithubRepos;
  final void Function(int index) onRemoveRepo;
  final void Function(String uid, String repo, bool enabled) onToggleAccess;
  final VoidCallback onSave;

  List<String> get _repos {
    final seen = <String>{};
    final values = <String>[];
    for (final controller in repoControllers) {
      final value = controller.text.trim();
      if (value.isEmpty || !seen.add(value)) continue;
      values.add(value);
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final repos = _repos;
    return _SectionCard(
      title: 'GitHub repositories and access',
      subtitle:
          'List the repositories this workspace can use, then choose which '
          'members can access each one.',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < repoControllers.length; i++) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: repoControllers[i],
                          enabled: canEdit,
                          decoration: const InputDecoration(
                            labelText: 'GitHub repository',
                            hintText: 'owner/repository',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Remove repository',
                        onPressed: canEdit ? () => onRemoveRepo(i) : null,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (canEdit)
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: onAddRepo,
                        icon: const Icon(Icons.add),
                        label: const Text('Add repository'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: importing ? null : onImportGithubRepos,
                        icon: importing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync),
                        label: Text(
                          importing ? 'Importing…' : 'Import from GitHub',
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                if (members.isEmpty)
                  const Text(
                    'Invite teammates first to assign repository access.',
                    style: TextStyle(color: Colors.black54),
                  )
                else if (repos.isEmpty)
                  const Text(
                    'Add at least one repository to configure member access.',
                    style: TextStyle(color: Colors.black54),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Member access',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      for (final member in members) ...[
                        _MemberRepoAccessRow(
                          member: member,
                          repos: repos,
                          selectedRepos:
                              repoAccessByUser[member.uid] ?? const <String>{},
                          enabled: canEdit,
                          isCurrentUser: member.uid == currentUserUid,
                          onToggle: (repo, enabled) =>
                              onToggleAccess(member.uid, repo, enabled),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                if (canEdit)
                  _SaveButton(
                    saving: saving,
                    onSave: onSave,
                    label: 'Save repository access',
                  ),
              ],
            ),
    );
  }
}

class _MemberRepoAccessRow extends StatelessWidget {
  const _MemberRepoAccessRow({
    required this.member,
    required this.repos,
    required this.selectedRepos,
    required this.enabled,
    required this.isCurrentUser,
    required this.onToggle,
  });

  final _WorkspaceMemberAccess member;
  final List<String> repos;
  final Set<String> selectedRepos;
  final bool enabled;
  final bool isCurrentUser;
  final void Function(String repo, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  member.email ?? member.uid,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              if (isCurrentUser)
                const Chip(
                  label: Text('You', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
              if (member.workspaceRole == 'admin') ...[
                const SizedBox(width: 8),
                const Chip(
                  label: Text('Org admin', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final repo in repos)
                FilterChip(
                  label: Text(repo),
                  selected: selectedRepos.contains(repo),
                  onSelected: enabled ? (v) => onToggle(repo, v) : null,
                ),
            ],
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

class _WorkspaceMemberAccess {
  const _WorkspaceMemberAccess({
    required this.uid,
    required this.email,
    required this.workspaceRole,
  });

  final String uid;
  final String? email;
  final String workspaceRole;

  factory _WorkspaceMemberAccess.fromJson(Map<String, dynamic> json) {
    return _WorkspaceMemberAccess(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String?,
      workspaceRole: json['workspaceRole'] as String? ?? 'member',
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
