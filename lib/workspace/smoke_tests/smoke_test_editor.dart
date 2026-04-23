import 'package:flutter/material.dart';

import 'smoke_test_models.dart';

/// Dialog for authoring a new smoke test or editing an existing one.
/// Editing a test bumps its version and resets approval status to pending —
/// the Cloud Function enforces that.
class SmokeTestEditor extends StatefulWidget {
  const SmokeTestEditor({super.key, this.initial});
  final SmokeTest? initial;

  @override
  State<SmokeTestEditor> createState() => _SmokeTestEditorState();
}

class _SmokeTestEditorState extends State<SmokeTestEditor> {
  late SmokeTestKind _kind;
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _commandCtl = TextEditingController();
  final _argsCtl = TextEditingController();
  final _bashCtl = TextEditingController();
  final _psCtl = TextEditingController();
  final _timeoutCtl = TextEditingController(text: '60');
  final _allowlistCtl = TextEditingController();
  String _cwd = 'repo';
  String _network = 'none';
  final Set<SmokeTestPlatform> _platforms = {};

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t != null) {
      _kind = t.kind;
      _nameCtl.text = t.name;
      _descCtl.text = t.description;
      _platforms.addAll(t.platforms);
      if (t.declarative != null) {
        _commandCtl.text = t.declarative!.command;
        _argsCtl.text = t.declarative!.args.join(' ');
        _cwd = t.declarative!.cwd;
        _timeoutCtl.text = t.declarative!.timeoutSec.toString();
      }
      if (t.shell != null) {
        _bashCtl.text = t.shell!.bash ?? '';
        _psCtl.text = t.shell!.powershell ?? '';
        _timeoutCtl.text = t.shell!.timeoutSec.toString();
        _network = t.shell!.network;
        _allowlistCtl.text = t.shell!.allowlistHosts.join(', ');
      }
    } else {
      _kind = SmokeTestKind.declarative;
      _platforms.addAll(SmokeTestPlatform.values);
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    _commandCtl.dispose();
    _argsCtl.dispose();
    _bashCtl.dispose();
    _psCtl.dispose();
    _timeoutCtl.dispose();
    _allowlistCtl.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _buildSpec() {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) return null;
    final timeout = int.tryParse(_timeoutCtl.text.trim()) ?? 60;

    final spec = <String, dynamic>{
      'name': name,
      'description': _descCtl.text.trim(),
      'platforms': _platforms.map((p) => p.name).toList(),
      'kind': _kind.name,
    };

    if (_kind == SmokeTestKind.declarative) {
      spec['declarative'] = {
        'command': _commandCtl.text.trim(),
        'args': _argsCtl.text.trim().isEmpty
            ? <String>[]
            : _argsCtl.text.trim().split(RegExp(r'\s+')),
        'cwd': _cwd,
        'timeoutSec': timeout,
        'expect': <String, dynamic>{},
      };
    } else {
      final hosts = _allowlistCtl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      spec['shell'] = {
        if (_kind == SmokeTestKind.bash) 'bash': _bashCtl.text,
        if (_kind == SmokeTestKind.powershell) 'powershell': _psCtl.text,
        'timeoutSec': timeout,
        'network': _network,
        'allowlistHosts': hosts,
      };
    }
    return spec;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'New smoke test' : 'Edit smoke test'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const Text('Platforms'),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in SmokeTestPlatform.values)
                    FilterChip(
                      label: Text(p.name),
                      selected: _platforms.contains(p),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _platforms.add(p);
                        } else {
                          _platforms.remove(p);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Kind'),
              SegmentedButton<SmokeTestKind>(
                segments: const [
                  ButtonSegment(
                    value: SmokeTestKind.declarative,
                    label: Text('Declarative'),
                  ),
                  ButtonSegment(
                    value: SmokeTestKind.bash,
                    label: Text('Bash'),
                  ),
                  ButtonSegment(
                    value: SmokeTestKind.powershell,
                    label: Text('PowerShell'),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 16),
              if (_kind == SmokeTestKind.declarative) ..._declarativeFields(),
              if (_kind == SmokeTestKind.bash) ..._bashFields(),
              if (_kind == SmokeTestKind.powershell) ..._powershellFields(),
              const SizedBox(height: 12),
              TextField(
                controller: _timeoutCtl,
                decoration:
                    const InputDecoration(labelText: 'Timeout (seconds)'),
                keyboardType: TextInputType.number,
              ),
              if (_kind != SmokeTestKind.declarative) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _network,
                  decoration: const InputDecoration(labelText: 'Network'),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('None')),
                    DropdownMenuItem(
                      value: 'allowlist',
                      child: Text('Allowlist'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _network = v ?? 'none'),
                ),
                if (_network == 'allowlist')
                  TextField(
                    controller: _allowlistCtl,
                    decoration: const InputDecoration(
                      labelText: 'Allowed hosts (comma-separated)',
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Note: after save, a different workspace admin must review '
                'and approve the test before desktops will run it.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final spec = _buildSpec();
            if (spec == null) return;
            Navigator.of(context).pop(spec);
          },
          child: const Text('Save & submit for review'),
        ),
      ],
    );
  }

  List<Widget> _declarativeFields() => [
        TextField(
          controller: _commandCtl,
          decoration: const InputDecoration(
            labelText: 'Command (from allowlist)',
            helperText:
                'flutter_analyze, flutter_test, dart_test, git_status, ...',
          ),
        ),
        TextField(
          controller: _argsCtl,
          decoration: const InputDecoration(
            labelText: 'Arguments (space-separated)',
          ),
        ),
        DropdownButtonFormField<String>(
          value: _cwd,
          decoration: const InputDecoration(labelText: 'Working directory'),
          items: const [
            DropdownMenuItem(value: 'repo', child: Text('repo')),
            DropdownMenuItem(value: 'workspace', child: Text('workspace')),
            DropdownMenuItem(value: 'tmp', child: Text('tmp')),
          ],
          onChanged: (v) => setState(() => _cwd = v ?? 'repo'),
        ),
      ];

  List<Widget> _bashFields() => [
        TextField(
          controller: _bashCtl,
          decoration: const InputDecoration(
            labelText: 'Bash script',
            alignLabelWithHint: true,
          ),
          minLines: 8,
          maxLines: 20,
        ),
      ];

  List<Widget> _powershellFields() => [
        TextField(
          controller: _psCtl,
          decoration: const InputDecoration(
            labelText: 'PowerShell script',
            alignLabelWithHint: true,
          ),
          minLines: 8,
          maxLines: 20,
        ),
      ];
}
