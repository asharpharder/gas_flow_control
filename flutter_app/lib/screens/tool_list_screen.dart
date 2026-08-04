import 'dart:async';

import 'package:flutter/material.dart';

import '../models/gas_tool.dart';
import '../services/gas_api.dart';
import '../widgets/tool_control_card.dart';

class ToolListScreen extends StatefulWidget {
  const ToolListScreen({
    required this.api,
    super.key,
  });

  final GasApi api;

  @override
  State<ToolListScreen> createState() => _ToolListScreenState();
}

class _ToolListScreenState extends State<ToolListScreen> {
  static const Duration _refreshInterval = Duration(seconds: 2);
  static const Duration _staleAfter = Duration(seconds: 6);

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
      final updatedTool = await widget.api.closeValve(
        toolId: tool.toolId,
      );

      _replaceTool(updatedTool);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tool.name}: close command accepted',
          ),
        ),
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
        const SnackBar(
          content: Text('Close-all command accepted'),
        ),
      );
    } catch (error) {
      _recordCommandFailure(error);
      rethrow;
    }
  }

  Future<void> _confirmCloseAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            size: 42,
            color: Theme.of(dialogContext).colorScheme.error,
          ),
          title: const Text(
            'Close all valves?',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'This sends a software close command to all six controllers.\n\n'
            'This action does not replace a physical emergency stop or '
            'manual gas shutoff.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('CANCEL'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(dialogContext).colorScheme.error,
                foregroundColor:
                    Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.power_settings_new),
              label: const Text('CLOSE ALL'),
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
        SnackBar(
          content: Text('$error'),
          backgroundColor: Colors.red,
        ),
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
        _tools.sort(
          (a, b) => a.toolId.compareTo(b.toolId),
        );
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
    final seconds = difference.inSeconds < 0
        ? 0
        : difference.inSeconds;

    if (seconds == 0) {
      return 'just now';
    }

    if (seconds == 1) {
      return '1 second ago';
    }

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
      title = 'CONNECTING';
      message = 'Waiting for the first controller response.';
    } else if (_connectionError != null) {
      color = Colors.redAccent;
      icon = Icons.cloud_off;
      title = 'CONNECTION LOST — COMMANDS DISABLED';
      message = 'Last successful update: ${_lastUpdateText()}';
    } else if (_telemetryIsStale) {
      color = Colors.orangeAccent;
      icon = Icons.warning_amber_rounded;
      title = 'TELEMETRY STALE — COMMANDS DISABLED';
      message = 'Last successful update: ${_lastUpdateText()}';
    } else {
      color = Colors.green;
      icon = Icons.cloud_done;
      title = 'CONTROLLER CONNECTED';
      message = 'Telemetry updated ${_lastUpdateText()}';
    }

    return Semantics(
      liveRegion: true,
      label: '$title. $message',
      child: Container(
        width: double.infinity,
        color: color.withValues(alpha: 0.18),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolBody() {
    if (_initialLoading && _tools.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_tools.isEmpty && _connectionError != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 64,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to connect to the controller',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SelectableText(
                _connectionError!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _requestInProgress
                      ? null
                      : () {
                          unawaited(_loadTools());
                        },
                  icon: const Icon(Icons.refresh),
                  label: const Text('TRY AGAIN'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_tools.isEmpty) {
      return const Center(
        child: Text(
          'No welding tools were found.',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTools,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          12,
          12,
          12,
          20,
        ),
        itemCount: _tools.length,
        itemBuilder: (context, index) {
          final tool = _tools[index];

          return ToolControlCard(
            key: ValueKey(
              '${tool.toolId}-$_cardResetVersion',
            ),
            tool: tool,
            commandsEnabled: _commandsEnabled,
            commandsDisabledReason: _commandsDisabledReason,
            onApply: (requestedPercent) {
              return _applyValvePosition(
                tool,
                requestedPercent,
              );
            },
            onClose: () {
              return _closeValve(tool);
            },
          );
        },
      ),
    );
  }

  Widget _buildCloseAllButton() {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          12,
          10,
          12,
          12,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              offset: Offset(0, -2),
              color: Color(0x22000000),
            ),
          ],
        ),
        child: SizedBox(
          height: 58,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              disabledBackgroundColor:
                  colorScheme.error.withValues(alpha: 0.25),
              disabledForegroundColor:
                  colorScheme.onSurface.withValues(alpha: 0.45),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _commandsEnabled
                ? _confirmCloseAll
                : null,
            icon: _closingAll
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.power_settings_new,
                    size: 26,
                  ),
            label: Text(
              _closingAll
                  ? 'CLOSING ALL VALVES...'
                  : 'CLOSE ALL VALVES',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gas Flow Control',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh controller telemetry',
            onPressed: _requestInProgress
                ? null
                : () {
                    unawaited(_loadTools());
                  },
            icon: _requestInProgress
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildConnectionBanner(),
          Expanded(
            child: _buildToolBody(),
          ),
          _buildCloseAllButton(),
        ],
      ),
    );
  }
}
