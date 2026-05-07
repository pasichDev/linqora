import 'package:get/get.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';

enum MouseAction {
  move, // 0
  leftClick, // 1
  rightClick, // 2
  middleClick, // 3
  scroll, // 4
  doubleClick, // 5
}

class MouseController extends GetxController {
  final WebSocketProvider webSocketProvider;

  MouseController({required this.webSocketProvider});

  // Throttle move events to ~30 fps to stay within server rate limits.
  static const _moveInterval = Duration(milliseconds: 33);
  DateTime _lastMove = DateTime.fromMillisecondsSinceEpoch(0);

  // Sensitivity multiplier applied to raw pan deltas.
  final RxDouble sensitivity = 1.5.obs;

  void moveMouse(double dx, double dy) {
    final now = DateTime.now();
    if (now.difference(_lastMove) < _moveInterval) return;
    _lastMove = now;

    final ix = (dx * sensitivity.value).round();
    final iy = (dy * sensitivity.value).round();
    if (ix == 0 && iy == 0) return;

    _send(MouseAction.move, dx: ix, dy: iy);
  }

  void leftClick() => _send(MouseAction.leftClick);
  void rightClick() => _send(MouseAction.rightClick);
  void middleClick() => _send(MouseAction.middleClick);
  void doubleClick() => _send(MouseAction.doubleClick);

  void scroll(int delta) => _send(MouseAction.scroll, delta: delta);

  void _send(MouseAction action, {int dx = 0, int dy = 0, int delta = 0}) {
    if (!webSocketProvider.isReadyForCommand()) return;
    webSocketProvider.sendMessage({
      'type': 'mouse',
      'data': {'action': action.index, 'dx': dx, 'dy': dy, 'delta': delta},
    });
  }
}
