import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/data/providers/websocket_provider.dart';
import 'package:linqoraremote/presentation/widgets/power/powered_control_card.dart';

import '../controllers/power_controller.dart';

class PowerManagementView extends StatefulWidget {
  const PowerManagementView({super.key});

  @override
  State<PowerManagementView> createState() => _PowerManagementViewState();
}

class _PowerManagementViewState extends State<PowerManagementView>
    with SingleTickerProviderStateMixin {
  late final PowerController _powerController;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _powerController = Get.put(
      PowerController(webSocketProvider: Get.find<WebSocketProvider>()),
    );

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    if (_isControllerRegistered<PowerController>()) {
      Get.delete<PowerController>();
    }
    _animationController.dispose();

    super.dispose();
  }

  bool _isControllerRegistered<T>() {
    return Get.isRegistered<T>();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: Get.theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'info_power_management'.tr,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Get.theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            PowerControlCard(
              fetchAction: (it) => {_powerController.fetchCommand(it)},
            ),
          ],
        ),
      ),
    );
  }
}
