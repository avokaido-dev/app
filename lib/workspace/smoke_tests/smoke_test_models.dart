// Data classes that mirror the Firestore / Cloud Functions smoke-test shape.
// Kept deliberately simple — the source of truth lives in the Cloud
// Functions definitions (see smoke_test_scanner.ts / smoke_tests.ts).

enum SmokeTestKind { declarative, bash, powershell }

enum SmokeTestStatus { pending, approved, rejected, revoked }

enum SmokeTestPlatform { macos, linux, windows }

enum ScannerRisk { low, medium, high, blocked }

class ScannerFinding {
  ScannerFinding({
    required this.rule,
    required this.severity,
    required this.match,
    this.line,
    this.note,
  });

  final String rule;
  final String severity; // low / medium / high
  final String match;
  final int? line;
  final String? note;

  factory ScannerFinding.fromMap(Map<String, dynamic> m) => ScannerFinding(
        rule: m['rule']?.toString() ?? '',
        severity: m['severity']?.toString() ?? 'low',
        match: m['match']?.toString() ?? '',
        line: m['line'] is int ? m['line'] as int : null,
        note: m['note']?.toString(),
      );
}

class ScannerReport {
  ScannerReport({
    required this.risk,
    required this.findings,
    this.scannedAtMs,
  });

  final ScannerRisk risk;
  final List<ScannerFinding> findings;
  final int? scannedAtMs;

  factory ScannerReport.fromMap(Map<String, dynamic> m) {
    final riskStr = m['risk']?.toString() ?? 'low';
    final risk = ScannerRisk.values.firstWhere(
      (r) => r.name == riskStr,
      orElse: () => ScannerRisk.low,
    );
    final findings = (m['findings'] as List?)
            ?.cast<Map>()
            .map((e) => ScannerFinding.fromMap(e.cast<String, dynamic>()))
            .toList() ??
        const [];
    int? ms;
    final ts = m['scannedAt'];
    if (ts is int) {
      ms = ts;
    } else if (ts != null) {
      // Firestore Timestamp JSON from callable — { _seconds, _nanoseconds }
      final seconds = (ts as Map?)?['_seconds'];
      if (seconds is int) ms = seconds * 1000;
    }
    return ScannerReport(risk: risk, findings: findings, scannedAtMs: ms);
  }
}

class DeclarativeSpec {
  DeclarativeSpec({
    required this.command,
    required this.args,
    required this.cwd,
    required this.timeoutSec,
    this.expectExitCode,
    this.expectStdoutContains,
  });

  final String command;
  final List<String> args;
  final String cwd; // repo | workspace | tmp
  final int timeoutSec;
  final int? expectExitCode;
  final String? expectStdoutContains;

  Map<String, dynamic> toMap() => {
        'command': command,
        'args': args,
        'cwd': cwd,
        'timeoutSec': timeoutSec,
        'expect': {
          if (expectExitCode != null) 'exitCode': expectExitCode,
          if (expectStdoutContains != null)
            'stdoutContains': expectStdoutContains,
        },
      };

  factory DeclarativeSpec.fromMap(Map<String, dynamic> m) {
    final expect = (m['expect'] as Map?)?.cast<String, dynamic>() ?? const {};
    return DeclarativeSpec(
      command: m['command']?.toString() ?? '',
      args: (m['args'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      cwd: m['cwd']?.toString() ?? 'repo',
      timeoutSec:
          m['timeoutSec'] is int ? m['timeoutSec'] as int : 60,
      expectExitCode: expect['exitCode'] is int ? expect['exitCode'] : null,
      expectStdoutContains: expect['stdoutContains']?.toString(),
    );
  }
}

class ShellSpec {
  ShellSpec({
    required this.timeoutSec,
    required this.network,
    this.bash,
    this.powershell,
    this.allowlistHosts = const [],
  });

  final String? bash;
  final String? powershell;
  final int timeoutSec;
  final String network; // none | allowlist
  final List<String> allowlistHosts;

  Map<String, dynamic> toMap() => {
        if (bash != null) 'bash': bash,
        if (powershell != null) 'powershell': powershell,
        'timeoutSec': timeoutSec,
        'network': network,
        'allowlistHosts': allowlistHosts,
      };

  factory ShellSpec.fromMap(Map<String, dynamic> m) => ShellSpec(
        bash: m['bash']?.toString(),
        powershell: m['powershell']?.toString(),
        timeoutSec: m['timeoutSec'] is int ? m['timeoutSec'] as int : 60,
        network: m['network']?.toString() ?? 'none',
        allowlistHosts:
            (m['allowlistHosts'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
      );
}

class SmokeTest {
  SmokeTest({
    required this.id,
    required this.name,
    required this.description,
    required this.platforms,
    required this.kind,
    required this.status,
    required this.version,
    required this.authorUid,
    this.declarative,
    this.shell,
    this.scannerReport,
    this.approvedBy,
    this.rejectedBy,
    this.rejectReason,
    this.hasSignature = false,
  });

  final String id;
  final String name;
  final String description;
  final List<SmokeTestPlatform> platforms;
  final SmokeTestKind kind;
  final SmokeTestStatus status;
  final int version;
  final String authorUid;
  final DeclarativeSpec? declarative;
  final ShellSpec? shell;
  final ScannerReport? scannerReport;
  final String? approvedBy;
  final String? rejectedBy;
  final String? rejectReason;
  final bool hasSignature;

  factory SmokeTest.fromMap(String id, Map<String, dynamic> m) {
    final kindStr = m['kind']?.toString() ?? 'declarative';
    final kind = SmokeTestKind.values.firstWhere(
      (k) => k.name == kindStr,
      orElse: () => SmokeTestKind.declarative,
    );
    final statusStr = m['status']?.toString() ?? 'pending';
    final status = SmokeTestStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => SmokeTestStatus.pending,
    );
    final platforms = ((m['platforms'] as List?) ?? const [])
        .map((e) => e.toString())
        .map((p) => SmokeTestPlatform.values.firstWhere(
              (v) => v.name == p,
              orElse: () => SmokeTestPlatform.linux,
            ))
        .toSet()
        .toList();
    return SmokeTest(
      id: id,
      name: m['name']?.toString() ?? '',
      description: m['description']?.toString() ?? '',
      platforms: platforms,
      kind: kind,
      status: status,
      version: m['version'] is int ? m['version'] as int : 1,
      authorUid: m['authorUid']?.toString() ?? '',
      declarative: m['declarative'] is Map
          ? DeclarativeSpec.fromMap(
              (m['declarative'] as Map).cast<String, dynamic>(),
            )
          : null,
      shell: m['shell'] is Map
          ? ShellSpec.fromMap((m['shell'] as Map).cast<String, dynamic>())
          : null,
      scannerReport: m['scannerReport'] is Map
          ? ScannerReport.fromMap(
              (m['scannerReport'] as Map).cast<String, dynamic>(),
            )
          : null,
      approvedBy: m['approvedBy']?.toString(),
      rejectedBy: m['rejectedBy']?.toString(),
      rejectReason: m['rejectReason']?.toString(),
      hasSignature:
          m['signature'] is String && (m['signature'] as String).isNotEmpty,
    );
  }
}
