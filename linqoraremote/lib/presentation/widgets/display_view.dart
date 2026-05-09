import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/themes/lx_theme.dart';
import '../controllers/display_controller.dart';
import '../controllers/platform_caps_controller.dart';
import 'lx_glass.dart';
import 'lx_header.dart';

class DisplayView extends StatelessWidget {
  const DisplayView({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<DisplayController>();

    return Column(
      children: [
        const LxHeader(title: 'Display'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: sp18, vertical: sp12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LxGlass(
                        padding: const EdgeInsets.symmetric(vertical: sp18),
                        borderRadius: BorderRadius.circular(lxRadiusCard),
                        onTap: ctrl.sleep,
                        child: const Column(
                          children: [
                            Icon(Icons.nightlight_round,
                                color: lxTextDim, size: 28),
                            SizedBox(height: sp8),
                            Text('Sleep',
                                style: TextStyle(color: lxTextDim)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: sp12),
                    Expanded(
                      child: LxGlass(
                        accent: true,
                        padding: const EdgeInsets.symmetric(vertical: sp18),
                        borderRadius: BorderRadius.circular(lxRadiusCard),
                        onTap: ctrl.wake,
                        child: const Column(
                          children: [
                            Icon(Icons.wb_sunny_rounded,
                                color: lxAccent, size: 28),
                            SizedBox(height: sp8),
                            Text('Wake',
                                style: TextStyle(color: lxAccent)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Obx(() {
                  final caps = Get.find<PlatformCapsController>();
                  if (!caps.has('display_brightness')) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: sp22),
                      Text(
                        'Brightness',
                        style: TextStyle(
                            color: lxTextDim, fontSize: 12, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: sp12),
                      LxGlass(
                        padding: const EdgeInsets.symmetric(
                            horizontal: sp14, vertical: sp18),
                        borderRadius: BorderRadius.circular(lxRadiusCard),
                        child: Row(
                          children: [
                            const Icon(Icons.brightness_low,
                                color: lxTextDim, size: 20),
                            const SizedBox(width: sp8),
                            Expanded(
                              child: Obx(() => SliderTheme(
                                    data: SliderThemeData(
                                      activeTrackColor: lxAccent,
                                      inactiveTrackColor: lxHairlineHi,
                                      thumbColor: lxAccent,
                                      overlayColor:
                                          lxAccent.withValues(alpha: 0.15),
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 8),
                                    ),
                                    child: Slider(
                                      value: ctrl.brightness.value,
                                      min: 0,
                                      max: 100,
                                      onChanged: ctrl.onBrightnessChanged,
                                    ),
                                  )),
                            ),
                            const SizedBox(width: sp8),
                            const Icon(Icons.brightness_high,
                                color: lxTextDim, size: 20),
                          ],
                        ),
                      ),
                      const SizedBox(height: sp8),
                      Obx(() => Center(
                            child: Text(
                              '${ctrl.brightness.value.round()}%',
                              style: const TextStyle(
                                  color: lxTextDim, fontSize: 13),
                            ),
                          )),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
