import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'services/demo_gas_service.dart';
import 'services/gas_api.dart';
import 'services/gas_service.dart';

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

const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final GasService service;

  if (demoMode) {
    service = DemoGasService(operatorId: operatorId);
  } else {
    service = const GasApi(
      baseUrl: apiUrl,
      token: apiToken,
      operatorId: operatorId,
    );
  }

  runApp(GasControlApp(api: service));
}

class GasControlApp extends StatelessWidget {
  const GasControlApp({required this.api, super.key});

  final GasService api;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF8A00),
      brightness: Brightness.dark,
      surface: const Color(0xFF151719),
      error: const Color(0xFFFF4D4D),
    );

    return MaterialApp(
      title: demoMode ? 'Gas Flow Control Demo' : 'Gas Flow Control',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF0F1113),
        canvasColor: const Color(0xFF0F1113),
        dividerColor: Colors.white.withValues(alpha: 0.12),
        visualDensity: VisualDensity.standard,
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 2,
          backgroundColor: const Color(0xFF151719),
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
          iconTheme: const IconThemeData(size: 26),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          color: const Color(0xFF1A1D20),
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          backgroundColor: const Color(0xFF151719),
          indicatorColor: colorScheme.primary.withValues(alpha: 0.22),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return IconThemeData(color: colorScheme.primary, size: 30);
            }

            return IconThemeData(
              color: Colors.white.withValues(alpha: 0.72),
              size: 28,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              color: states.contains(WidgetState.selected)
                  ? colorScheme.primary
                  : Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.bold
                  : FontWeight.w600,
            );
          }),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.25,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 52),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
        sliderTheme: SliderThemeData(
          trackHeight: 7,
          activeTrackColor: colorScheme.primary,
          inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
          thumbColor: colorScheme.primary,
          overlayColor: colorScheme.primary.withValues(alpha: 0.18),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: colorScheme.primary,
          linearTrackColor: Colors.white.withValues(alpha: 0.14),
          circularTrackColor: Colors.white.withValues(alpha: 0.14),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2A2D31),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF1A1D20),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
          contentTextStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 16,
            height: 1.4,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
        textTheme: const TextTheme(
          displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 17),
          bodyMedium: TextStyle(fontSize: 15),
          bodySmall: TextStyle(fontSize: 13),
          labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      home: AppShell(api: api),
    );
  }
}
