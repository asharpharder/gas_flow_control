import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/gas_tool.dart';

class ToolControlCard extends StatefulWidget {
  const ToolControlCard({
    required this.tool,
    required this.commandsEnabled,
    required this.commandsDisabledReason,
    required this.onApply,
    required this.onClose,
    super.key,
  });

  final GasTool tool;
  final bool commandsEnabled;
  final String commandsDisabledReason;
  final Future<void> Function(double requestedPercent) onApply;
  final Future<void> Function() onClose;

  @override
  State<ToolControlCard> createState() => _ToolControlCardState();
}

class _ToolControlCardState extends State<ToolControlCard> {
  static const double _adjustmentStep = 5;

  late double _draftPercent;
  late final TextEditingController _setpointController;
  late final FocusNode _setpointFocusNode;

  bool _submitting = false;
  bool _dirty = false;
  String? _inputError;

  @override
  void initState() {
    super.initState();

    _draftPercent = widget.tool.requestedValvePercent;

    _setpointController = TextEditingController(
      text: _draftPercent.toStringAsFixed(0),
    );

    _setpointFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant ToolControlCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.tool.requestedValvePercent !=
        widget.tool.requestedValvePercent) {
      _draftPercent = widget.tool.requestedValvePercent;
      _dirty = false;
      _inputError = null;

      if (!_setpointFocusNode.hasFocus) {
        _setpointController.text = _draftPercent.toStringAsFixed(0);
      }
    }
  }

  @override
  void dispose() {
    _setpointController.dispose();
    _setpointFocusNode.dispose();
    super.dispose();
  }

  bool get _toolAvailable {
    return widget.commandsEnabled && widget.tool.isOnline && !_submitting;
  }

  void _setDraftPercent(double value, {bool updateTextField = true}) {
    final clampedValue = value.clamp(0.0, 100.0);

    setState(() {
      _draftPercent = clampedValue;

      _dirty = (clampedValue - widget.tool.requestedValvePercent).abs() >= 0.5;

      _inputError = null;

      if (updateTextField) {
        _setpointController.text = clampedValue.toStringAsFixed(0);
        _setpointController.selection = TextSelection.collapsed(
          offset: _setpointController.text.length,
        );
      }
    });
  }

  void _handleSetpointChanged(String value) {
    if (value.isEmpty) {
      setState(() {
        _inputError = 'Enter a value from 0 to 100.';
        _dirty = false;
      });

      return;
    }

    final parsedValue = int.tryParse(value);

    if (parsedValue == null) {
      setState(() {
        _inputError = 'Enter a whole number from 0 to 100.';
        _dirty = false;
      });

      return;
    }

    if (parsedValue < 0 || parsedValue > 100) {
      setState(() {
        _inputError = 'Setpoint must be between 0% and 100%.';
        _dirty = false;
      });

      return;
    }

    _setDraftPercent(parsedValue.toDouble(), updateTextField: false);
  }

  void _handleSetpointSubmitted(String value) {
    _handleSetpointChanged(value);

    if (_inputError == null) {
      _setpointFocusNode.unfocus();
    }
  }

  void _decreaseDraft() {
    if (!_toolAvailable) {
      return;
    }

    _setDraftPercent(_draftPercent - _adjustmentStep);
  }

  void _increaseDraft() {
    if (!_toolAvailable) {
      return;
    }

    _setDraftPercent(_draftPercent + _adjustmentStep);
  }

  Future<void> _apply() async {
    if (!_toolAvailable || !_dirty || _inputError != null) {
      return;
    }

    _setpointFocusNode.unfocus();

    setState(() {
      _submitting = true;
    });

    try {
      await widget.onApply(_draftPercent);

      if (!mounted) {
        return;
      }

      setState(() {
        _dirty = false;
        _inputError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.tool.name}: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _confirmClose() async {
    if (!_toolAvailable) {
      return;
    }

    _setpointFocusNode.unfocus();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            size: 42,
            color: colorScheme.error,
          ),
          title: Text(
            'Close ${widget.tool.name} valve?',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'This sends a software close command to this controller.\n\n'
            'It does not replace a physical emergency stop or manual '
            'gas shutoff.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('CANCEL'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.power_settings_new),
              label: const Text('CLOSE VALVE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted || !_toolAvailable) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await widget.onClose();

      if (!mounted) {
        return;
      }

      setState(() {
        _draftPercent = 0;
        _dirty = false;
        _inputError = null;

        _setpointController.text = '0';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.tool.name}: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Color _statusColor() {
    switch (widget.tool.status) {
      case GasToolStatus.online:
        return widget.commandsEnabled ? Colors.green : Colors.orangeAccent;

      case GasToolStatus.offline:
        return Colors.redAccent;

      case GasToolStatus.fault:
        return Colors.redAccent;
    }
  }

  IconData _statusIcon() {
    switch (widget.tool.status) {
      case GasToolStatus.online:
        return widget.commandsEnabled
            ? Icons.check_circle
            : Icons.warning_amber_rounded;

      case GasToolStatus.offline:
        return Icons.link_off;

      case GasToolStatus.fault:
        return Icons.error;
    }
  }

  String _statusText() {
    if (!widget.commandsEnabled && widget.tool.isOnline) {
      return 'LOCKED';
    }

    return widget.tool.statusLabel;
  }

  Widget _buildStatusChip() {
    final color = _statusColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(), size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            _statusText(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingPanel({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledWarning() {
    String message;

    if (!widget.commandsEnabled) {
      message = widget.commandsDisabledReason;
    } else if (widget.tool.isOffline) {
      message = 'This tool controller is disconnected.';
    } else if (widget.tool.hasFault) {
      message = 'Controller fault: ${widget.tool.fault}';
    } else {
      return const SizedBox.shrink();
    }

    return _buildWarningPanel(
      icon: Icons.lock,
      message: message,
      color: Colors.redAccent,
    );
  }

  Widget _buildValveMismatchWarning() {
    if (!widget.tool.valvePositionMismatch) {
      return const SizedBox.shrink();
    }

    return _buildWarningPanel(
      icon: Icons.sync_problem,
      color: Colors.orangeAccent,
      message:
          'Valve position mismatch detected. Commanded position is '
          '${widget.tool.requestedValveLabel}, but the actual position is '
          '${widget.tool.actualValveLabel}. Difference: '
          '${widget.tool.valveDifference.toStringAsFixed(1)}%.',
    );
  }

  Widget _buildWarningPanel({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: SizedBox(
        height: 60,
        child: OutlinedButton.icon(
          onPressed: _toolAvailable ? onPressed : null,
          icon: Icon(icon, size: 28),
          label: Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildSetpointInput() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          'ENTER VALVE POSITION',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _setpointController,
          focusNode: _setpointFocusNode,
          enabled: _toolAvailable,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: false,
            signed: false,
          ),
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: InputDecoration(
            hintText: '0',
            suffixText: '%',
            suffixStyle: TextStyle(
              color: colorScheme.primary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            errorText: _inputError,
            helperText: 'Enter a whole number from 0 to 100',
            helperStyle: Theme.of(context).textTheme.bodySmall,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
          ),
          onTap: () {
            _setpointController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _setpointController.text.length,
            );
          },
          onChanged: _handleSetpointChanged,
          onSubmitted: _handleSetpointSubmitted,
        ),
        const SizedBox(height: 8),
        Text(
          _dirty
              ? 'New setpoint not yet applied'
              : 'Current command: ${widget.tool.requestedValveLabel}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _dirty ? Colors.orangeAccent : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    final colorScheme = Theme.of(context).colorScheme;

    final canApply = _toolAvailable && _dirty && _inputError == null;

    final canClose = _toolAvailable && tool.valveIsOpen;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _statusColor().withValues(alpha: 0.08),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tool.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (!_toolAvailable) ...[
                  _buildDisabledWarning(),
                  const SizedBox(height: 12),
                ],
                if (tool.valvePositionMismatch) ...[
                  _buildValveMismatchWarning(),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    _buildReadingPanel(
                      label: 'ACTUAL VALVE',
                      value: tool.actualValveLabel,
                      icon: Icons.tune,
                    ),
                    const SizedBox(width: 12),
                    _buildReadingPanel(
                      label: 'MEASURED FLOW',
                      value: tool.measuredFlowLabel,
                      icon: Icons.air,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: tool.normalizedActualValvePosition,
                  minHeight: 9,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: _buildSetpointInput(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildAdjustmentButton(
                      icon: Icons.remove,
                      label: '−5%',
                      onPressed: _decreaseDraft,
                    ),
                    const SizedBox(width: 12),
                    _buildAdjustmentButton(
                      icon: Icons.add,
                      label: '+5%',
                      onPressed: _increaseDraft,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: FilledButton.icon(
                    onPressed: canApply ? _apply : null,
                    icon: _submitting
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, size: 24),
                    label: Text(
                      _submitting
                          ? 'SENDING COMMAND...'
                          : _dirty && _inputError == null
                          ? 'APPLY ${_draftPercent.toStringAsFixed(0)}%'
                          : 'POSITION APPLIED',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(
                        color: canClose
                            ? colorScheme.error
                            : colorScheme.outline.withValues(alpha: 0.35),
                      ),
                    ),
                    onPressed: canClose ? _confirmClose : null,
                    icon: const Icon(Icons.power_settings_new, size: 24),
                    label: const Text(
                      'CLOSE THIS VALVE',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
