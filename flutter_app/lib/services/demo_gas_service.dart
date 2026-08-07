import 'dart:async';
import 'dart:math';

import '../models/command_audit_entry.dart';
import '../models/gas_tool.dart';
import 'gas_service.dart';

class DemoGasService implements GasService {
  DemoGasService({required this.operatorId}) {
    final now = DateTime.now();

    const gasTypes = [
      'Argon',
      'Argon',
      '75/25 Ar-CO2',
      '75/25 Ar-CO2',
      'Helium',
      'Nitrogen',
    ];

    const startingPressures = [1850.0, 1725.0, 1600.0, 1450.0, 1200.0, 950.0];

    const targetFlows = [20.0, 22.0, 25.0, 25.0, 28.0, 18.0];

    _tools.addAll(
      List.generate(6, (index) {
        final toolId = index + 1;
        final targetFlow = targetFlows[index];

        return GasTool(
          toolId: toolId,
          name: 'Welding Tool $toolId',
          gasType: gasTypes[index],
          cylinderPressurePsi: startingPressures[index],
          requestedValvePercent: 0,
          actualValvePercent: 0,
          measuredFlowCfh: 0,
          targetFlowCfh: targetFlow,
          minimumFlowCfh: max(0, targetFlow - 3),
          maximumFlowCfh: targetFlow + 3,
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
      gasType: current.gasType,
      cylinderPressurePsi: current.cylinderPressurePsi,
      requestedValvePercent: requested,
      actualValvePercent: current.actualValvePercent,
      measuredFlowCfh: current.measuredFlowCfh,
      targetFlowCfh: current.targetFlowCfh,
      minimumFlowCfh: current.minimumFlowCfh,
      maximumFlowCfh: current.maximumFlowCfh,
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
      gasType: current.gasType,
      cylinderPressurePsi: current.cylinderPressurePsi,
      requestedValvePercent: 0,
      actualValvePercent: 0,
      measuredFlowCfh: 0,
      targetFlowCfh: current.targetFlowCfh,
      minimumFlowCfh: current.minimumFlowCfh,
      maximumFlowCfh: current.maximumFlowCfh,
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
        gasType: current.gasType,
        cylinderPressurePsi: current.cylinderPressurePsi,
        requestedValvePercent: 0,
        actualValvePercent: 0,
        measuredFlowCfh: 0,
        targetFlowCfh: current.targetFlowCfh,
        minimumFlowCfh: current.minimumFlowCfh,
        maximumFlowCfh: current.maximumFlowCfh,
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

      var pressure = current.cylinderPressurePsi;

      if (flow > 0) {
        pressure = max(0.0, pressure - max(0.2, flow * 0.004));
      }

      _tools[index] = GasTool(
        toolId: current.toolId,
        name: current.name,
        gasType: current.gasType,
        cylinderPressurePsi: pressure,
        requestedValvePercent: current.requestedValvePercent,
        actualValvePercent: actual,
        measuredFlowCfh: flow,
        targetFlowCfh: current.targetFlowCfh,
        minimumFlowCfh: current.minimumFlowCfh,
        maximumFlowCfh: current.maximumFlowCfh,
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
