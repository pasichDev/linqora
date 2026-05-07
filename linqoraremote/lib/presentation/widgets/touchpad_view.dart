import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';

import '../controllers/mouse_controller.dart';

class TouchpadView extends StatefulWidget {
  const TouchpadView({super.key});

  @override
  State<TouchpadView> createState() => _TouchpadViewState();
}

class _TouchpadViewState extends State<TouchpadView> {
  late final MouseController _mouse;

  @override
  void initState() {
    super.initState();
    _mouse = Get.put(
      MouseController(webSocketProvider: Get.find<WebSocketProvider>()),
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<MouseController>()) Get.delete<MouseController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _sensitivityRow(),
          const SizedBox(height: 12),
          Expanded(child: _touchpad()),
          const SizedBox(height: 12),
          _scrollStrip(),
          const SizedBox(height: 12),
          _buttonRow(),
        ],
      ),
    );
  }

  Widget _sensitivityRow() {
    return Row(
      children: [
        Text('sensitivity'.tr, style: Get.textTheme.bodyMedium),
        Expanded(
          child: Obx(
            () => Slider(
              value: _mouse.sensitivity.value,
              min: 0.5,
              max: 4.0,
              divisions: 7,
              label: '×${_mouse.sensitivity.value.toStringAsFixed(1)}',
              onChanged: (v) => _mouse.sensitivity.value = v,
            ),
          ),
        ),
        Obx(
          () => SizedBox(
            width: 36,
            child: Text(
              '×${_mouse.sensitivity.value.toStringAsFixed(1)}',
              style: Get.textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }

  Widget _touchpad() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          // pan → move
          onPanUpdate: (d) => _mouse.moveMouse(d.delta.dx, d.delta.dy),
          // tap → left click
          onTap: _mouse.leftClick,
          // double-tap → double click
          onDoubleTap: _mouse.doubleClick,
          // long press → right click
          onLongPress: _mouse.rightClick,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 48,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(60),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'touchpad_hint'.tr,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(80),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Vertical drag strip for scrolling.
  Widget _scrollStrip() {
    double _scrollAccum = 0;
    const notchThreshold = 40.0; // pixels per scroll notch

    return StatefulBuilder(
      builder: (ctx, setState) {
        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: GestureDetector(
            onVerticalDragUpdate: (d) {
              _scrollAccum += d.delta.dy;
              while (_scrollAccum >= notchThreshold) {
                _mouse.scroll(-1); // drag down = scroll down
                _scrollAccum -= notchThreshold;
              }
              while (_scrollAccum <= -notchThreshold) {
                _mouse.scroll(1); // drag up = scroll up
                _scrollAccum += notchThreshold;
              }
            },
            onVerticalDragEnd: (_) {
              _scrollAccum = 0;
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.swap_vert,
                    size: 20,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(120),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'scroll'.tr,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(140),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buttonRow() {
    return Row(
      children: [
        Expanded(
          child: _clickButton(
            label: 'left_click'.tr,
            icon: Icons.mouse,
            onPressed: _mouse.leftClick,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _clickButton(
            label: 'right_click'.tr,
            icon: Icons.ads_click,
            onPressed: _mouse.rightClick,
          ),
        ),
      ],
    );
  }

  Widget _clickButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
