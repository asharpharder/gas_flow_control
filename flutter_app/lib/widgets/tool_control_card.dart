import 'package:flutter/material.dart';

import '../models/gas_tool.dart';

class ToolControlCard extends StatefulWidget {
  const ToolControlCard({
    required this.tool,
    required this.onApply,
    required this.onClose,
    super.key,
  });

  final GasTool tool;
  final Future<void> Function(double requestedPercent) onApply;
  final Future<void> Function() onClose;

  @override
  State<ToolControlCard> createState() => _ToolControlCardState();
}

class _ToolControlCardState extends State<ToolControlCard> {
  late double _draftPercent;
  bool _submitting = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _draftPercent = widget.tool.requestedValvePercent;
  }

  @override
  void didUpdateWidget(covariant ToolControlCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.tool.requestedValvePercent !=
        widget.tool.requestedValvePercent) {
      _draftPercent = widget.tool.requestedValvePercent;
      _dirty = false;
    }
  }

  Future<void> _apply() async {
    setState(() {
      _submitting = true;
    });

    try {
      await widget.onApply(_draftPercent);
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Command ${widget.tool.name} closed?'),
          content: const Text(
            'This sends a software close command to the controller. '
            'It is not a hardware emergency stop.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Command Closed'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await widget.onClose();
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

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;

    final controlsEnabled =
        tool.connected && tool.fault == null && !_submitting;

    final canApply = controlsEnabled && _dirty;

    final canClose =
        controlsEnabled &&
        (tool.requestedValvePercent > 0.1 || tool.actualValvePercent > 0.1);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tool.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Icon(
                  tool.connected ? Icons.check_circle : Icons.error,
                  color: tool.connected ? Colors.greenAccent : Colors.redAccent,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Actual valve position: '
              '${tool.actualValvePercent.toStringAsFixed(1)}%',
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: tool.actualValvePercent / 100),
            const SizedBox(height: 16),
            Text(
              'Measured flow: '
              '${tool.measuredFlowCfh.toStringAsFixed(1)} CFH',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(height: 32),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Draft valve position',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${_draftPercent.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            Slider(
              value: _draftPercent,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${_draftPercent.toStringAsFixed(0)}%',
              onChanged: controlsEnabled
                  ? (value) {
                      setState(() {
                        _draftPercent = value;
                        _dirty =
                            (value - tool.requestedValvePercent).abs() >= 0.5;
                      });
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canApply ? _apply : null,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_submitting ? 'Applying…' : 'Apply Position'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: canClose ? _confirmClose : null,
                icon: const Icon(Icons.power_settings_new),
                label: const Text('Command Valve Closed'),
              ),
            ),
            if (tool.fault != null) ...[
              const SizedBox(height: 12),
              Text(
                'Fault: ${tool.fault}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
