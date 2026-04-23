import 'package:flutter/material.dart';

import 'smoke_test_models.dart';

/// Shows the scanner findings and lets the reviewing admin approve or
/// reject. The Approve button is disabled when the current user is the
/// author — the Cloud Function enforces the same rule, this is just UX.
class SmokeTestReviewDialog extends StatefulWidget {
  const SmokeTestReviewDialog({
    super.key,
    required this.test,
    required this.currentUid,
  });

  final SmokeTest test;
  final String currentUid;

  @override
  State<SmokeTestReviewDialog> createState() => _SmokeTestReviewDialogState();
}

enum ReviewDecision { approve, reject }

typedef ReviewOutcome = ({ReviewDecision decision, String reason});

class _SmokeTestReviewDialogState extends State<SmokeTestReviewDialog> {
  final _reasonCtl = TextEditingController();

  @override
  void dispose() {
    _reasonCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.test;
    final isAuthor = t.authorUid == widget.currentUid;
    final report = t.scannerReport;

    Color riskColor(ScannerRisk r) {
      switch (r) {
        case ScannerRisk.low:
          return Colors.green.shade700;
        case ScannerRisk.medium:
          return Colors.orange.shade800;
        case ScannerRisk.high:
          return Colors.deepOrange.shade800;
        case ScannerRisk.blocked:
          return Colors.red.shade800;
      }
    }

    return AlertDialog(
      title: Text('Review: ${t.name}'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kind: ${t.kind.name}   •   Platforms: '
                '${t.platforms.map((p) => p.name).join(", ")}   •   '
                'Version: ${t.version}',
              ),
              const SizedBox(height: 6),
              Text(
                'Author UID: ${t.authorUid}'
                '${isAuthor ? "  (that is you — a different admin must review)" : ""}',
                style: TextStyle(
                  color: isAuthor ? Colors.red : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              if (report != null) ...[
                Row(
                  children: [
                    const Text(
                      'Scanner risk: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      report.risk.name.toUpperCase(),
                      style: TextStyle(
                        color: riskColor(report.risk),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (report.findings.isEmpty)
                  const Text('No findings.')
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final f in report.findings)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _sevColor(f.severity),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  f.severity,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${f.rule}'
                                      '${f.line != null ? " (line ${f.line})" : ""}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      f.match,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (f.note != null)
                                      Text(
                                        f.note!,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                const Divider(height: 24),
                const Text(
                  'The scanner is advisory. It blocks obvious high-severity '
                  'patterns but cannot certify a script as safe. Review the '
                  'script source below before approving.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
              ],
              if (t.kind == SmokeTestKind.declarative &&
                  t.declarative != null) ...[
                const Text('Command'),
                _CodeBlock(
                  text: '${t.declarative!.command} '
                      '${t.declarative!.args.join(" ")}\n'
                      'cwd: ${t.declarative!.cwd}   '
                      'timeout: ${t.declarative!.timeoutSec}s',
                ),
              ],
              if (t.kind == SmokeTestKind.bash && t.shell?.bash != null) ...[
                const Text('Bash source'),
                _CodeBlock(text: t.shell!.bash!),
              ],
              if (t.kind == SmokeTestKind.powershell &&
                  t.shell?.powershell != null) ...[
                const Text('PowerShell source'),
                _CodeBlock(text: t.shell!.powershell!),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _reasonCtl,
                decoration: const InputDecoration(
                  labelText: 'Reject reason (optional)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop((
            decision: ReviewDecision.reject,
            reason: _reasonCtl.text.trim(),
          )),
          child: const Text('Reject'),
        ),
        FilledButton(
          onPressed: isAuthor || report?.risk == ScannerRisk.blocked
              ? null
              : () => Navigator.of(context).pop((
                  decision: ReviewDecision.approve,
                  reason: '',
                )),
          child: const Text('Approve'),
        ),
      ],
    );
  }

  Color _sevColor(String severity) {
    switch (severity) {
      case 'high':
        return Colors.red.shade700;
      case 'medium':
        return Colors.orange.shade700;
      default:
        return Colors.blueGrey.shade500;
    }
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        child: SelectableText(
          text,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      );
}
