import 'package:flutter/foundation.dart';

import '../models/workspace_audit.dart';

/// A provider for managing workspace audit trail entries.
class WorkspaceAuditProvider extends ChangeNotifier {
  final List<WorkspaceAudit> _audits = [];

  /// An unmodifiable list of workspace audits.
  List<WorkspaceAudit> get audits => List.unmodifiable(_audits);

  /// Records a new audit activity with the provided [user] and [action].
  void recordAudit({required String user, required String action}) {
    final timestamp = DateTime.now();
    final audit = WorkspaceAudit(
      id: timestamp.millisecondsSinceEpoch.toString(),
      timestamp: timestamp,
      user: user,
      action: action,
    );
    _audits.add(audit);
    notifyListeners();
  }

  /// Clears all workspace audits.
  void clearAudits() {
    _audits.clear();
    notifyListeners();
  }
}
