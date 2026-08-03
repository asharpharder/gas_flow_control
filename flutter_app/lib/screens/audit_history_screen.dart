import 'package:flutter/material.dart';

import '../models/command_audit_entry.dart';
import '../services/gas_api.dart';

class AuditHistoryScreen extends StatefulWidget {
  const AuditHistoryScreen({required this.api, super.key});

  final GasApi api;

  @override
  State<AuditHistoryScreen> createState() => _AuditHistoryScreenState();
}

class _AuditHistoryScreenState extends State<AuditHistoryScreen> {
  late Future<List<CommandAuditEntry>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = widget.api.fetchAuditHistory();
  }

  Future<void> _refresh() async {
    final nextLoad = widget.api.fetchAuditHistory();

    setState(() {
      _historyFuture = nextLoad;
    });

    try {
      await nextLoad;
    } catch (_) {
      // FutureBuilder displays the error.
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${local.year}-'
        '${twoDigits(local.month)}-'
        '${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}:'
        '${twoDigits(local.second)}';
  }

  Widget _buildEntry(CommandAuditEntry entry) {
    final statusColor = entry.success ? Colors.greenAccent : Colors.redAccent;

    return Card(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              entry.success ? Icons.check_circle : Icons.error,
              color: statusColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.actionLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(entry.targetLabel),
                  Text('Operator: ${entry.operatorId}'),
                  if (entry.requestedValvePercent != null)
                    Text(
                      'Requested position: '
                      '${entry.requestedValvePercent!.toStringAsFixed(0)}%',
                    ),
                  Text(
                    'Time: '
                    '${_formatTimestamp(entry.timestamp)}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.detail,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              entry.success ? 'SUCCESS' : 'FAILED',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
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
        title: const Text('Command History'),
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<CommandAuditEntry>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.history_toggle_off,
                      size: 56,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load command history',
                      style: TextStyle(fontSize: 20),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final entries = snapshot.data ?? [];

          if (entries.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 140),
                  Icon(Icons.history, size: 56),
                  SizedBox(height: 16),
                  Text(
                    'No commands have been recorded.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                return _buildEntry(entries[index]);
              },
            ),
          );
        },
      ),
    );
  }
}
