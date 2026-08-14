import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/gas_tool.dart';
import '../services/gas_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.api,
    required this.isSignedIn,
    required this.signedInEmail,
    required this.onSignIn,
    required this.onSignOut,
    required this.onOpenControls,
    required this.onOpenHistory,
    super.key,
  });

  final GasService api;

  final bool isSignedIn;
  final String? signedInEmail;

  final bool Function({required String email, required String pin}) onSignIn;

  final VoidCallback onSignOut;
  final VoidCallback onOpenControls;
  final VoidCallback onOpenHistory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Duration _refreshInterval = Duration(seconds: 2);

  final List<GasTool> _tools = [];

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _pinController = TextEditingController();

  Timer? _refreshTimer;

  bool _loading = true;
  bool _requestInProgress = false;
  bool _connectionFailed = false;

  String? _loginError;

  @override
  void initState() {
    super.initState();

    if (widget.isSignedIn) {
      _startControllerMonitoring();
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isSignedIn && widget.isSignedIn) {
      _startControllerMonitoring();
    }

    if (oldWidget.isSignedIn && !widget.isSignedIn) {
      _stopControllerMonitoring();

      _tools.clear();

      _loading = true;
      _connectionFailed = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();

    _emailController.dispose();
    _pinController.dispose();

    super.dispose();
  }

  void _startControllerMonitoring() {
    _refreshTimer?.cancel();

    unawaited(_loadTools());

    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      unawaited(_loadTools());
    });
  }

  void _stopControllerMonitoring() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _attemptSignIn() {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();

    final success = widget.onSignIn(email: email, pin: pin);

    if (success) {
      setState(() {
        _loginError = null;
      });

      _pinController.clear();

      return;
    }

    setState(() {
      _loginError =
          'Unable to sign in. Check your Harder email and 6-digit PIN.';
    });
  }

  Future<void> _loadTools() async {
    if (!widget.isSignedIn || _requestInProgress) {
      return;
    }

    _requestInProgress = true;

    try {
      final tools = await widget.api.fetchTools();

      if (!mounted) {
        return;
      }

      setState(() {
        _tools
          ..clear()
          ..addAll(tools);

        _loading = false;
        _connectionFailed = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _connectionFailed = true;
      });
    } finally {
      _requestInProgress = false;
    }
  }

  int get _adjustingCount {
    return _tools.where((tool) => tool.isAdjusting).length;
  }

  int get _warningCount {
    return _tools.where((tool) => tool.hasWarning).length;
  }

  int get _faultCount {
    return _tools.where((tool) => tool.isFaulted).length;
  }

  int get _offlineCount {
    return _tools.where((tool) => tool.isOffline).length;
  }

  int get _attentionCount {
    return _warningCount + _faultCount + _offlineCount;
  }

  int get _onlineCount {
    return _tools.where((tool) => tool.isOnline).length;
  }

  GasToolStatus get _systemStatus {
    if (_faultCount > 0) {
      return GasToolStatus.fault;
    }

    if (_offlineCount > 0) {
      return GasToolStatus.offline;
    }

    if (_warningCount > 0) {
      return GasToolStatus.warning;
    }

    if (_adjustingCount > 0) {
      return GasToolStatus.adjusting;
    }

    return GasToolStatus.normal;
  }

  Color _systemColor() {
    if (_connectionFailed) {
      return Colors.redAccent;
    }

    switch (_systemStatus) {
      case GasToolStatus.normal:
        return Colors.green;

      case GasToolStatus.adjusting:
        return Colors.lightBlueAccent;

      case GasToolStatus.warning:
        return Colors.orangeAccent;

      case GasToolStatus.offline:
      case GasToolStatus.fault:
        return Colors.redAccent;
    }
  }

  IconData _systemIcon() {
    if (_connectionFailed) {
      return Icons.cloud_off;
    }

    switch (_systemStatus) {
      case GasToolStatus.normal:
        return Icons.check_circle;

      case GasToolStatus.adjusting:
        return Icons.sync;

      case GasToolStatus.warning:
        return Icons.warning_amber_rounded;

      case GasToolStatus.offline:
        return Icons.link_off;

      case GasToolStatus.fault:
        return Icons.error;
    }
  }

  String _systemTitle() {
    if (_connectionFailed) {
      return 'CONNECTION LOST';
    }

    switch (_systemStatus) {
      case GasToolStatus.normal:
        return 'SYSTEM NORMAL';

      case GasToolStatus.adjusting:
        return 'SYSTEM ADJUSTING';

      case GasToolStatus.warning:
        return 'SYSTEM WARNING';

      case GasToolStatus.offline:
        return 'CONTROLLER OFFLINE';

      case GasToolStatus.fault:
        return 'SYSTEM FAULT';
    }
  }

  Widget _buildLogin() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(Icons.lock_outline, size: 46, color: colorScheme.primary),
        ),
        const SizedBox(height: 24),
        Text(
          'GAS FLOW CONTROL',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'AUTHORIZED ACCESS',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(
            labelText: 'Harder Email',
            hintText: 'employee@harder.com',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onSubmitted: (_) {
            _attemptSignIn();
          },
          decoration: const InputDecoration(
            labelText: '6-Digit PIN',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.pin_outlined),
            counterText: '',
          ),
        ),
        if (_loginError != null) ...[
          const SizedBox(height: 12),
          Text(
            _loginError!,
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: FilledButton.icon(
            onPressed: _attemptSignIn,
            icon: const Icon(Icons.login, size: 26),
            label: const Text(
              'SIGN IN',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Access is limited to authorized personnel.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white60),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSystemSummary() {
    if (_loading && _tools.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: CircularProgressIndicator(),
      );
    }

    final color = _systemColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          Icon(_systemIcon(), size: 38, color: color),
          const SizedBox(height: 8),
          Text(
            _systemTitle(),
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (_connectionFailed)
            const Text(
              'Unable to retrieve controller status.',
              textAlign: TextAlign.center,
            )
          else ...[
            Text(
              '$_onlineCount of ${_tools.length} controllers online',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _attentionCount == 0
                  ? 'No warnings or faults'
                  : '$_attentionCount require attention',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignedInHome() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(
            Icons.precision_manufacturing_outlined,
            size: 48,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'GAS FLOW CONTROL',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Version 1.1',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Signed in as ${widget.signedInEmail ?? ''}',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _buildSystemSummary(),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 64,
          child: FilledButton.icon(
            onPressed: widget.onOpenControls,
            icon: const Icon(Icons.tune, size: 28),
            label: const Text(
              'OPEN CONTROLS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: OutlinedButton.icon(
            onPressed: widget.onOpenHistory,
            icon: const Icon(Icons.history, size: 26),
            label: const Text(
              'VIEW COMMAND HISTORY',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 22),
        TextButton.icon(
          onPressed: widget.onSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('SIGN OUT'),
        ),
        const SizedBox(height: 16),
        Text(
          'Field review build',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white60),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gas Flow Control',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: widget.isSignedIn ? _buildSignedInHome() : _buildLogin(),
            ),
          ),
        ),
      ),
    );
  }
}
