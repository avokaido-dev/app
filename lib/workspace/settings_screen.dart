import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import 'smoke_tests/smoke_tests_screen.dart';

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

  // Model defaults
  final Map<String, TextEditingController> _modelDefaultControllers = {
    for (final p in _providers) p.id: TextEditingController(),
  };
  bool _modelDefaultsLocked = false;

  // Routing
  String? _defaultProvider;
  String? _fallbackProvider;
  bool _routingLocked = false;

  // QA rules — workspace-wide defaults for repository quality checks.
  // Desktop clients read these from workspaces/{id}.settings.qaRules and
  // seed the per-repo Edit Repository dialog. When `_qaRulesLocked` is true,
  // the desktop app hides the per-repo controls and enforces these values.
  static const List<({String id, String label})> _qaCheckIds = [
    (id: 'dependencies', label: 'Dependencies'),
    (id: 'format', label: 'Format'),
    (id: 'analyze', label: 'Analyze'),
    (id: 'test', label: 'Test'),
    (id: 'complexity', label: 'Big O (complexity)'),
    (id: 'logs', label: 'System logs'),
  ];
  final Map<String, bool> _qaCheckEnabled = {
    for (final c in _qaCheckIds) c.id: true,
  };
  final Map<String, String> _qaCheckSeverity = {
    for (final c in _qaCheckIds) c.id: 'critical',
  };
  bool _qaRulesLocked = false;
  bool _savingQaRules = false;

  bool _loaded = false;
  bool _savingName = false;
  // ignore: unused_field
  bool _savingKeys = false; // AI provider keys card is hidden for now.
  bool _savingGithubToken = false;
  bool _savingLinearApiKey = false;
  bool _savingRepoAccess = false;
  bool _importingRepos = false;
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

    // QA rules
    final qa =
        (settings['qaRules'] as Map?)?.cast<String, Object?>() ?? const {};
    final qaChecks =
        (qa['checks'] as Map?)?.cast<String, Object?>() ?? const {};
    for (final c in _qaCheckIds) {
      final entry = (qaChecks[c.id] as Map?)?.cast<String, Object?>();
      _qaCheckEnabled[c.id] = (entry?['enabled'] as bool?) ?? true;
      final severity = entry?['severity'] as String?;
      _qaCheckSeverity[c.id] =
          (severity == 'warning' || severity == 'critical')
              ? severity!
              : 'critical';
    }
    _qaRulesLocked = (qa['locked'] as bool?) ?? false;
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
      debugPrint('[settings] _saveSection ok: $ok');
    } catch (e, st) {
      _error = e.toString();
      debugPrint('[settings] _saveSection error: $e\n$st');
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

  // ignore: unused_element
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

  Future<void> _saveQaRules() async {
    final checks = <String, Object?>{
      for (final c in _qaCheckIds)
        c.id: {
          'enabled': _qaCheckEnabled[c.id] ?? true,
          'severity': _qaCheckSeverity[c.id] ?? 'critical',
        },
    };
    await _saveSection(
      'QA rules saved.',
      () => _wsRef().set({
        'settings': {
          'qaRules': {
            'checks': checks,
            'locked': _qaRulesLocked,
          },
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
      (v) => _savingQaRules = v,
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
      final wsDocFuture = _wsRef().get();
      final repoAccessFuture = FirebaseFunctions.instance
          .httpsCallable('getWorkspaceRepoAccess')
          .call<Map<String, dynamic>>({'workspaceId': wsId});

      final membersResult = await membersFuture;
      final wsSnap = await wsDocFuture;
      final repoAccessResult = await repoAccessFuture;

      final rawMembers = (membersResult.data['members'] as List?) ?? const [];
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

      final integrations =
          (wsSnap.data()?['integrations'] as Map?) ?? const {};
      debugPrint(
          '[settings] _loadAdminConfig integrations=$integrations');
      final rawRepos = (repoAccessResult.data['repos'] as List?) ?? const [];
      final repos = rawRepos
          .map((value) => value?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toList();
      final rawRepoAccess =
          (repoAccessResult.data['repoAccessByUser'] as Map?) ?? const {};
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
        _hasGithubToken =
            (integrations['githubToken'] as String?)?.trim().isNotEmpty ?? false;
        _hasLinearApiKey =
            (integrations['linearApiKey'] as String?)?.trim().isNotEmpty ?? false;
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

  Future<void> _saveGithubToken() async {
    final wsId = widget.auth.workspaceId;
    debugPrint('[settings] _saveGithubToken start wsId=$wsId');
    if (wsId == null) {
      debugPrint('[settings] _saveGithubToken abort: wsId is null');
      return;
    }
    final token = _githubTokenController.text.trim();
    debugPrint(
        '[settings] _saveGithubToken token len=${token.length} prefix='
        '${token.isEmpty ? "<empty>" : token.substring(0, token.length < 4 ? token.length : 4)}…');
    if (token.isEmpty) {
      setState(() => _error =
          'Paste a GitHub token (ghp_… or github_pat_…) before saving.');
      return;
    }
    if (!token.startsWith('ghp_') && !token.startsWith('github_pat_')) {
      setState(() => _error =
          "That doesn't look like a GitHub token. It should start with "
          '"ghp_" or "github_pat_".');
      return;
    }
    await _saveSection(
      'GitHub token saved.',
      () async {
        await _wsRef().set({
          'integrations': {'githubToken': token},
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _hasGithubToken = true;
        _githubTokenController.clear();
      },
      (v) => _savingGithubToken = v,
    );
  }

  Future<void> _saveLinearApiKey() async {
    final wsId = widget.auth.workspaceId;
    if (wsId == null) return;
    final key = _linearApiKeyController.text.trim();
    await _saveSection(
      'Linear API key saved.',
      () async {
        await _wsRef().set({
          'integrations': {
            'linearApiKey': key.isEmpty ? FieldValue.delete() : key,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _hasLinearApiKey = key.isNotEmpty;
        _linearApiKeyController.clear();
      },
      (v) => _savingLinearApiKey = v,
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
    debugPrint('[settings] _saveRepoAccess invoked');
    final wsId = widget.auth.workspaceId;
    if (wsId == null) {
      debugPrint('[settings] _saveRepoAccess aborted: workspaceId is null');
      if (mounted) {
        setState(() {
          _error = 'No active workspace — cannot save.';
          _notice = null;
        });
      }
      return;
    }
    final repos = _currentRepoSlugs();
    debugPrint('[settings] _saveRepoAccess wsId=$wsId repos=$repos');
    final invalid = repos.where((repo) => !_repoSlugRe.hasMatch(repo)).toList();
    if (invalid.isNotEmpty) {
      debugPrint('[settings] _saveRepoAccess aborted: invalid repos=$invalid');
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
    List<String> available = const [];
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('importWorkspaceGithubRepos')
          .call<Map<String, dynamic>>({'workspaceId': wsId});
      available = ((result.data['repos'] as List?) ?? const [])
          .map((value) => value?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toList();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
      return;
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      return;
    } finally {
      if (mounted) setState(() => _importingRepos = false);
    }

    if (!mounted) return;
    if (available.isEmpty) {
      setState(() => _notice =
          'No repositories accessible with this token.');
      return;
    }

    final existing = _currentRepoSlugs().toSet();
    final picked = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _GithubRepoPickerDialog(
        available: available,
        alreadyAdded: existing,
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    setState(() {
      _setRepoControllers([...existing, ...picked]);
      _notice = 'Added ${picked.length} '
          '${picked.length == 1 ? 'repository' : 'repositories'}. '
          'Click "Save repositories & access" to persist.';
    });
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
              // AI provider API keys card hidden for now — controllers + save
              // path kept intact so we can re-enable without reworking state.
              _GitHubCard(
                tokenController: _githubTokenController,
                hasToken: _hasGithubToken,
                savingToken: _savingGithubToken,
                onSaveToken: _saveGithubToken,
                repoControllers: _repoControllers,
                members: _workspaceMembers,
                repoAccessByUser: _repoAccessByUser,
                canEdit: canEdit,
                loading: _loadingAdminConfig,
                savingRepoAccess: _savingRepoAccess,
                importing: _importingRepos,
                currentUserUid: widget.auth.user?.uid,
                onAddRepo: _addRepoField,
                onImportGithubRepos: _importGithubRepos,
                onRemoveRepo: _removeRepoField,
                onToggleAccess: (uid, repo, enabled) => setState(() {
                  final set =
                      _repoAccessByUser.putIfAbsent(uid, () => <String>{});
                  if (enabled) {
                    set.add(repo);
                  } else {
                    set.remove(repo);
                  }
                }),
                onSaveRepoAccess: _saveRepoAccess,
              ),
              const SizedBox(height: 20),
              _LinearCard(
                apiKeyController: _linearApiKeyController,
                hasApiKey: _hasLinearApiKey,
                canEdit: canEdit,
                saving: _savingLinearApiKey,
                loading: _loadingAdminConfig,
                onSave: _saveLinearApiKey,
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
              const SizedBox(height: 20),
              _QaRulesCard(
                checkIds: _qaCheckIds,
                enabled: _qaCheckEnabled,
                severity: _qaCheckSeverity,
                locked: _qaRulesLocked,
                canEdit: canEdit,
                saving: _savingQaRules,
                onEnabledChanged: (id, v) =>
                    setState(() => _qaCheckEnabled[id] = v),
                onSeverityChanged: (id, v) =>
                    setState(() => _qaCheckSeverity[id] = v),
                onLockedChanged: (v) => setState(() => _qaRulesLocked = v),
                onSave: _saveQaRules,
              ),
              const SizedBox(height: 20),
              _SmokeTestsCard(
                canEdit: canEdit,
                onOpen: () {
                  final wsId = widget.auth.workspaceId;
                  if (wsId == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SmokeTestsScreen(workspaceId: wsId),
                    ),
                  );
                },
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
    this.trailing,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                ?trailing,
              ],
            ),
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

// ignore: unused_element
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

  _SettingState _aggregateState() {
    var anyValue = false;
    var anyLocked = false;
    var allLocked = true;
    for (final p in providers) {
      final hasValue = (keyControllers[p.id]?.text.trim().isNotEmpty) ?? false;
      final isLocked = locked[p.id] ?? false;
      if (hasValue) anyValue = true;
      if (isLocked) anyLocked = true;
      if (!isLocked) allLocked = false;
    }
    if (!anyValue) return _SettingState.notSet;
    if (anyLocked && allLocked) return _SettingState.enforced;
    return _SettingState.cloudDefault;
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'AI provider API keys',
      trailing: _StatusChip(_aggregateState()),
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
// Status chip — shows where a setting's value lives
// ---------------------------------------------------------------------------

/// Cloud-precedence state for a workspace setting, as seen from the admin
/// panel. The admin panel never sees an individual member's local override,
/// so these states describe what the cloud tells the desktop app to do:
///
///  * [enforced]   — value is set and `locked: true`. Desktop apps must use
///                   this value; members cannot override it locally.
///  * [cloudDefault] — value is set, `locked: false`. Desktop apps use this
///                   as the default but members can override it locally.
///  * [notSet]     — no value in the cloud. Each desktop app uses whatever
///                   the member configured on their own machine.
enum _SettingState { enforced, cloudDefault, notSet }

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.state);
  final _SettingState state;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg, tooltip) = switch (state) {
      _SettingState.enforced => (
          'Cloud · enforced',
          const Color(0xFFDCF2E0),
          const Color(0xFF1B5E20),
          'Value is set here and locked. Every member\'s desktop app '
              'must use this value.',
        ),
      _SettingState.cloudDefault => (
          'Cloud · default',
          const Color(0xFFE3F2FD),
          const Color(0xFF0D47A1),
          'Value is set here as a default. Members can still override '
              'it locally in the desktop app.',
        ),
      _SettingState.notSet => (
          'Not set',
          const Color(0xFFEEEEEE),
          const Color(0xFF616161),
          'No cloud value. Each desktop app uses the member\'s own '
              'local configuration.',
        ),
    };
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

_SettingState _stateFor({required bool hasValue, required bool locked}) {
  if (!hasValue) return _SettingState.notSet;
  return locked ? _SettingState.enforced : _SettingState.cloudDefault;
}

// ---------------------------------------------------------------------------
// Section: GitHub (token + repositories + member access)
// ---------------------------------------------------------------------------

class _GitHubCard extends StatelessWidget {
  const _GitHubCard({
    required this.tokenController,
    required this.hasToken,
    required this.savingToken,
    required this.onSaveToken,
    required this.repoControllers,
    required this.members,
    required this.repoAccessByUser,
    required this.canEdit,
    required this.loading,
    required this.savingRepoAccess,
    required this.importing,
    required this.currentUserUid,
    required this.onAddRepo,
    required this.onImportGithubRepos,
    required this.onRemoveRepo,
    required this.onToggleAccess,
    required this.onSaveRepoAccess,
  });

  final TextEditingController tokenController;
  final bool hasToken;
  final bool savingToken;
  final VoidCallback onSaveToken;

  final List<TextEditingController> repoControllers;
  final List<_WorkspaceMemberAccess> members;
  final Map<String, Set<String>> repoAccessByUser;
  final bool canEdit;
  final bool loading;
  final bool savingRepoAccess;
  final bool importing;
  final String? currentUserUid;
  final VoidCallback onAddRepo;
  final VoidCallback onImportGithubRepos;
  final void Function(int index) onRemoveRepo;
  final void Function(String uid, String repo, bool enabled) onToggleAccess;
  final VoidCallback onSaveRepoAccess;

  static final RegExp _slugRe =
      RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$');

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
    debugPrint('[settings] _GitHubCard build hasToken=$hasToken '
        'savingToken=$savingToken loading=$loading');
    final repos = _repos;
    return _SectionCard(
      title: 'GitHub',
      subtitle:
          'Organisation-wide GitHub token, the repositories this workspace '
          'can use, and which members can access each one. These are stored '
          'in the cloud and always apply to every member.',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Token
                _LabeledRow(
                  title: 'Organisation token',
                  chip: _StatusChip(
                    hasToken
                        ? _SettingState.enforced
                        : _SettingState.notSet,
                  ),
                ),
                const SizedBox(height: 8),
                _SecretField(
                  controller: tokenController,
                  label: 'GitHub token (ghp_… or github_pat_…)',
                  enabled: canEdit,
                  configured: hasToken,
                ),
                if (canEdit) ...[
                  const SizedBox(height: 8),
                  _SaveButton(
                    saving: savingToken,
                    onSave: onSaveToken,
                    label: 'Save GitHub token',
                  ),
                ],
                const Divider(height: 32),

                // 2. Repositories
                _LabeledRow(
                  title: 'Repositories',
                  chip: _StatusChip(
                    repos.isEmpty
                        ? _SettingState.notSet
                        : _SettingState.enforced,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Use the owner/repo format, e.g. "avokaido/desktop". '
                  'Do not paste a token here — the token field is above.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < repoControllers.length; i++) ...[
                  _RepoField(
                    controller: repoControllers[i],
                    enabled: canEdit,
                    onRemove: canEdit ? () => onRemoveRepo(i) : null,
                    validate: (v) {
                      final t = v.trim();
                      if (t.isEmpty) return null;
                      if (t.startsWith('ghp_') ||
                          t.startsWith('github_pat_')) {
                        return 'This looks like a token. Put it in the '
                            'field above, not here.';
                      }
                      if (!_slugRe.hasMatch(t)) {
                        return 'Expected owner/repository format.';
                      }
                      return null;
                    },
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
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.sync),
                        label: Text(
                          importing ? 'Importing…' : 'Import from GitHub',
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),

                // 3. Member access
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
                else ...[
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
                if (canEdit)
                  _SaveButton(
                    saving: savingRepoAccess,
                    onSave: onSaveRepoAccess,
                    label: 'Save repositories & access',
                  ),
              ],
            ),
    );
  }
}

class _RepoField extends StatefulWidget {
  const _RepoField({
    required this.controller,
    required this.enabled,
    required this.onRemove,
    required this.validate,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onRemove;
  final String? Function(String) validate;

  @override
  State<_RepoField> createState() => _RepoFieldState();
}

class _RepoFieldState extends State<_RepoField> {
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_revalidate);
    _error = widget.validate(widget.controller.text);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_revalidate);
    super.dispose();
  }

  void _revalidate() {
    final next = widget.validate(widget.controller.text);
    if (next != _error) setState(() => _error = next);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: widget.controller,
            enabled: widget.enabled,
            decoration: InputDecoration(
              labelText: 'GitHub repository',
              hintText: 'owner/repository',
              border: const OutlineInputBorder(),
              isDense: true,
              errorText: _error,
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: IconButton(
            tooltip: 'Remove repository',
            onPressed: widget.onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      ],
    );
  }
}

class _LabeledRow extends StatelessWidget {
  const _LabeledRow({required this.title, required this.chip});
  final String title;
  final Widget chip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(width: 10),
        chip,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section: Linear
// ---------------------------------------------------------------------------

class _LinearCard extends StatelessWidget {
  const _LinearCard({
    required this.apiKeyController,
    required this.hasApiKey,
    required this.canEdit,
    required this.saving,
    required this.loading,
    required this.onSave,
  });

  final TextEditingController apiKeyController;
  final bool hasApiKey;
  final bool canEdit;
  final bool saving;
  final bool loading;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Linear',
      subtitle:
          'Organisation-wide Linear API key. Stored in the cloud and used '
          'by every member\'s desktop app.',
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LabeledRow(
                  title: 'API key',
                  chip: _StatusChip(
                    hasApiKey
                        ? _SettingState.enforced
                        : _SettingState.notSet,
                  ),
                ),
                const SizedBox(height: 8),
                _SecretField(
                  controller: apiKeyController,
                  label: 'Linear API key (lin_api_…)',
                  enabled: canEdit,
                  configured: hasApiKey,
                ),
                if (canEdit) ...[
                  const SizedBox(height: 8),
                  _SaveButton(
                    saving: saving,
                    onSave: onSave,
                    label: 'Save Linear API key',
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

  static const Map<String, List<String>> _suggestions = {
    'anthropic': [
      'claude-opus-4-7',
      'claude-sonnet-4-6',
      'claude-haiku-4-5-20251001',
      'claude-opus-4-20250514',
      'claude-sonnet-4-20250514',
      'claude-3-7-sonnet-20250219',
      'claude-3-5-haiku-20241022',
    ],
    'openai': [
      'gpt-4.1',
      'gpt-4.1-mini',
      'gpt-4.1-nano',
      'gpt-4o',
      'gpt-4o-mini',
      'o3',
      'o3-mini',
      'o4-mini',
    ],
    'gemini': [
      'gemini-2.5-pro',
      'gemini-2.5-flash',
      'gemini-2.0-flash',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final hasValue = providers
        .any((p) => controllers[p.id]?.text.trim().isNotEmpty ?? false);
    return _SectionCard(
      title: 'Model defaults',
      trailing: _StatusChip(_stateFor(hasValue: hasValue, locked: locked)),
      subtitle:
          'Model id used for each provider. Pick a suggested id or type a '
          'custom one.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in providers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ModelIdField(
                label: '${p.label} — model id',
                controller: controllers[p.id]!,
                suggestions: _suggestions[p.id] ?? const [],
                enabled: canEdit,
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

/// Editable dropdown: a text field with a clickable arrow that opens a menu
/// of known model ids. Typing a custom value is allowed — the menu only
/// surfaces suggestions, never restricts.
class _ModelIdField extends StatelessWidget {
  const _ModelIdField({
    required this.label,
    required this.controller,
    required this.suggestions,
    required this.enabled,
  });

  final String label;
  final TextEditingController controller;
  final List<String> suggestions;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: suggestions.isEmpty
            ? null
            : PopupMenuButton<String>(
                tooltip: 'Pick a known model id',
                enabled: enabled,
                icon: const Icon(Icons.arrow_drop_down),
                onSelected: (value) {
                  controller.text = value;
                  controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: value.length),
                  );
                },
                itemBuilder: (_) => [
                  for (final id in suggestions)
                    PopupMenuItem(
                      value: id,
                      child: Text(
                        id,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                ],
              ),
      ),
      style: const TextStyle(fontFamily: 'monospace'),
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
    final hasValue = defaultProvider != null || fallbackProvider != null;
    return _SectionCard(
      title: 'Implementation routing',
      trailing: _StatusChip(_stateFor(hasValue: hasValue, locked: locked)),
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

// ---------------------------------------------------------------------------
// Section: QA rules
// ---------------------------------------------------------------------------

/// Workspace-wide QA check defaults. Desktop clients read these from
/// `workspaces/{id}.settings.qaRules` and use them to seed the per-repo
/// Edit Repository dialog. When `locked` is true, the desktop app hides the
/// per-repo QA controls and enforces these values.
class _QaRulesCard extends StatelessWidget {
  const _QaRulesCard({
    required this.checkIds,
    required this.enabled,
    required this.severity,
    required this.locked,
    required this.canEdit,
    required this.saving,
    required this.onEnabledChanged,
    required this.onSeverityChanged,
    required this.onLockedChanged,
    required this.onSave,
  });

  final List<({String id, String label})> checkIds;
  final Map<String, bool> enabled;
  final Map<String, String> severity;
  final bool locked;
  final bool canEdit;
  final bool saving;
  final void Function(String id, bool v) onEnabledChanged;
  final void Function(String id, String v) onSeverityChanged;
  final ValueChanged<bool> onLockedChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final hasValue = checkIds.any((c) => enabled[c.id] ?? true);
    return _SectionCard(
      title: 'QA rules',
      trailing: _StatusChip(_stateFor(hasValue: hasValue, locked: locked)),
      subtitle:
          'Which quality checks run on every repository, and whether a '
          'failure blocks the release (Critical) or just shows a warning. '
          'Lock to enforce these values across every member.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: const [
                SizedBox(width: 40),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Check',
                    style:
                        TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: Text(
                    'Severity',
                    style:
                        TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          for (final c in checkIds)
            _QaCheckRow(
              id: c.id,
              label: c.label,
              enabled: enabled[c.id] ?? true,
              severity: severity[c.id] ?? 'critical',
              canEdit: canEdit,
              onEnabledChanged: (v) => onEnabledChanged(c.id, v),
              onSeverityChanged: (v) => onSeverityChanged(c.id, v),
            ),
          const SizedBox(height: 4),
          _LockCheckbox(
            locked: locked,
            enabled: canEdit,
            onChanged: onLockedChanged,
          ),
          if (canEdit)
            _SaveButton(
                saving: saving, onSave: onSave, label: 'Save QA rules'),
        ],
      ),
    );
  }
}

class _QaCheckRow extends StatelessWidget {
  const _QaCheckRow({
    required this.id,
    required this.label,
    required this.enabled,
    required this.severity,
    required this.canEdit,
    required this.onEnabledChanged,
    required this.onSeverityChanged,
  });

  final String id;
  final String label;
  final bool enabled;
  final String severity;
  final bool canEdit;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String> onSeverityChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: enabled,
              onChanged:
                  canEdit ? (v) => onEnabledChanged(v ?? false) : null,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: enabled ? null : Colors.black45,
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              initialValue: severity,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'critical',
                  child: Text('Critical — blocks'),
                ),
                DropdownMenuItem(
                  value: 'warning',
                  child: Text('Warning — advisory'),
                ),
              ],
              onChanged: canEdit && enabled
                  ? (v) {
                      if (v != null) onSeverityChanged(v);
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _GithubRepoPickerDialog extends StatefulWidget {
  const _GithubRepoPickerDialog({
    required this.available,
    required this.alreadyAdded,
  });

  final List<String> available;
  final Set<String> alreadyAdded;

  @override
  State<_GithubRepoPickerDialog> createState() =>
      _GithubRepoPickerDialogState();
}

class _GithubRepoPickerDialogState extends State<_GithubRepoPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selected = <String>{};
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.available;
    return widget.available
        .where((slug) => slug.toLowerCase().contains(q))
        .toList();
  }

  Iterable<String> get _selectable =>
      _visible.where((slug) => !widget.alreadyAdded.contains(slug));

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final selectable = _selectable.toList();
    final allVisibleSelected = selectable.isNotEmpty &&
        selectable.every(_selected.contains);

    return AlertDialog(
      title: const Text('Import GitHub repositories'),
      content: SizedBox(
        width: 520,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter repositories…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: selectable.isEmpty
                      ? null
                      : () {
                          setState(() {
                            if (allVisibleSelected) {
                              _selected.removeAll(selectable);
                            } else {
                              _selected.addAll(selectable);
                            }
                          });
                        },
                  icon: Icon(allVisibleSelected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank),
                  label: Text(allVisibleSelected ? 'Clear' : 'Select all'),
                ),
                const Spacer(),
                Text(
                  '${_selected.length} selected · ${visible.length} shown',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('No matches.'))
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final slug = visible[index];
                        final alreadyAdded =
                            widget.alreadyAdded.contains(slug);
                        return CheckboxListTile(
                          dense: true,
                          value: alreadyAdded || _selected.contains(slug),
                          onChanged: alreadyAdded
                              ? null
                              : (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selected.add(slug);
                                    } else {
                                      _selected.remove(slug);
                                    }
                                  });
                                },
                          title: Text(slug),
                          subtitle:
                              alreadyAdded ? const Text('Already added') : null,
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: Text(_selected.isEmpty
              ? 'Add'
              : 'Add ${_selected.length}'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Smoke tests summary card — entry point to the full smoke-tests admin
// screen. The screen handles authoring, review/approval, and run history.
// ---------------------------------------------------------------------------

class _SmokeTestsCard extends StatelessWidget {
  const _SmokeTestsCard({required this.canEdit, required this.onOpen});

  final bool canEdit;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Smoke tests',
      subtitle:
          'Admin-authored tests that run on workspace desktops. Requires '
          'two-admin approval before desktops will execute them.',
      trailing: FilledButton.icon(
        onPressed: canEdit ? onOpen : null,
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('Open'),
      ),
      child: const Text(
        'Each test is scanned for obviously harmful patterns and must be '
        'approved by a second admin. Desktops verify the server signature '
        'before running.',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
    );
  }
}
