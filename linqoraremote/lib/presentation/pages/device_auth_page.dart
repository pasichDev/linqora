import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/presentation/controllers/auth_controller.dart';
import 'package:linqoraremote/presentation/widgets/app_bar.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../core/constants/urls.dart';
import '../../core/utils/lauch_url.dart';

class DeviceAuthPage extends StatefulWidget {
  const DeviceAuthPage({super.key});

  @override
  State<DeviceAuthPage> createState() => _DeviceAuthPageState();
}

class _DeviceAuthPageState extends State<DeviceAuthPage> {
  late final AuthController authController;

  @override
  void initState() {
    super.initState();
    authController = Get.find<AuthController>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarCustom(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              SizedBox(height: 10),
              Obx(() {
                return authController.authStatus.value !=
                            AuthStatus.pendingAuth &&
                        authController.authStatus.value != AuthStatus.connecting
                    ? _buildFAQ()
                    : SizedBox.shrink();
              }),

              SizedBox(height: 10),
              Expanded(
                child: Obx(() {
                  switch (authController.authStatus.value) {
                    case AuthStatus.noWifi:
                      return _buildNoWifi();
                    case AuthStatus.pendingAuth:
                      return _buildAuthPendingView();
                    case AuthStatus.connecting:
                      return _buildConnectingView();
                    case AuthStatus.scanning:
                      if (authController.discoveredDevices.isEmpty) {
                        return _buildScanningView();
                      }
                      return _buildDeviceList();
                    case AuthStatus.listDevices:
                      return _buildDeviceList();
                  }
                }),
              ),
              Obx(() {
                return authController.isWifiConnections.value
                    ? _buildActionButton()
                    : SizedBox.shrink();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoWifi() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 60,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 24),
          const Text(
            'Нет подключения к Wi-Fi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Пожалуйста, подключитесь к Wi-Fi и попробуйте снова',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFAQ() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            launchUrlHandler(howItWorks);
          },
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.remove_from_queue_rounded),

          label: const Text('Як це працює?'),
        ),
        SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () {
            launchUrlHandler(getLinqoraHost);
          },
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.ac_unit),
          label: const Text('Linqora Host'),
        ),
      ],
    );
  }

  Widget _buildScanningView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingAnimationWidget.fourRotatingDots(
            color: Theme.of(context).colorScheme.onSurface,
            size: 60,
          ),
          const SizedBox(height: 24),
          const Text(
            'Поиск устройств Linqora в сети...',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingAnimationWidget.fourRotatingDots(
            color: Theme.of(context).colorScheme.primary,
            size: 60,
          ),
          const SizedBox(height: 24),
          Obx(
            () => Text(
              authController.statusMessage.value,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () {
              authController.cancelAuth('Авторизация отклонена пользователем');
              setState(() {
                authController.authStatus.value = AuthStatus.scanning;
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                )
            ),
            child: const Text('Отменить'),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthPendingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.security,
            size: 60,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          const Text(
            'Запрос авторизации отправлен',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Пожалуйста, подтвердите подключение на устройстве-хосте',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Obx(
            () => Text(
              'Осталось времени: ${authController.authTimeoutSeconds.value} сек',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed:
                () => authController.cancelAuth(
                  'Авторизация отменена пользователем',
                ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Отменить'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return Obx(() {
      if (authController.discoveredDevices.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.devices_other,
                size: 60,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'Устройства LinqoraHost не найдены',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Убедитесь, что устройство находится в той же сети и приложение LinqoraHost запущено',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        itemCount: authController.discoveredDevices.length,
        itemBuilder: (context, index) {
          final device = authController.discoveredDevices[index];

          return Card(
            elevation: 0,
            color: Get.theme.colorScheme.surfaceContainer,
            margin: const EdgeInsets.symmetric(vertical: 0),
            child: ListTile(
              leading: Icon(
                Icons.computer,
                color:
                    device.supportsTLS
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.errorContainer,
              ),
              title: Text(
                device.name,
                style: Get.theme.textTheme.titleMedium?.copyWith(
                  color: Get.theme.colorScheme.onPrimaryContainer,
                ),
              ),
              subtitle: Text(
                '${device.address}:${device.port}',
                style: Get.theme.textTheme.labelMedium?.copyWith(
                  color: Get.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  Icons.arrow_forward,
                  color: Get.theme.colorScheme.onPrimaryContainer,
                ),
                onPressed: () => authController.connectToDevice(device),
              ),
              onTap: () => authController.connectToDevice(device),
            ),
          );
        },
      );
    });
  }

  Widget _buildActionButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Obx(() {
        if (authController.authStatus.value == AuthStatus.scanning ||
            authController.authStatus.value == AuthStatus.connecting ||
            authController.authStatus.value == AuthStatus.pendingAuth) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 48,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: authController.startDiscovery,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh),
            label: Text('Обновить', style: Get.theme.textTheme.titleMedium),
          ),
        );
      }),
    );
  }
}
