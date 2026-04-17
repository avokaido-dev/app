import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

/// Shown after sign-in when the user doesn't yet have a `workspaceId` claim.
/// Single text field → calls the `createWorkspace` cloud function → refreshes
/// the ID token so the router switches to the workspace shell.
class CreateWorkspaceScreen extends StatefulWidget {
  const CreateWorkspaceScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  State<CreateWorkspaceScreen> createState() => _CreateWorkspaceScreenState();
}

class _CreateWorkspaceScreenState extends State<CreateWorkspaceScreen> {
  final _nameController = TextEditingController();
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      await FirebaseFunctions.instance
          .httpsCallable('createWorkspace')
          .call<Map<String, dynamic>>({'name': name});
      await widget.auth.refreshClaims();
      // Router will re-evaluate and push to /workspace.
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avokaido'),
        actions: [
          TextButton.icon(
            onPressed: widget.auth.signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create your workspace',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A workspace is where you and your team collaborate. '
                  'You can invite teammates once it exists.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Workspace name',
                    hintText: 'e.g. Acme Corp',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _create(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _creating ? null : _create,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _creating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create workspace'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
