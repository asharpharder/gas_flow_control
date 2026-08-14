import 'package:flutter/material.dart';

import '../services/gas_service.dart';
import 'audit_history_screen.dart';
import 'home_screen.dart';
import 'tool_list_screen.dart';

const accessPin = String.fromEnvironment('ACCESS_PIN', defaultValue: '123456');

const harderEmailDomain = String.fromEnvironment(
  'HARDER_EMAIL_DOMAIN',
  defaultValue: 'harder.com',
);

class AppShell extends StatefulWidget {
  const AppShell({required this.api, super.key});

  final GasService api;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  bool _isSignedIn = false;
  String? _signedInEmail;

  bool _signIn({required String email, required String pin}) {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedDomain = harderEmailDomain.trim().toLowerCase();

    final emailParts = normalizedEmail.split('@');

    final validEmail =
        emailParts.length == 2 &&
        emailParts.first.isNotEmpty &&
        emailParts.last == normalizedDomain;

    final validPin =
        pin.length == 6 && RegExp(r'^\d{6}$').hasMatch(pin) && pin == accessPin;

    if (!validEmail || !validPin) {
      return false;
    }

    setState(() {
      _isSignedIn = true;
      _signedInEmail = normalizedEmail;
      _selectedIndex = 0;
    });

    return true;
  }

  void _signOut() {
    setState(() {
      _isSignedIn = false;
      _signedInEmail = null;
      _selectedIndex = 0;
    });
  }

  void _selectScreen(int index) {
    if (!_isSignedIn) {
      return;
    }

    if (index < 0 || index > 2) {
      return;
    }

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

    final homeScreen = HomeScreen(
      api: widget.api,
      isSignedIn: _isSignedIn,
      signedInEmail: _signedInEmail,
      onSignIn: _signIn,
      onSignOut: _signOut,
      onOpenControls: () {
        _selectScreen(1);
      },
      onOpenHistory: () {
        _selectScreen(2);
      },
    );

    if (!_isSignedIn) {
      return Scaffold(body: homeScreen);
    }

    final screens = <Widget>[
      homeScreen,
      ToolListScreen(api: widget.api),
      AuditHistoryScreen(api: widget.api),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
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
                icon: Icon(Icons.home_outlined, size: 28),
                selectedIcon: Icon(Icons.home, size: 30),
                label: 'Home',
                tooltip: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined, size: 28),
                selectedIcon: Icon(Icons.tune, size: 30),
                label: 'Controls',
                tooltip: 'Valve controls',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined, size: 28),
                selectedIcon: Icon(Icons.history, size: 30),
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
