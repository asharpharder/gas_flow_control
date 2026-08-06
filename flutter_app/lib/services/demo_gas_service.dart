import 'dart:async';
import 'dart:math';

import '../models/command_audit_entry.dart';
import '../models/gas_tool.dart';
import 'gas_service.dart';

class DemoGasService implements GasService {
  DemoGasService({required this.operatorId}) {
    final now = DateTime.now();

    _tools.addAll(
      List.generate(6, (index) {
        final toolId = index + 1;

        return GasTool(
          toolId: toolId,
          name: 'Welding Tool $toolId',
          requestedValvePercent: 0,
          actualValvePercent: 0,
          measuredFlowCfh: 0,
          connected: true,
          fault: null,
          updatedAt: now,
        );
      }),
    );
  }

  final String operatorId;

  final List<GasTool> _tools = [];
  final List<CommandAuditEntry> _history = [];

  final Random _random = Random();

  int _nextAuditId = 1;

  static const Duration _simulatedDelay = Duration(milliseconds: 250);

  @override
  Future<List<GasTool>> fetchTools() async {
    await Future<void>.delayed(_simulatedDelay);

    _advanceSimulation();

    return List<GasTool>.unmodifiable(_tools);
  }

  @override
  Future<GasTool> setValvePosition({
    required int toolId,
    required double requestedPercent,
  }) async {
    await Future<void>.delayed(_simulatedDelay);

    final index = _findToolIndex(toolId);
    final current = _tools[index];
    final requested = requestedPercent.clamp(0.0, 100.0);
    final now = DateTime.now();

    final updated = GasTool(
      toolId: current.toolId,
      name: current.name,
      requestedValvePercent: requested,
      actualValvePercent: current.actualValvePercent,
      measuredFlowCfh: current.measuredFlowCfh,
      connected: current.connected,
      fault: current.fault,
      updatedAt: now,
    );

    _tools[index] = updated;

    _recordAudit(
      action: 'set_valve_position',
      toolId: toolId,
      requestedValvePercent: requested,
      detail: 'Demo valve-position command accepted.',
    );

    return updated;
  }

  @override
  Future<GasTool> closeValve({required int toolId}) async {
    await Future<void>.delayed(_simulatedDelay);

    final index = _findToolIndex(toolId);
    final current = _tools[index];
    final now = DateTime.now();

    final updated = GasTool(
      toolId: current.toolId,
      name: current.name,
      requestedValvePercent: 0,
      actualValvePercent: 0,
      measuredFlowCfh: 0,
      connected: current.connected,
      fault: current.fault,
      updatedAt: now,
    );

    _tools[index] = updated;

    _recordAudit(
      action: 'close_valve',
      toolId: toolId,
      requestedValvePercent: 0,
      detail: 'Demo valve-close command accepted.',
    );

    return updated;
  }

  @override
  Future<List<GasTool>> closeAll() async {
    await Future<void>.delayed(_simulatedDelay);

    final now = DateTime.now();

    for (var index = 0; index < _tools.length; index++) {
      final current = _tools[index];

      _tools[index] = GasTool(
        toolId: current.toolId,
        name: current.name,
        requestedValvePercent: 0,
        actualValvePercent: 0,
        measuredFlowCfh: 0,
        connected: current.connected,
        fault: current.fault,
        updatedAt: now,
      );
    }

    _recordAudit(
      action: 'close_all',
      toolId: null,
      requestedValvePercent: 0,
      detail: 'All demo valves commanded closed.',
    );

    return List<GasTool>.unmodifiable(_tools);
  }

  @override
  Future<List<CommandAuditEntry>> fetchAuditHistory({int limit = 100}) async {
    await Future<void>.delayed(_simulatedDelay);

    return List<CommandAuditEntry>.unmodifiable(_history.take(limit).toList());
  }

  int _findToolIndex(int toolId) {
    final index = _tools.indexWhere((tool) => tool.toolId == toolId);

    if (index < 0) {
      throw StateError('Demo tool $toolId was not found.');
    }

    return index;
  }

  void _advanceSimulation() {
    final now = DateTime.now();

    for (var index = 0; index < _tools.length; index++) {
      final current = _tools[index];

      final difference =
          current.requestedValvePercent - current.actualValvePercent;

      final movement = difference.abs() <= 3 ? difference : difference.sign * 3;

      final actual = (current.actualValvePercent + movement).clamp(0.0, 100.0);

      final baseFlow = actual * 0.62;
      final variation = actual <= 0 ? 0.0 : (_random.nextDouble() - 0.5) * 0.8;

      final flow = max(0.0, baseFlow + variation);

      _tools[index] = GasTool(
        toolId: current.toolId,
        name: current.name,
        requestedValvePercent: current.requestedValvePercent,
        actualValvePercent: actual,
        measuredFlowCfh: flow,
        connected: current.connected,
        fault: current.fault,
        updatedAt: now,
      );
    }
  }

  void _recordAudit({
    required String action,
    required int? toolId,
    required double? requestedValvePercent,
    required String detail,
  }) {
    _history.insert(
      0,
      CommandAuditEntry(
        id: _nextAuditId++,
        timestamp: DateTime.now(),
        operatorId: operatorId,
        action: action,
        toolId: toolId,
        requestedValvePercent: requestedValvePercent,
        success: true,
        detail: detail,
      ),
    );
  }
}
