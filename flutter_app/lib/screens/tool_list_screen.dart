import 'dart:async';

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
  static const _refreshInterval = Duration(seconds: 2);
  static const _staleAfter = Duration(seconds: 6);

  final List<GasTool> _tools = [];

  Timer? _refreshTimer;
  DateTime? _lastSuccessfulRefresh;
  DateTime _now = DateTime.now();

  String? _connectionError;

  bool _initialLoading = true;
  bool _requestInProgress = false;
  bool _closingAll = false;

  int _cardResetVersion = 0;

  bool get _telemetryIsStale {
    final lastRefresh = _lastSuccessfulRefresh;

    if (lastRefresh == null) {
      return true;
    }

    return _now.difference(lastRefresh) > _staleAfter;
  }

  bool get _commandsEnabled {
    return !_initialLoading &&
        _connectionError == null &&
        !_telemetryIsStale &&
        !_closingAll;
  }

  String get _commandsDisabledReason {
    if (_closingAll) {
      return 'A close-all command is currently being processed.';
    }

    if (_initialLoading) {
      return 'Waiting for controller telemetry.';
    }

    if (_connectionError != null) {
      return 'Communication with the controller was lost.';
    }

    if (_telemetryIsStale) {
      return 'Controller telemetry is stale.';
    }

    return 'Commands are currently unavailable.';
  }

  @override
  void initState() {
    super.initState();

    unawaited(_loadTools());

    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _now = DateTime.now();
      });

      unawaited(_loadTools());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTools() async {
    if (_requestInProgress) {
      return;
    }

    setState(() {
      _requestInProgress = true;
    });

    try {
      final tools = await widget.api.fetchTools();
      final receivedAt = DateTime.now();

      if (!mounted) {
        return;
      }

      setState(() {
        _tools
          ..clear()
          ..addAll(tools);

        _lastSuccessfulRefresh = receivedAt;
        _now = receivedAt;
        _connectionError = null;
        _initialLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _now = DateTime.now();
        _connectionError = '$error';
        _initialLoading = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _requestInProgress = false;
        });
      }
    }
  }

  Future<void> _applyValvePosition(
    GasTool tool,
    double requestedPercent,
  ) async {
    if (!_commandsEnabled) {
      throw StateError(_commandsDisabledReason);
    }

    try {
      final updatedTool = await widget.api.setValvePosition(
        toolId: tool.toolId,
        requestedPercent: requestedPercent,
      );

      _replaceTool(updatedTool);

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
    } catch (error) {
      _recordCommandFailure(error);
      rethrow;
    }
  }

  Future<void> _closeValve(GasTool tool) async {
    if (!_commandsEnabled) {
      throw StateError(_commandsDisabledReason);
    }

    try {
      final updatedTool = await widget.api.closeValve(toolId: tool.toolId);

      _replaceTool(updatedTool);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tool.name}: close command accepted')),
      );
    } catch (error) {
      _recordCommandFailure(error);
      rethrow;
    }
  }

  Future<void> _closeAll() async {
    try {
      final updatedTools = await widget.api.closeAll();
      final receivedAt = DateTime.now();

      if (!mounted) {
        return;
      }

      setState(() {
        _tools
          ..clear()
          ..addAll(updatedTools);

        _lastSuccessfulRefresh = receivedAt;
        _now = receivedAt;
        _connectionError = null;
        _cardResetVersion++;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Close-all command accepted')),
      );
    } catch (error) {
      _recordCommandFailure(error);
      rethrow;
    }
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

    if (!_commandsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_commandsDisabledReason),
          backgroundColor: Colors.red,
        ),
      );
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

  void _replaceTool(GasTool updatedTool) {
    if (!mounted) {
      return;
    }

    final receivedAt = DateTime.now();

    setState(() {
      final index = _tools.indexWhere(
        (tool) => tool.toolId == updatedTool.toolId,
      );

      if (index >= 0) {
        _tools[index] = updatedTool;
      } else {
        _tools.add(updatedTool);
        _tools.sort((a, b) => a.toolId.compareTo(b.toolId));
      }

      _lastSuccessfulRefresh = receivedAt;
      _now = receivedAt;
      _connectionError = null;
    });
  }

  void _recordCommandFailure(Object error) {
    if (!mounted) {
      return;
    }

    setState(() {
      _now = DateTime.now();
      _connectionError = '$error';
    });
  }

  String _lastUpdateText() {
    final lastRefresh = _lastSuccessfulRefresh;

    if (lastRefresh == null) {
      return 'never';
    }

    final difference = _now.difference(lastRefresh);
    final seconds = difference.inSeconds < 0 ? 0 : difference.inSeconds;

    return '$seconds seconds ago';
  }

  Widget _buildConnectionBanner() {
    late final Color color;
    late final IconData icon;
    late final String title;
    late final String message;

    if (_initialLoading) {
      color = Colors.orange;
      icon = Icons.sync;
      title = 'Connecting';
      message = 'Waiting for the first controller response.';
    } else if (_connectionError != null) {
      color = Colors.redAccent;
      icon = Icons.cloud_off;
      title = 'Connection Lost — Commands Disabled';
      message = 'Last successful update: ${_lastUpdateText()}';
    } else if (_telemetryIsStale) {
      color = Colors.orangeAccent;
      icon = Icons.warning_amber;
      title = 'Telemetry Stale — Commands Disabled';
      message = 'Last successful update: ${_lastUpdateText()}';
    } else {
      color = Colors.green;
      icon = Icons.cloud_done;
      title = 'Controller Connected';
      message = 'Telemetry updated ${_lastUpdateText()}';
    }

    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolBody() {
    if (_initialLoading && _tools.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tools.isEmpty && _connectionError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text(
                'Unable to connect to the controller',
                style: TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SelectableText(_connectionError!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _requestInProgress
                    ? null
                    : () {
                        unawaited(_loadTools());
                      },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_tools.isEmpty) {
      return const Center(child: Text('No welding tools were found.'));
    }

    return RefreshIndicator(
      onRefresh: _loadTools,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _tools.length,
        itemBuilder: (context, index) {
          final tool = _tools[index];

          return ToolControlCard(
            key: ValueKey('${tool.toolId}-$_cardResetVersion'),
            tool: tool,
            commandsEnabled: _commandsEnabled,
            commandsDisabledReason: _commandsDisabledReason,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gas Flow Control'),
        actions: [
          IconButton(
            tooltip: 'Command all valves closed',
            onPressed: _commandsEnabled ? _confirmCloseAll : null,
            icon: _closingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.power_settings_new,
                    color: _commandsEnabled
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _requestInProgress
                ? null
                : () {
                    unawaited(_loadTools());
                  },
            icon: _requestInProgress
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildConnectionBanner(),
          Expanded(child: _buildToolBody()),
        ],
      ),
    );
  }
}
