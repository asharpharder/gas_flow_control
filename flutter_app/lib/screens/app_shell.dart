import 'package:flutter/material.dart';

import '../services/gas_api.dart';
import 'audit_history_screen.dart';
import 'tool_list_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.api,
    super.key,
  });

  final GasApi api;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = [
      ToolListScreen(api: widget.api),
      AuditHistoryScreen(api: widget.api),
    ];
  }

  void _selectScreen(int index) {
    if (index == _selectedIndex) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.25),
              ),
            ),
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                offset: Offset(0, -2),
                color: Color(0x22000000),
              ),
            ],
          ),
          child: NavigationBar(
            height: 76,
            selectedIndex: _selectedIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: _selectScreen,
            destinations: const [
              NavigationDestination(
                icon: Icon(
                  Icons.tune_outlined,
                  size: 28,
                ),
                selectedIcon: Icon(
                  Icons.tune,
                  size: 30,
                ),
                label: 'Controls',
                tooltip: 'Valve controls',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.history_outlined,
                  size: 28,
                ),
                selectedIcon: Icon(
                  Icons.history,
                  size: 30,
                ),
                label: 'History',
                tooltip: 'Command history',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
