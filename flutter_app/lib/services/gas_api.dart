import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/command_audit_entry.dart';
import '../models/gas_tool.dart';
import 'gas_service.dart';

class GasApi implements GasService {
  const GasApi({
    required this.baseUrl,
    required this.token,
    required this.operatorId,
  });

  final String baseUrl;
  final String token;
  final String operatorId;

  static const requestTimeout = Duration(seconds: 5);

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Uri _uri(String path) {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    return Uri.parse('$normalizedBaseUrl$path');
  }

  @override
  Future<List<GasTool>> fetchTools() async {
    final response = await http
        .get(_uri('/tools'), headers: _headers)
        .timeout(requestTimeout);

    _requireSuccess(response, 'Load tools');

    return _decodeToolList(response.body);
  }

  @override
  Future<GasTool> setValvePosition({
    required int toolId,
    required double requestedPercent,
  }) async {
    final response = await http
        .post(
          _uri('/tools/$toolId/valve'),
          headers: _headers,
          body: jsonEncode({
            'requested_valve_percent': requestedPercent,
            'operator_id': operatorId,
          }),
        )
        .timeout(requestTimeout);

    _requireSuccess(response, 'Set valve position');

    return _decodeTool(response.body);
  }

  @override
  Future<GasTool> closeValve({required int toolId}) async {
    final response = await http
        .post(
          _uri('/tools/$toolId/close'),
          headers: _headers,
          body: jsonEncode({'operator_id': operatorId}),
        )
        .timeout(requestTimeout);

    _requireSuccess(response, 'Close valve');

    return _decodeTool(response.body);
  }

  @override
  Future<List<GasTool>> closeAll() async {
    final response = await http
        .post(
          _uri('/close-all'),
          headers: _headers,
          body: jsonEncode({'operator_id': operatorId}),
        )
        .timeout(requestTimeout);

    _requireSuccess(response, 'Close all valves');

    return _decodeToolList(response.body);
  }

  @override
  Future<List<CommandAuditEntry>> fetchAuditHistory({int limit = 100}) async {
    final auditUri = _uri(
      '/audit',
    ).replace(queryParameters: {'limit': '$limit'});

    final response = await http
        .get(auditUri, headers: _headers)
        .timeout(requestTimeout);

    _requireSuccess(response, 'Load command history');

    return _decodeAuditList(response.body);
  }

  GasTool _decodeTool(String responseBody) {
    final decoded = jsonDecode(responseBody);

    if (decoded is! Map) {
      throw const FormatException('Expected a tool object from the backend.');
    }

    return GasTool.fromJson(Map<String, dynamic>.from(decoded));
  }

  List<GasTool> _decodeToolList(String responseBody) {
    final decoded = jsonDecode(responseBody);

    if (decoded is! List) {
      throw const FormatException('Expected a tool list from the backend.');
    }

    return decoded
        .map((item) => GasTool.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  List<CommandAuditEntry> _decodeAuditList(String responseBody) {
    final decoded = jsonDecode(responseBody);

    if (decoded is! List) {
      throw const FormatException('Expected an audit list from the backend.');
    }

    return decoded
        .map(
          (item) => CommandAuditEntry.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  void _requireSuccess(http.Response response, String action) {
    final succeeded = response.statusCode >= 200 && response.statusCode < 300;

    if (!succeeded) {
      throw GasApiException(
        '$action failed with ${response.statusCode}: '
        '${response.body}',
      );
    }
  }
}

class GasApiException implements Exception {
  const GasApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
