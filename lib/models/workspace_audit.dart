/// An immutable model representing a workspace audit record.
class WorkspaceAudit {
  final String id;
  final DateTime timestamp;
  final String user;
  final String action;

  const WorkspaceAudit({
    required this.id,
    required this.timestamp,
    required this.user,
    required this.action,
  });

  @override
  String toString() {
    return 'WorkspaceAudit(id: $id, timestamp: $timestamp, user: $user, action: $action)';
  }
}
