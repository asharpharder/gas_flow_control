enum GasToolStatus { normal, adjusting, warning, offline, fault }

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
    this.gasType = 'Unknown',
    this.cylinderPressurePsi = 0,
    this.targetFlowCfh = 0,
    this.minimumFlowCfh = 0,
    this.maximumFlowCfh = 0,
  });

  static const double lowPressureThresholdPsi = 500;
  static const double criticalPressureThresholdPsi = 200;

  final int toolId;
  final String name;

  final String gasType;
  final double cylinderPressurePsi;

  final double requestedValvePercent;
  final double actualValvePercent;

  final double measuredFlowCfh;
  final double targetFlowCfh;
  final double minimumFlowCfh;
  final double maximumFlowCfh;

  final bool connected;
  final String? fault;
  final DateTime updatedAt;

  bool get hasFault {
    final faultText = fault?.trim();

    return faultText != null && faultText.isNotEmpty;
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

  bool get isAdjusting {
    return connected && !hasFault && valvePositionMismatch;
  }

  bool get flowMonitoringActive {
    return valveIsOpen && targetFlowCfh > 0 && !isAdjusting;
  }

  bool get flowBelowMinimum {
    if (!flowMonitoringActive) {
      return false;
    }

    return measuredFlowCfh < minimumFlowCfh;
  }

  bool get flowAboveMaximum {
    if (!flowMonitoringActive) {
      return false;
    }

    return measuredFlowCfh > maximumFlowCfh;
  }

  bool get flowOutOfRange {
    return flowBelowMinimum || flowAboveMaximum;
  }

  bool get cylinderPressureCritical {
    return cylinderPressurePsi > 0 &&
        cylinderPressurePsi < criticalPressureThresholdPsi;
  }

  bool get cylinderPressureLow {
    return cylinderPressurePsi >= criticalPressureThresholdPsi &&
        cylinderPressurePsi <= lowPressureThresholdPsi;
  }

  bool get cylinderPressureWarning {
    return cylinderPressureLow || cylinderPressureCritical;
  }

  GasToolStatus get status {
    if (!connected) {
      return GasToolStatus.offline;
    }

    if (hasFault) {
      return GasToolStatus.fault;
    }

    if (cylinderPressureCritical) {
      return GasToolStatus.warning;
    }

    if (isAdjusting) {
      return GasToolStatus.adjusting;
    }

    if (flowOutOfRange || cylinderPressureLow) {
      return GasToolStatus.warning;
    }

    return GasToolStatus.normal;
  }

  bool get isOnline {
    return connected && !hasFault;
  }

  bool get isOffline {
    return status == GasToolStatus.offline;
  }

  bool get hasWarning {
    return status == GasToolStatus.warning;
  }

  bool get isFaulted {
    return status == GasToolStatus.fault;
  }

  bool get isNormal {
    return status == GasToolStatus.normal;
  }

  double get normalizedActualValvePosition {
    return (actualValvePercent / 100).clamp(0.0, 1.0);
  }

  String get statusLabel {
    switch (status) {
      case GasToolStatus.normal:
        return 'NORMAL';

      case GasToolStatus.adjusting:
        return 'ADJUSTING';

      case GasToolStatus.warning:
        return 'WARNING';

      case GasToolStatus.offline:
        return 'OFFLINE';

      case GasToolStatus.fault:
        return 'FAULT';
    }
  }

  String get statusDetail {
    switch (status) {
      case GasToolStatus.normal:
        return 'Operating normally';

      case GasToolStatus.adjusting:
        return 'Valve moving to commanded position';

      case GasToolStatus.warning:
        if (cylinderPressureCritical) {
          return 'Cylinder pressure critically low';
        }

        if (cylinderPressureLow) {
          return 'Cylinder pressure low';
        }

        if (flowBelowMinimum) {
          return 'Gas flow below minimum';
        }

        if (flowAboveMaximum) {
          return 'Gas flow above maximum';
        }

        return 'Tool requires attention';

      case GasToolStatus.offline:
        return 'Controller disconnected';

      case GasToolStatus.fault:
        return fault ?? 'Controller fault';
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

  String get targetFlowLabel {
    return '${targetFlowCfh.toStringAsFixed(1)} CFH';
  }

  String get flowRangeLabel {
    return '${minimumFlowCfh.toStringAsFixed(1)}–'
        '${maximumFlowCfh.toStringAsFixed(1)} CFH';
  }

  String get cylinderPressureLabel {
    return '${cylinderPressurePsi.toStringAsFixed(0)} PSI';
  }

  String get cylinderPressureStatusLabel {
    if (cylinderPressureCritical) {
      return 'CRITICAL';
    }

    if (cylinderPressureLow) {
      return 'LOW';
    }

    return 'NORMAL';
  }

  factory GasTool.fromJson(Map<String, dynamic> json) {
    return GasTool(
      toolId: _readInt(json, 'tool_id'),
      name: _readString(json, 'name'),
      gasType: _readString(json, 'gas_type'),
      cylinderPressurePsi: _readDouble(json, 'cylinder_pressure_psi'),
      requestedValvePercent: _readDouble(
        json,
        'requested_valve_percent',
      ).clamp(0.0, 100.0),
      actualValvePercent: _readDouble(
        json,
        'actual_valve_percent',
      ).clamp(0.0, 100.0),
      measuredFlowCfh: _readDouble(json, 'measured_flow_cfh'),
      targetFlowCfh: _readDouble(json, 'target_flow_cfh'),
      minimumFlowCfh: _readDouble(json, 'minimum_flow_cfh'),
      maximumFlowCfh: _readDouble(json, 'maximum_flow_cfh'),
      connected: _readBool(json, 'connected'),
      fault: _readNullableString(json, 'fault'),
      updatedAt: _readDateTime(json, 'updated_at'),
    );
  }

  static int _readInt(Map<String, dynamic> json, String key) {
    final value = json[key];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    throw FormatException(
      'Expected "$key" to be a number, '
      'but received: $value',
    );
  }

  static double _readDouble(Map<String, dynamic> json, String key) {
    final value = json[key];

    if (value is num) {
      return value.toDouble();
    }

    throw FormatException(
      'Expected "$key" to be a number, '
      'but received: $value',
    );
  }

  static String _readString(Map<String, dynamic> json, String key) {
    final value = json[key];

    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    throw FormatException(
      'Expected "$key" to be a non-empty '
      'string, but received: $value',
    );
  }

  static String? _readNullableString(Map<String, dynamic> json, String key) {
    final value = json[key];

    if (value == null) {
      return null;
    }

    if (value is String) {
      final trimmedValue = value.trim();

      return trimmedValue.isEmpty ? null : trimmedValue;
    }

    throw FormatException(
      'Expected "$key" to be a string or null, '
      'but received: $value',
    );
  }

  static bool _readBool(Map<String, dynamic> json, String key) {
    final value = json[key];

    if (value is bool) {
      return value;
    }

    throw FormatException(
      'Expected "$key" to be a boolean, '
      'but received: $value',
    );
  }

  static DateTime _readDateTime(Map<String, dynamic> json, String key) {
    final value = json[key];

    if (value is! String) {
      throw FormatException(
        'Expected "$key" to be a date string, '
        'but received: $value',
      );
    }

    final timestamp = DateTime.tryParse(value);

    if (timestamp == null) {
      throw FormatException(
        'Unable to parse "$key" timestamp: '
        '$value',
      );
    }

    return timestamp;
  }
}
