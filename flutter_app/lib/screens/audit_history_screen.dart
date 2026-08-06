import 'package:flutter/material.dart';

import '../models/command_audit_entry.dart';
import '../services/gas_service.dart';

class AuditHistoryScreen extends StatefulWidget {
  const AuditHistoryScreen({required this.api, super.key});

  final GasService api;

  @override
  State<AuditHistoryScreen> createState() => _AuditHistoryScreenState();
}

class _AuditHistoryScreenState extends State<AuditHistoryScreen> {
  late Future<List<CommandAuditEntry>> _historyFuture;

  bool _refreshing = false;
  bool _showFailuresOnly = false;

  @override
  void initState() {
    super.initState();
    _historyFuture = widget.api.fetchAuditHistory();
  }

  Future<void> _refresh() async {
    if (_refreshing) {
      return;
    }

    setState(() {
      _refreshing = true;
    });

    final nextLoad = widget.api.fetchAuditHistory();

    setState(() {
      _historyFuture = nextLoad;
    });

    try {
      await nextLoad;
    } catch (_) {
      // FutureBuilder displays the error.
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    final hour = local.hour;
    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;

    final period = hour >= 12 ? 'PM' : 'AM';

    return '${local.month}/${local.day}/${local.year} '
        '${twoDigits(displayHour)}:'
        '${twoDigits(local.minute)}:'
        '${twoDigits(local.second)} $period';
  }

  String _summaryText(List<CommandAuditEntry> entries) {
    final successful = entries.where((entry) => entry.success).length;
    final failed = entries.length - successful;

    return '${entries.length} commands • '
        '$successful successful • '
        '$failed failed';
  }

  List<CommandAuditEntry> _filteredEntries(List<CommandAuditEntry> entries) {
    if (!_showFailuresOnly) {
      return entries;
    }

    return entries.where((entry) => !entry.success).toList();
  }

  Widget _buildStatusBadge(CommandAuditEntry entry) {
    final color = entry.success ? Colors.green : Colors.redAccent;
    final text = entry.success ? 'SUCCESS' : 'FAILED';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntry(CommandAuditEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = entry.success ? Colors.green : Colors.redAccent;

    return Card(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: statusColor.withValues(alpha: 0.08),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  entry.success ? Icons.check_circle : Icons.error_rounded,
                  color: statusColor,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.actionLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(entry),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  icon: Icons.precision_manufacturing,
                  label: 'Target',
                  value: entry.targetLabel,
                ),
                _buildDetailRow(
                  icon: Icons.person_outline,
                  label: 'Operator',
                  value: entry.operatorId,
                ),
                if (entry.requestedValvePercent != null)
                  _buildDetailRow(
                    icon: Icons.tune,
                    label: 'Setpoint',
                    value:
                        '${entry.requestedValvePercent!.toStringAsFixed(0)}%',
                  ),
                _buildDetailRow(
                  icon: Icons.schedule,
                  label: 'Time',
                  value: _formatTimestamp(entry.timestamp),
                ),
                const Divider(height: 22),
                Text(
                  'DETAIL',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  entry.detail,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(List<CommandAuditEntry> entries) {
    final filteredEntries = _filteredEntries(entries);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _summaryText(entries),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilterChip(
                  selected: !_showFailuresOnly,
                  label: const Text('All Commands'),
                  avatar: const Icon(Icons.list_alt, size: 18),
                  onSelected: (_) {
                    setState(() {
                      _showFailuresOnly = false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilterChip(
                  selected: _showFailuresOnly,
                  label: const Text('Failures Only'),
                  avatar: const Icon(Icons.error_outline, size: 18),
                  onSelected: (_) {
                    setState(() {
                      _showFailuresOnly = true;
                    });
                  },
                ),
              ),
            ],
          ),
          if (_showFailuresOnly) ...[
            const SizedBox(height: 8),
            Text(
              '${filteredEntries.length} failed commands shown',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState({required String message, required IconData icon}) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 130),
          Icon(icon, size: 64),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Pull down to refresh.', textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<CommandAuditEntry> entries) {
    final filteredEntries = _filteredEntries(entries);

    if (entries.isEmpty) {
      return _buildEmptyState(
        message: 'No commands have been recorded.',
        icon: Icons.history,
      );
    }

    if (filteredEntries.isEmpty) {
      return Column(
        children: [
          _buildSummaryHeader(entries),
          Expanded(
            child: _buildEmptyState(
              message: 'No failed commands were found.',
              icon: Icons.check_circle_outline,
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: filteredEntries.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildSummaryHeader(entries);
          }

          return _buildEntry(filteredEntries[index - 1]);
        },
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.history_toggle_off,
              size: 64,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load command history',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SelectableText('$error', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _refreshing ? null : _refresh,
                icon: _refreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('TRY AGAIN'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Command History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh command history',
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<CommandAuditEntry>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error!);
          }

          final entries = snapshot.data ?? [];

          return _buildHistoryList(entries);
        },
      ),
    );
  }
}
