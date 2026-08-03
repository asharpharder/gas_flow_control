class GasTool {
  const GasTool({
    required this.toolId,
    required this.name,
    required this.requestedValvePercent,
    required this.actualValvePercent,
    required this.measuredFlowCfh,
    required this.connected,
    required this.fault,
    required this.updatedAt,
  });

  final int toolId;
  final String name;
  final double requestedValvePercent;
  final double actualValvePercent;
  final double measuredFlowCfh;
  final bool connected;
  final String? fault;
  final DateTime updatedAt;

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
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
