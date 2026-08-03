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
      requestedValvePercent:
          (json['requested_valve_percent'] as num).toDouble(),
      actualValvePercent:
          (json['actual_valve_percent'] as num).toDouble(),
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

  Future<List<GasTool>> _fetchTools() async {
    final response = await http.get(
      Uri.parse('$apiUrl/tools'),
      headers: {
        'Authorization': 'Bearer $apiToken',
      },
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception(
        'Backend returned ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as List<dynamic>;

    return decoded
        .map(
          (item) => GasTool.fromJson(item as Map<String, dynamic>),
        )
        .toList();
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
      // FutureBuilder displays the connection error.
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
            return const Center(
              child: CircularProgressIndicator(),
            );
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
                                style:
                                    Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Icon(
                              tool.connected
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: tool.connected
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Valve position: '
                          '${tool.actualValvePercent.toStringAsFixed(1)}%',
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: tool.actualValvePercent / 100,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Requested position: '
                          '${tool.requestedValvePercent.toStringAsFixed(1)}%',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Measured flow: '
                          '${tool.measuredFlowCfh.toStringAsFixed(1)} CFH',
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
              },
            ),
          );
        },
      ),
    );
  }
}