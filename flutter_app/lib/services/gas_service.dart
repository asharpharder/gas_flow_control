import '../models/command_audit_entry.dart';
import '../models/gas_tool.dart';

abstract interface class GasService {
  Future<List<GasTool>> fetchTools();

  Future<GasTool> setValvePosition({
    required int toolId,
    required double requestedPercent,
  });

  Future<GasTool> closeValve({required int toolId});

  Future<List<GasTool>> closeAll();

  Future<List<CommandAuditEntry>> fetchAuditHistory({int limit = 100});
}
