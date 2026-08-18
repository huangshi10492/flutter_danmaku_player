import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DirectionalScrollView extends StatefulWidget {
  const DirectionalScrollView({
    super.key,
    required this.child,
    this.controller,
    this.padding,
  });

  final Widget child;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  @override
  State<DirectionalScrollView> createState() => _DirectionalScrollViewState();
}

class _DirectionalScrollViewState extends State<DirectionalScrollView> {
  late ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();
  }

  @override
  void didUpdateWidget(DirectionalScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(widget.controller, oldWidget.controller)) return;
    if (oldWidget.controller == null) _controller.dispose();
    _controller = widget.controller ?? ScrollController();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: SingleChildScrollView(
        controller: _controller,
        padding: widget.padding,
        child: widget.child,
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if ((event is! KeyDownEvent && event is! KeyRepeatEvent) ||
        !_controller.hasClients) {
      return .ignored;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => -1.0,
      LogicalKeyboardKey.arrowDown => 1.0,
      _ => 0.0,
    };
    if (direction == 0) return .ignored;

    final position = _controller.position;
    final target =
        (position.pixels + direction * position.viewportDimension * 0.35).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    if ((target - position.pixels).abs() < 0.5) {
      return .ignored;
    }
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    return .handled;
  }
}
