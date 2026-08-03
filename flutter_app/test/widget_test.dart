import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';

void main() {
  test('GasTool parses backend telemetry', () {
    final tool = GasTool.fromJson({
      'tool_id': 1,
      'name': 'Welding Tool 1',
      'requested_valve_percent': 25,
      'actual_valve_percent': 24.5,
      'measured_flow_cfh': 18.2,
      'connected': true,
      'fault': null,
    });

    expect(tool.toolId, 1);
    expect(tool.name, 'Welding Tool 1');
    expect(tool.requestedValvePercent, 25);
    expect(tool.actualValvePercent, 24.5);
    expect(tool.measuredFlowCfh, 18.2);
    expect(tool.connected, isTrue);
    expect(tool.fault, isNull);
  });
}