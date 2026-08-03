class CommandAuditEntry {
  const CommandAuditEntry({
    required this.id,
    required this.timestamp,
    required this.operatorId,
    required this.action,
    required this.toolId,
    required this.requestedValvePercent,
    required this.success,
    required this.detail,
  });

  final int id;
  final DateTime timestamp;
  final String operatorId;
  final String action;
  final int? toolId;
  final double? requestedValvePercent;
  final bool success;
  final String detail;

  factory CommandAuditEntry.fromJson(Map<String, dynamic> json) {
    return CommandAuditEntry(
      id: json['id'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      operatorId: json['operator_id'] as String,
      action: json['action'] as String,
      toolId: json['tool_id'] as int?,
      requestedValvePercent: (json['requested_valve_percent'] as num?)
          ?.toDouble(),
      success: json['success'] as bool,
      detail: json['detail'] as String,
    );
  }

  String get actionLabel {
    return switch (action) {
      'set_valve_position' => 'Set Valve Position',
      'close_valve' => 'Close Valve',
      'close_all' => 'Close All Valves',
      _ => action,
    };
  }

  String get targetLabel {
    if (toolId == null) {
      return 'All tools';
    }

    return 'Tool $toolId';
  }
}
