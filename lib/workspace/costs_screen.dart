import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

/// Admin-only dashboard: accumulated AI spend across the workspace, rolled
/// up from `workspaces/{wsId}/dailyUsage/{YYYY-MM-DD}_{uid}` documents that
/// the desktop app pushes from each member's local `AiRunTracker`.
///
/// Until the desktop sync lands this screen will render an empty state —
/// the schema and aggregation are ready to light up as data starts flowing.
class CostsScreen extends StatefulWidget {
  const CostsScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  State<CostsScreen> createState() => _CostsScreenState();
}

class _CostsScreenState extends State<CostsScreen> {
  int _windowDays = 30;

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  @override
  Widget build(BuildContext context) {
    final wsId = widget.auth.workspaceId;
    if (wsId == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final since = now.subtract(Duration(days: _windowDays - 1));
    final sinceKey = _dateKey(DateTime(since.year, since.month, since.day));

    final stream = FirebaseFirestore.instance
        .collection('workspaces')
        .doc(wsId)
        .collection('dailyUsage')
        .where('date', isGreaterThanOrEqualTo: sinceKey)
        .snapshots();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Costs',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7d')),
                  ButtonSegment(value: 30, label: Text('30d')),
                  ButtonSegment(value: 90, label: Text('90d')),
                ],
                selected: {_windowDays},
                onSelectionChanged: (s) =>
                    setState(() => _windowDays = s.first),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.auth.isOrgAdmin) ...[
            _BudgetsSection(workspaceId: wsId),
            const SizedBox(height: 16),
          ],
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return _ErrorCard(message: snap.error.toString());
              }
              final docs = snap.data?.docs ?? const [];
              if (docs.isEmpty) {
                return const _EmptyState();
              }
              final agg = _Aggregates.from(docs);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TotalsRow(agg: agg, windowDays: _windowDays),
                  const SizedBox(height: 16),
                  _ByProviderCard(agg: agg),
                  const SizedBox(height: 16),
                  _ByUserCard(agg: agg),
                  const SizedBox(height: 16),
                  _DailyTrendCard(agg: agg, windowDays: _windowDays),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Aggregation
// ---------------------------------------------------------------------------

class _Aggregates {
  _Aggregates({
    required this.totalCostUsd,
    required this.totalTokensIn,
    required this.totalTokensOut,
    required this.runCount,
    required this.byProvider,
    required this.byUser,
    required this.byDay,
  });

  final double totalCostUsd;
  final int totalTokensIn;
  final int totalTokensOut;
  final int runCount;
  final Map<String, _ProviderRow> byProvider;
  final Map<String, _UserRow> byUser;
  final Map<String, double> byDay;

