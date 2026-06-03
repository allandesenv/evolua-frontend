import 'dart:async';

import 'package:flutter/material.dart';

class KeyboardAwareFormScrollView extends StatefulWidget {
  const KeyboardAwareFormScrollView({
    super.key,
    required this.child,
    this.controller,
    this.bottomSpacing = 24,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
  });

  final Widget child;
  final ScrollController? controller;
  final double bottomSpacing;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  State<KeyboardAwareFormScrollView> createState() =>
      _KeyboardAwareFormScrollViewState();
}

class _KeyboardAwareFormScrollViewState
    extends State<KeyboardAwareFormScrollView>
    with WidgetsBindingObserver {
  double _lastKeyboardBottom = 0;
  bool _clampScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
      final closedKeyboard = _lastKeyboardBottom > 0 && keyboardBottom == 0;
      _lastKeyboardBottom = keyboardBottom;
      if (closedKeyboard) {
        _scheduleClampToScrollBounds();
      }
    });
  }

  void _scheduleClampToScrollBounds() {
    if (_clampScheduled) return;
    _clampScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _clampScheduled = false;
      final controller = widget.controller;
      if (!mounted || controller == null || !controller.hasClients) return;
      final position = controller.position;
      final target = position.pixels.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (target != position.pixels) {
        controller.jumpTo(target.toDouble());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final keyboardBottom = viewInsets.bottom;
    final isClosingKeyboard = _lastKeyboardBottom > 0 && keyboardBottom == 0;
    final safeBottom = keyboardBottom > 0 ? keyboardBottom : viewPadding.bottom;
    final padding = EdgeInsets.only(bottom: safeBottom + widget.bottomSpacing);

    return LayoutBuilder(
      builder: (context, constraints) {
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            top: false,
            child: _KeyboardPadding(
              padding: padding,
              animate: !isClosingKeyboard,
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  _scheduleClampToScrollBounds();
                  return false;
                },
                child: SingleChildScrollView(
                  controller: widget.controller,
                  keyboardDismissBehavior: widget.keyboardDismissBehavior,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KeyboardPadding extends StatelessWidget {
  const _KeyboardPadding({
    required this.padding,
    required this.animate,
    required this.child,
  });

  final EdgeInsets padding;
  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animate) {
      return Padding(padding: padding, child: child);
    }
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: padding,
      child: child,
    );
  }
}

class EnsureVisibleOnFocus extends StatefulWidget {
  const EnsureVisibleOnFocus({
    super.key,
    required this.focusNode,
    required this.child,
    this.alignment = 0.2,
  });

  final FocusNode focusNode;
  final Widget child;
  final double alignment;

  @override
  State<EnsureVisibleOnFocus> createState() => _EnsureVisibleOnFocusState();
}

class _EnsureVisibleOnFocusState extends State<EnsureVisibleOnFocus>
    with WidgetsBindingObserver {
  final _targetKey = GlobalKey();
  double _lastKeyboardBottom = 0;
  Timer? _ensureVisibleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant EnsureVisibleOnFocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    oldWidget.focusNode.removeListener(_handleFocusChanged);
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _ensureVisibleTimer?.cancel();
    widget.focusNode.removeListener(_handleFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
      final isClosingKeyboard = _lastKeyboardBottom > 0 && keyboardBottom == 0;
      _lastKeyboardBottom = keyboardBottom;
      if (widget.focusNode.hasFocus && !isClosingKeyboard) {
        _scheduleEnsureVisible();
      }
    });
  }

  void _handleFocusChanged() {
    _lastKeyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    if (widget.focusNode.hasFocus) {
      _scheduleEnsureVisible();
    }
  }

  void _scheduleEnsureVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible());
    _ensureVisibleTimer?.cancel();
    _ensureVisibleTimer = Timer(
      const Duration(milliseconds: 260),
      _ensureVisible,
    );
  }

  void _ensureVisible() {
    if (!mounted) return;
    final context = _targetKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: widget.alignment,
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _targetKey, child: widget.child);
  }
}
