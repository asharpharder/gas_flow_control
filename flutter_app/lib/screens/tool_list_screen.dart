import 'package:flutter/material.dart';

import '../models/gas_tool.dart';
import '../services/gas_api.dart';
import '../widgets/tool_control_card.dart';

class ToolListScreen extends StatefulWidget {
  const ToolListScreen({required this.api, super.key});

  final GasApi api;

  @override
  State<ToolListScreen> createState() => _ToolListScreenState();
}

class _ToolListScreenState extends State<ToolListScreen> {
  late Future<List<GasTool>> _toolsFuture;
  bool _closingAll = false;

  @override
  void initState() {
    super.initState();
    _toolsFuture = widget.api.fetchTools();
  }

  Future<void> _applyValvePosition(
    GasTool tool,
    double requestedPercent,
  ) async {
    await widget.api.setValvePosition(
      toolId: tool.toolId,
      requestedPercent: requestedPercent,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${tool.name}: command accepted at '
          '${requestedPercent.toStringAsFixed(0)}%',
        ),
      ),
    );

    _reload();
  }

  Future<void> _closeValve(GasTool tool) async {
    await widget.api.closeValve(toolId: tool.toolId);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${tool.name}: close command accepted')),
    );

    _reload();
  }

  Future<void> _closeAll() async {
    await widget.api.closeAll();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Close-all command accepted')));

    _reload();
  }

  Future<void> _confirmCloseAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Command all valves closed?'),
          content: const Text(
            'This sends a software close command to all six '
            'controllers. It is not a hardware emergency stop.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Command All Closed'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _closingAll = true;
    });

    try {
      await _closeAll();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _closingAll = false;
        });
      }
    }
  }

  void _reload() {
    setState(() {
      _toolsFuture = widget.api.fetchTools();
    });
  }

  Future<void> _refresh() async {
    final nextLoad = widget.api.fetchTools();

    setState(() {
      _toolsFuture = nextLoad;
    });

    try {
      await nextLoad;
    } catch (_) {
      // FutureBuilder displays connection errors.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gas Flow Control'),
        actions: [
          IconButton(
            tooltip: 'Command all valves closed',
            onPressed: _closingAll ? null : _confirmCloseAll,
            icon: _closingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.power_settings_new,
                    color: Theme.of(context).colorScheme.error,
                  ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<GasTool>>(
        future: _toolsFuture,
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
                      Icons.cloud_off,
                      size: 56,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to connect to the controller',
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
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final tools = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: tools.length,
              itemBuilder: (context, index) {
                final tool = tools[index];

                return ToolControlCard(
                  key: ValueKey(tool.toolId),
                  tool: tool,
                  onApply: (requestedPercent) {
                    return _applyValvePosition(tool, requestedPercent);
                  },
                  onClose: () {
                    return _closeValve(tool);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
