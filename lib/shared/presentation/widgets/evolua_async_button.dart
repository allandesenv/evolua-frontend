import 'dart:async';

import 'package:evolua_frontend/l10n/app_l10n.dart';
import 'package:flutter/material.dart';

enum EvoluaAsyncButtonVariant { filled, outlined, text }

class EvoluaAsyncButton extends StatefulWidget {
  const EvoluaAsyncButton.filled({
    super.key,
    required this.label,
    required this.onPressed,
    this.loadingLabel,
    this.icon,
    this.isBusy = false,
    this.expand = false,
  }) : variant = EvoluaAsyncButtonVariant.filled;

  const EvoluaAsyncButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.loadingLabel,
    this.icon,
    this.isBusy = false,
    this.expand = false,
  }) : variant = EvoluaAsyncButtonVariant.outlined;

  const EvoluaAsyncButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.loadingLabel,
    this.icon,
    this.isBusy = false,
    this.expand = false,
  }) : variant = EvoluaAsyncButtonVariant.text;

  final String label;
  final String? loadingLabel;
  final IconData? icon;
  final bool isBusy;
  final bool expand;
  final EvoluaAsyncButtonVariant variant;
  final FutureOr<void> Function()? onPressed;

  @override
  State<EvoluaAsyncButton> createState() => _EvoluaAsyncButtonState();
}

class _EvoluaAsyncButtonState extends State<EvoluaAsyncButton> {
  bool _isRunning = false;

  Future<void> _handlePressed() async {
    if (_isRunning || widget.isBusy || widget.onPressed == null) {
      return;
    }

    setState(() => _isRunning = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) {
        setState(() => _isRunning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isRunning || widget.isBusy;
    final icon = busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(widget.icon ?? Icons.check_rounded);
    final label = Text(
      busy ? widget.loadingLabel ?? context.l10n.commonLoading : widget.label,
    );
    final onPressed = busy ? null : _handlePressed;
    final button = switch (widget.variant) {
      EvoluaAsyncButtonVariant.filled => FilledButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: label,
      ),
      EvoluaAsyncButtonVariant.outlined => OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: label,
      ),
      EvoluaAsyncButtonVariant.text => TextButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: label,
      ),
    };

    if (!widget.expand) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}
