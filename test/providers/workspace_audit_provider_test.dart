import 'package:flutter_test/flutter_test.dart';

import 'package:avokaido_app/providers/workspace_audit_provider.dart';

void main() {
  group('WorkspaceAuditProvider', () {
    late WorkspaceAuditProvider provider;

    setUp(() {
      provider = WorkspaceAuditProvider();
    });

    test('initial audits list is empty', () {
      expect(provider.audits, isEmpty);
    });

    test('recordAudit adds an audit', () {
      const user = 'test_user';
      const action = 'created document';
      provider.recordAudit(user: user, action: action);
      expect(provider.audits.length, 1);
      final audit = provider.audits.first;
      expect(audit.user, user);
      expect(audit.action, action);
      // Check that audit id is not empty and timestamp is close to now
      expect(audit.id.isNotEmpty, isTrue);
      expect(
        audit.timestamp.difference(DateTime.now()).inSeconds.abs(),
        lessThan(2),
      );
    });

    test('clearAudits clears all audits', () {
      provider.recordAudit(user: 'user1', action: 'action1');
      provider.recordAudit(user: 'user2', action: 'action2');
      expect(provider.audits.length, 2);
      provider.clearAudits();
      expect(provider.audits, isEmpty);
    });
  });
}
