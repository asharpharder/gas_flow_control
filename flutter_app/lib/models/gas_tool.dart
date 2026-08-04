enum GasToolStatus {
  online,
  offline,
  fault,
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

  GasToolStatus get status {
    if (!connected) {
      return GasToolStatus.offline;
    }

    if (hasFault) {
      return GasToolStatus.fault;
    }

    return GasToolStatus.online;
  }

  bool get hasFault {
    final faultText = fault?.trim();

    return faultText != null && faultText.isNotEmpty;
  }

  bool get isOnline {
    return status == GasToolStatus.online;
  }

  bool get isOffline {
    return status == GasToolStatus.offline;
  }

  bool get valveIsOpen {
    return requestedValvePercent > 0.1 || actualValvePercent > 0.1;
  }

  double get valveDifference {
    return (requestedValvePercent - actualValvePercent).abs();
  }

  bool get valvePositionMismatch {
    return valveDifference >= 5;
  }

  double get normalizedActualValvePosition {
    return (actualValvePercent / 100).clamp(0.0, 1.0);
  }

  String get statusLabel {
    switch (status) {
      case GasToolStatus.online:
        return 'ONLINE';
      case GasToolStatus.offline:
        return 'OFFLINE';
      case GasToolStatus.fault:
        return 'FAULT';
    }
  }

  String get requestedValveLabel {
    return '${requestedValvePercent.toStringAsFixed(0)}%';
  }

  String get actualValveLabel {
    return '${actualValvePercent.toStringAsFixed(1)}%';
  }

  String get measuredFlowLabel {
    return '${measuredFlowCfh.toStringAsFixed(1)} CFH';
  }

  factory GasTool.fromJson(Map<String, dynamic> json) {
    return GasTool(
      toolId: _readInt(json, 'tool_id'),
      name: _readString(json, 'name'),
      requestedValvePercent: _readDouble(
        json,
        'requested_valve_percent',
      ).clamp(0.0, 100.0),
      actualValvePercent: _readDouble(
        json,
        'actual_valve_percent',
      ).clamp(0.0, 100.0),
      measuredFlowCfh: _readDouble(
        json,
        'measured_flow_cfh',
      ),
      connected: _readBool(json, 'connected'),
      fault: _readNullableString(json, 'fault'),
      updatedAt: _readDateTime(json, 'updated_at'),
    );
  }

  static int _readInt(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    throw FormatException(
      'Expected "$key" to be a number, but received: $value',
    );
  }

  static double _readDouble(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];

    if (value is num) {
      return value.toDouble();
    }

    throw FormatException(
      'Expected "$key" to be a number, but received: $value',
    );
  }

  static String _readString(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];

    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    throw FormatException(
      'Expected "$key" to be a non-empty string, but received: $value',
    );
  }

  static String? _readNullableString(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];

    if (value == null) {
      return null;
    }

    if (value is String) {
      final trimmedValue = value.trim();

      return trimmedValue.isEmpty ? null : trimmedValue;
    }

    throw FormatException(
      'Expected "$key" to be a string or null, but received: $value',
    );
  }

  static bool _readBool(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];

    if (value is bool) {
      return value;
    }

    throw FormatException(
      'Expected "$key" to be a boolean, but received: $value',
    );
  }

  static DateTime _readDateTime(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];

    if (value is! String) {
      throw FormatException(
        'Expected "$key" to be a date string, but received: $value',
      );
    }

    final timestamp = DateTime.tryParse(value);

    if (timestamp == null) {
      throw FormatException(
        'Unable to parse "$key" timestamp: $value',
      );
    }

    return timestamp;
  }
}
