import 'package:dpad/dpad.dart';
import 'package:fldanplay/service/configure.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';

class ContextMenuItem {
  final IconData icon;
  final FItemVariant variant;
  final String title;
  final Function() onPress;

  const ContextMenuItem({
    required this.icon,
    this.variant = .primary,
    required this.title,
    required this.onPress,
  });
}

class ContextMenu extends StatefulWidget with FItemMixin {
  final List<ContextMenuItem> items;
  final VoidCallback onOpen;
  final FItem Function(VoidCallback onPress, FocusNode focusNode) child;
  final FocusNode? focusNode;
  final String openTitle;
  final IconData openIcon;

  const ContextMenu({
    super.key,
    required this.items,
    required this.onOpen,
    required this.child,
    this.focusNode,
    this.openTitle = '打开',
    this.openIcon = FLucideIcons.play,
  });

  @override
  State<ContextMenu> createState() => _ContextMenuState();
}

class _ContextMenuState extends State<ContextMenu>
    with TickerProviderStateMixin {
  static const _tileHeight = 50;
  late final FPopoverController _controller;
  late FocusNode _childFocus;
  late bool _ownsChildFocus;
  double _childHeight = 64;
  bool _menuAbove = false;
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = FPopoverController(vsync: this);
    _ownsChildFocus = widget.focusNode == null;
    _childFocus = widget.focusNode ?? FocusNode(debugLabel: 'context-menu');
  }

  @override
  void didUpdateWidget(ContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (_ownsChildFocus) _childFocus.dispose();
      _ownsChildFocus = widget.focusNode == null;
      _childFocus = widget.focusNode ?? FocusNode(debugLabel: 'context-menu');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsChildFocus) _childFocus.dispose();
    super.dispose();
  }

  void _closeAndRun(Function() action) {
    _hideContextMenu();
    action();
  }

  Future<void> _hideContextMenu() async {
    _controller.hide();
    if (mounted) setState(() => _menuOpen = false);
  }

  Future<bool> _handleBackButtonPressed() async {
    if (!_menuOpen) return false;
    await _hideContextMenu();
    return true;
  }

  void _showContextMenu() {
    final renderObject = _childFocus.context?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final top = renderObject.localToGlobal(Offset.zero).dy;
      final childHeight = renderObject.size.height;
      final viewportHeight = MediaQuery.sizeOf(context).height;
      final spaceBelow = viewportHeight - top - childHeight;
      final menuHeight = _tileHeight * (widget.items.length + 1);
      _menuAbove = spaceBelow < menuHeight && top > spaceBelow;
      _childHeight = childHeight;
    }
    setState(() => _menuOpen = true);
    _controller.show();
  }

  @override
  Widget build(BuildContext context) {
    final dpadEnabled = GetIt.I.get<ConfigureService>().dpadEnable.value;
    final List<FTileGroupMixin> menu = [
      _MenuGroup(
        items: [
          if (dpadEnabled)
            .tile(
              prefix: Icon(widget.openIcon),
              title: Text(widget.openTitle),
              autofocus: true,
              onPress: () => _closeAndRun(widget.onOpen),
            ),
          ...widget.items.asMap().entries.map<FTileMixin>(
            (entry) => .tile(
              prefix: Icon(entry.value.icon),
              variant: entry.value.variant,
              title: Text(entry.value.title),
              autofocus: !dpadEnabled && entry.key == 0,
              onPress: () => _closeAndRun(entry.value.onPress),
            ),
          ),
        ],
      ),
    ];
    return BackButtonListener(
      onBackButtonPressed: _handleBackButtonPressed,
      child: PopScope(
        canPop: !_menuOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _menuOpen) _hideContextMenu();
        },
        child: FContextMenu.tiles(
          control: .managed(controller: _controller),
          style: .delta(
            barrierFilter: () => FModalSheetStyle.defaultBarrierFilter,
          ),
          cutout: true,
          menuAnchor: dpadEnabled && _menuAbove ? .bottomLeft : .topLeft,
          offset: dpadEnabled && !_menuAbove ? Offset(0, _childHeight) : .zero,
          menu: menu,
          child: widget.child(
            dpadEnabled ? _showContextMenu : widget.onOpen,
            _childFocus,
          ),
        ),
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget with FTileGroupMixin {
  final List<FTileMixin> items;

  const _MenuGroup({required this.items});

  @override
  Widget build(BuildContext _) => Dpad(
    child: DpadRegion(
      verticalEdge: .stop,
      child: FTileGroup(divider: .full, children: items),
    ),
  );
}
