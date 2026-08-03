import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'services/gas_api.dart';

const apiUrl = String.fromEnvironment(
  'GAS_API_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

const apiToken = String.fromEnvironment(
  'GAS_API_TOKEN',
  defaultValue: 'local-simulation-token',
);

const operatorId = String.fromEnvironment(
  'OPERATOR_ID',
  defaultValue: 'development-operator',
);

void main() {
  const api = GasApi(baseUrl: apiUrl, token: apiToken, operatorId: operatorId);

  runApp(const GasControlApp(api: api));
}

class GasControlApp extends StatelessWidget {
  const GasControlApp({required this.api, super.key});

  final GasApi api;

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
      home: AppShell(api: api),
    );
  }
}