  static _Aggregates from(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    double total = 0;
    int tokIn = 0;
    int tokOut = 0;
    int runs = 0;
    final providers = <String, _ProviderRow>{};
    final users = <String, _UserRow>{};
    final days = <String, double>{};

    double asDouble(Object? v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
    int asInt(Object? v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    for (final d in docs) {
      final data = d.data();
      final cost = asDouble(data['totalCostUsd']);
      final inTok = asInt(data['totalTokensIn']);
      final outTok = asInt(data['totalTokensOut']);
      final rc = asInt(data['runCount']);
      final userId = data['userId'] as String? ?? 'unknown';
      final email = data['userEmail'] as String?;
      final date = data['date'] as String? ?? '';

      total += cost;
      tokIn += inTok;
      tokOut += outTok;
      runs += rc;

      users.update(
        userId,
        (u) => u.add(cost: cost, tokensIn: inTok, tokensOut: outTok, runs: rc),
        ifAbsent: () => _UserRow(
          userId: userId,
          email: email,
          costUsd: cost,
          tokensIn: inTok,
          tokensOut: outTok,
          runCount: rc,
        ),
      );

      if (date.isNotEmpty) {
        days.update(date, (v) => v + cost, ifAbsent: () => cost);
      }

      final perProv =
          (data['byProvider'] as Map?)?.cast<String, Object?>() ?? const {};
      for (final entry in perProv.entries) {
        final v = (entry.value as Map?)?.cast<String, Object?>() ?? const {};
        providers.update(
          entry.key,
          (p) => p.add(
            cost: asDouble(v['costUsd']),
            tokensIn: asInt(v['tokensIn']),
            tokensOut: asInt(v['tokensOut']),
            runs: asInt(v['runs']),
          ),
          ifAbsent: () => _ProviderRow(
            providerId: entry.key,
            costUsd: asDouble(v['costUsd']),
            tokensIn: asInt(v['tokensIn']),
            tokensOut: asInt(v['tokensOut']),
            runCount: asInt(v['runs']),
          ),
        );
      }
    }

    return _Aggregates(
      totalCostUsd: total,
      totalTokensIn: tokIn,
      totalTokensOut: tokOut,
      runCount: runs,
      byProvider: providers,
      byUser: users,
      byDay: days,
    );
  }
}

class _ProviderRow {
  _ProviderRow({
    required this.providerId,
    required this.costUsd,
    required this.tokensIn,
    required this.tokensOut,
    required this.runCount,
  });
  final String providerId;
  double costUsd;
  int tokensIn;
  int tokensOut;
  int runCount;

  _ProviderRow add({
    required double cost,
    required int tokensIn,
    required int tokensOut,
    required int runs,
  }) {
    costUsd += cost;
    this.tokensIn += tokensIn;
    this.tokensOut += tokensOut;
    runCount += runs;
    return this;
  }
}

class _UserRow {
  _UserRow({
    required this.userId,
    required this.email,
    required this.costUsd,
    required this.tokensIn,
    required this.tokensOut,
    required this.runCount,
  });
  final String userId;
  final String? email;
  double costUsd;
  int tokensIn;
  int tokensOut;
  int runCount;

  _UserRow add({
    required double cost,
    required int tokensIn,
    required int tokensOut,
    required int runs,
  }) {
    costUsd += cost;
    this.tokensIn += tokensIn;
    this.tokensOut += tokensOut;
    runCount += runs;
    return this;
  }
}

// ---------------------------------------------------------------------------
// UI pieces
// ---------------------------------------------------------------------------

String _fmtUsd(double v) {
  if (v >= 100) return '\$${v.toStringAsFixed(0)}';
  if (v >= 10) return '\$${v.toStringAsFixed(1)}';
  return '\$${v.toStringAsFixed(2)}';
}

String _fmtInt(int v) {
  if (v < 1000) return v.toString();
  if (v < 1000000) return '${(v / 1000).toStringAsFixed(1)}k';
  return '${(v / 1000000).toStringAsFixed(1)}M';
}

String _providerLabel(String id) => switch (id) {
  'anthropic' => 'Anthropic',
  'openai' => 'OpenAI',
  'gemini' => 'Google Gemini',
  _ => id,
};

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.agg, required this.windowDays});
  final _Aggregates agg;
  final int windowDays;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total spend ($windowDays d)',
            value: _fmtUsd(agg.totalCostUsd),
            icon: Icons.payments_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Input tokens',
            value: _fmtInt(agg.totalTokensIn),
            icon: Icons.input_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Output tokens',
            value: _fmtInt(agg.totalTokensOut),
            icon: Icons.output_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Runs',
            value: _fmtInt(agg.runCount),
            icon: Icons.play_arrow_outlined,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ByProviderCard extends StatelessWidget {
  const _ByProviderCard({required this.agg});
  final _Aggregates agg;

  @override
  Widget build(BuildContext context) {
    final rows = agg.byProvider.values.toList()
      ..sort((a, b) => b.costUsd.compareTo(a.costUsd));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'By provider',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Text(
                'No provider breakdown yet.',
                style: TextStyle(color: Colors.black54),
              )
            else
              DataTable(
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('Provider')),
                  DataColumn(label: Text('Cost'), numeric: true),
                  DataColumn(label: Text('Input'), numeric: true),
                  DataColumn(label: Text('Output'), numeric: true),
                  DataColumn(label: Text('Runs'), numeric: true),
                ],
                rows: [
                  for (final p in rows)
                    DataRow(
                      cells: [
                        DataCell(Text(_providerLabel(p.providerId))),
                        DataCell(Text(_fmtUsd(p.costUsd))),
                        DataCell(Text(_fmtInt(p.tokensIn))),
                        DataCell(Text(_fmtInt(p.tokensOut))),
                        DataCell(Text(_fmtInt(p.runCount))),
                      ],
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ByUserCard extends StatelessWidget {
  const _ByUserCard({required this.agg});
  final _Aggregates agg;

  @override
  Widget build(BuildContext context) {
    final rows = agg.byUser.values.toList()
      ..sort((a, b) => b.costUsd.compareTo(a.costUsd));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'By user',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Text(
                'No per-user data yet.',
                style: TextStyle(color: Colors.black54),
              )
            else
              DataTable(
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('Member')),
                  DataColumn(label: Text('Cost'), numeric: true),
                  DataColumn(label: Text('Tokens'), numeric: true),
                  DataColumn(label: Text('Runs'), numeric: true),
                ],
                rows: [
                  for (final u in rows)
                    DataRow(
                      cells: [
                        DataCell(Text(u.email ?? u.userId)),
                        DataCell(Text(_fmtUsd(u.costUsd))),
                        DataCell(Text(_fmtInt(u.tokensIn + u.tokensOut))),
                        DataCell(Text(_fmtInt(u.runCount))),
                      ],
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DailyTrendCard extends StatelessWidget {
  const _DailyTrendCard({required this.agg, required this.windowDays});
  final _Aggregates agg;
  final int windowDays;

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final series = <MapEntry<String, double>>[];
    double maxCost = 0;
    for (var i = windowDays - 1; i >= 0; i--) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      final key = _dateKey(day);
      final v = agg.byDay[key] ?? 0;
      series.add(MapEntry(key, v));
      if (v > maxCost) maxCost = v;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Daily trend',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: maxCost <= 0
                  ? const Center(
                      child: Text(
                        'No activity in this window.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final e in series)
                          Expanded(
                            child: Tooltip(
                              message: '${e.key}: ${_fmtUsd(e.value)}',
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                child: FractionallySizedBox(
                                  heightFactor: (e.value / maxCost).clamp(
                                    0.02,
                                    1.0,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.7),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(2),
                                        topRight: Radius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  series.first.key,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                Text(
                  series.last.key,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(
              Icons.query_stats_outlined,
              size: 48,
              color: Colors.black38,
            ),
            const SizedBox(height: 12),
            const Text(
              'No usage data yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cost and token totals appear here once team members start '
              "running Avokaido on the desktop. The app pushes daily rollups "
              'to this workspace automatically.',
              style: TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cost budgets — admin-writable soft/hard limits stored at
// workspaces/{wsId}.settings.budgets and enforced client-side by every
// member's desktop app. Lives on the Costs screen so budgets sit next to the
// spend they gate.
// ---------------------------------------------------------------------------

class _BudgetsSection extends StatefulWidget {
  const _BudgetsSection({required this.workspaceId});
  final String workspaceId;

  @override
  State<_BudgetsSection> createState() => _BudgetsSectionState();
}

class _BudgetsSectionState extends State<_BudgetsSection> {
  final _dailyController = TextEditingController();
  final _monthlyController = TextEditingController();
  final _perJobController = TextEditingController();
  final _warningController = TextEditingController();
  bool _hardStop = false;
  bool _locked = false;
  bool _loaded = false;
  bool _saving = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _dailyController.dispose();
    _monthlyController.dispose();
    _perJobController.dispose();
    _warningController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _ref => FirebaseFirestore.instance
      .collection('workspaces')
      .doc(widget.workspaceId);

  void _syncFromDoc(Map<String, dynamic> data) {
    final settings =
        (data['settings'] as Map?)?.cast<String, Object?>() ?? const {};
    final budgets =
        (settings['budgets'] as Map?)?.cast<String, Object?>() ?? const {};
    _dailyController.text = _numToString(budgets['dailyLimitUsd']);
    _monthlyController.text = _numToString(budgets['monthlyLimitUsd']);
    _perJobController.text = _numToString(budgets['perJobLimitUsd']);
    _warningController.text = _numToString(budgets['warningPct']);
    _hardStop = (budgets['hardStop'] as bool?) ?? false;
    _locked = (budgets['locked'] as bool?) ?? false;
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

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      await _ref.set({
        'settings': {
          'budgets': {
            'dailyLimitUsd': _parseDouble(_dailyController.text),
            'monthlyLimitUsd': _parseDouble(_monthlyController.text),
            'perJobLimitUsd': _parseDouble(_perJobController.text),
            'warningPct': _parseDouble(_warningController.text),
            'hardStop': _hardStop,
            'locked': _locked,
          },
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _notice = 'Budgets saved.';
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        if (data != null && !_loaded) {
          _syncFromDoc(data);
          _loaded = true;
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Cost budgets',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Soft and hard spend limits enforced by each member's "
                  'desktop app. Leave a field blank for no limit.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MoneyField(
                        controller: _dailyController,
                        label: 'Daily limit (USD)',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MoneyField(
                        controller: _monthlyController,
                        label: 'Monthly limit (USD)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MoneyField(
                        controller: _perJobController,
                        label: 'Per-job limit (USD)',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MoneyField(
                        controller: _warningController,
                        label: 'Warning at % of limit',
                        suffix: '%',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _hardStop,
                  onChanged: (v) => setState(() => _hardStop = v),
                  title: const Text('Hard stop when a limit is hit'),
                  subtitle: const Text(
                    'When off, members see a warning but can continue.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _locked,
                  onChanged: (v) => setState(() => _locked = v ?? false),
                  title: const Text('Lock'),
                  subtitle: const Text(
                    'Force these budgets on every member.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                if (_notice != null) ...[
                  const SizedBox(height: 4),
                  Text(_notice!, style: const TextStyle(color: Colors.green)),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save budgets'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    required this.controller,
    required this.label,
    this.suffix,
  });
  final TextEditingController controller;
  final String label;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
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
