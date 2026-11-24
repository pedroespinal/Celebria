import 'package:flutter/widgets.dart';

/// Safe navigation helpers (v1.10.3).
///
/// Plain `Navigator.of(context).pop()` always pops whatever route is on TOP.
/// Called twice for one action (a screen that rebuilds twice, or a quick
/// double tap) it pops one screen too many — and when that extra pop removes
/// the Home route, Android shows a completely black screen with nothing to
/// go back to. Reproduced on device: deleting a contact from its detail
/// screen popped Home as well.

/// Removes exactly the route that [context] belongs to, at most once, and
/// never the first route (Home).
/// A second call (or a call after the route was already closed some other
/// way) does nothing, and it never touches any other route.
void closeOwnRoute(BuildContext context) {
  if (!context.mounted) return;
  final route = ModalRoute.of(context);
  if (route == null || !route.isActive) return;
  // Never close the root (Home): there would be nothing left to show.
  if (route.isFirst) return;
  final nav = Navigator.of(context);
  if (route.isCurrent) {
    nav.pop();
  } else {
    nav.removeRoute(route);
  }
}

/// Runs [action] only if no previous call is still in progress — guards
/// buttons whose async handler ends by closing a screen.
class OnceGuard {
  bool _busy = false;
  bool get busy => _busy;

  Future<void> run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      await action();
    } finally {
      _busy = false;
    }
  }
}
