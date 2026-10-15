import 'package:material_ui/material_ui.dart';

class FocusState {
  final BuildContext context;

  FocusNode? _lastPageFocus;
  FocusNode? _focusBeforePause;
  FocusState(this.context);

  void handleFocusChanged() {
    final focus = FocusManager.instance.primaryFocus;
    if (_containsFocus(focus)) _lastPageFocus = focus;
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == .inactive || state == .hidden || state == .paused) {
      final focus = FocusManager.instance.primaryFocus;
      _focusBeforePause ??= _containsFocus(focus) ? focus : _lastPageFocus;
      return;
    }
    if (state != .resumed) return;
    final focus = _focusBeforePause;
    _focusBeforePause = null;
    if (focus == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && _containsFocus(focus)) {
        focus.requestFocus();
      }
    });
  }

  bool _containsFocus(FocusNode? focus) {
    if (ModalRoute.of(context)?.isCurrent != true || focus == null) {
      return false;
    }
    final focusContext = focus.context;
    if (focusContext == null) return false;
    var belongsToPage = focusContext == context;
    focusContext.visitAncestorElements((ancestor) {
      if (ancestor != context) return true;
      belongsToPage = true;
      return false;
    });
    return belongsToPage;
  }
}
