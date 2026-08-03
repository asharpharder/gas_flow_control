import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const apiUrl = String.fromEnvironment(
  'GAS_API_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

const apiToken = String.fromEnvironment(
  'GAS_API_TOKEN',
  defaultValue: 'local-simulation-token',
);

const operatorId = String.fromEnvironment(
  'OPERATOR_ID',
  defaultValue: 'development-operator',
);

void main() {
  runApp(const GasControlApp());
}

class GasControlApp extends StatelessWidget {
  const GasControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gas Flow Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ToolListScreen(),
    );
  }
}

class GasTool {
  const GasTool({
    required this.toolId,
    required this.name,
    required this.requestedValvePercent,
    required this.actualValvePercent,
    required this.measuredFlowCfh,
    required this.connected,
    required this.fault,
  });

  final int toolId;
  final String name;
  final double requestedValvePercent;
  final double actualValvePercent;
  final double measuredFlowCfh;
  final bool connected;
  final String? fault;

  factory GasTool.fromJson(Map<String, dynamic> json) {
    return GasTool(
      toolId: json['tool_id'] as int,
      name: json['name'] as String,
      requestedValvePercent: (json['requested_valve_percent'] as num)
          .toDouble(),
      actualValvePercent: (json['actual_valve_percent'] as num).toDouble(),
      measuredFlowCfh: (json['measured_flow_cfh'] as num).toDouble(),
      connected: json['connected'] as bool,
      fault: json['fault'] as String?,
    );
  }
}

class ToolListScreen extends StatefulWidget {
  const ToolListScreen({super.key});

  @override
  State<ToolListScreen> createState() => _ToolListScreenState();
}

class _ToolListScreenState extends State<ToolListScreen> {
  late Future<List<GasTool>> _toolsFuture;

  @override
  void initState() {
    super.initState();
    _toolsFuture = _fetchTools();
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $apiToken',
    'Content-Type': 'application/json',
  };

  Future<List<GasTool>> _fetchTools() async {
    final response = await http
        .get(Uri.parse('$apiUrl/tools'), headers: _headers)
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception(
        'Backend returned ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as List<dynamic>;

    return decoded
        .map((item) => GasTool.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _applyValvePosition(
    GasTool tool,
    double requestedPercent,
  ) async {
    final response = await http
        .post(
          Uri.parse('$apiUrl/tools/${tool.toolId}/valve'),
          headers: _headers,
          body: jsonEncode({
            'requested_valve_percent': requestedPercent,
            'operator_id': operatorId,
          }),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception(
        'Command failed with ${response.statusCode}: ${response.body}',
      );
    }

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

  void _reload() {
    setState(() {
      _toolsFuture = _fetchTools();
    });
  }

  Future<void> _refresh() async {
    final nextLoad = _fetchTools();

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
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class ToolControlCard extends StatefulWidget {
  const ToolControlCard({required this.tool, required this.onApply, super.key});

  final GasTool tool;
  final Future<void> Function(double requestedPercent) onApply;

  @override
  State<ToolControlCard> createState() => _ToolControlCardState();
}

class _ToolControlCardState extends State<ToolControlCard> {
  late double _draftPercent;
  bool _submitting = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _draftPercent = widget.tool.requestedValvePercent;
  }

  @override
  void didUpdateWidget(covariant ToolControlCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.tool.requestedValvePercent !=
        widget.tool.requestedValvePercent) {
      _draftPercent = widget.tool.requestedValvePercent;
      _dirty = false;
    }
  }

  Future<void> _apply() async {
    setState(() {
      _submitting = true;
    });

    try {
      await widget.onApply(_draftPercent);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.tool.name}: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;

    final controlsEnabled =
        tool.connected && tool.fault == null && !_submitting;

    final canApply = controlsEnabled && _dirty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tool.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Icon(
                  tool.connected ? Icons.check_circle : Icons.error,
                  color: tool.connected ? Colors.greenAccent : Colors.redAccent,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Actual valve position: '
              '${tool.actualValvePercent.toStringAsFixed(1)}%',
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: tool.actualValvePercent / 100),
            const SizedBox(height: 16),
            Text(
              'Measured flow: '
              '${tool.measuredFlowCfh.toStringAsFixed(1)} CFH',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(height: 32),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Draft valve position',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${_draftPercent.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            Slider(
              value: _draftPercent,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${_draftPercent.toStringAsFixed(0)}%',
              onChanged: controlsEnabled
                  ? (value) {
                      setState(() {
                        _draftPercent = value;
                        _dirty =
                            (value - tool.requestedValvePercent).abs() >= 0.5;
                      });
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canApply ? _apply : null,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_submitting ? 'Applying…' : 'Apply Position'),
              ),
            ),
            if (tool.fault != null) ...[
              const SizedBox(height: 12),
              Text(
                'Fault: ${tool.fault}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
