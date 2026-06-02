import 'package:flutter/material.dart';

class KeyboardAwareFormScrollView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final safeBottom = viewInsets.bottom > 0
        ? viewInsets.bottom
        : viewPadding.bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            top: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: safeBottom + bottomSpacing),
              child: SingleChildScrollView(
                controller: controller,
                keyboardDismissBehavior: keyboardDismissBehavior,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
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
    widget.focusNode.removeListener(_handleFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (widget.focusNode.hasFocus) {
      _scheduleEnsureVisible();
    }
  }

  void _handleFocusChanged() {
    if (widget.focusNode.hasFocus) {
      _scheduleEnsureVisible();
    }
  }

  void _scheduleEnsureVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVisible());
    Future<void>.delayed(const Duration(milliseconds: 260), _ensureVisible);
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
