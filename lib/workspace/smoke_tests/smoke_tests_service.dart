import 'package:cloud_functions/cloud_functions.dart';

import 'smoke_test_models.dart';

/// Thin wrapper around the smoke-test Cloud Functions. Centralizes the
/// callable names so the UI layer stays declarative.
class SmokeTestsService {
  SmokeTestsService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<ProposeResult> propose({
    required String workspaceId,
    String? testId,
    required Map<String, dynamic> spec,
  }) async {
    final res = await _functions.httpsCallable('proposeSmokeTest').call({
      'workspaceId': workspaceId,
      if (testId != null) 'testId': testId,
      'spec': spec,
    });
    final data = (res.data as Map).cast<String, dynamic>();
    return ProposeResult(
      testId: data['testId']?.toString() ?? '',
      status: data['status']?.toString() ?? 'pending',
      version: data['version'] is int ? data['version'] as int : 1,
      scannerReport: data['scannerReport'] is Map
          ? ScannerReport.fromMap(
              (data['scannerReport'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }

  Future<void> approve({
    required String workspaceId,
    required String testId,
  }) async {
    await _functions.httpsCallable('approveSmokeTest').call({
      'workspaceId': workspaceId,
      'testId': testId,
    });
  }

  Future<void> reject({
    required String workspaceId,
    required String testId,
    String? reason,
  }) async {
    await _functions.httpsCallable('rejectSmokeTest').call({
      'workspaceId': workspaceId,
      'testId': testId,
      if (reason != null) 'reason': reason,
    });
  }

  Future<void> revoke({
    required String workspaceId,
    required String testId,
  }) async {
    await _functions.httpsCallable('revokeSmokeTest').call({
      'workspaceId': workspaceId,
      'testId': testId,
    });
  }

  Future<List<SmokeTest>> list({required String workspaceId}) async {
    final res = await _functions.httpsCallable('listSmokeTests').call({
      'workspaceId': workspaceId,
    });
    final raw = (res.data as Map).cast<String, dynamic>();
    final items = (raw['tests'] as List?) ?? const [];
    return items.map((e) {
      final m = (e as Map).cast<String, dynamic>();
      return SmokeTest.fromMap(m['id']?.toString() ?? '', m);
    }).toList();
  }
}

class ProposeResult {
  ProposeResult({
    required this.testId,
    required this.status,
    required this.version,
    this.scannerReport,
  });

  final String testId;
  final String status;
  final int version;
  final ScannerReport? scannerReport;
}
