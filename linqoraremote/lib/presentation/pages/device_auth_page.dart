import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/presentation/controllers/auth_controller.dart';
import 'package:linqoraremote/presentation/widgets/app_bar.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => authController.startDiscovery(),
    );
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
              _buildStatusBar(),
              SizedBox(height: 10),
              Expanded(
                child: Obx(() {
                  switch (authController.authStatus.value) {
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
              _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Obx(() {
      if (authController.statusMessage.value.isNotEmpty) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Icon(
                authController.authStatus.value == AuthStatus.scanning
                    ? Icons.search
                    : authController.authStatus.value == AuthStatus.connecting
                    ? Icons.sync
                    : Icons.info_outline,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  authController.statusMessage.value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    });
  }

  Widget _buildScanningView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingAnimationWidget.discreteCircle(
            color: Theme.of(context).colorScheme.primary,
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
            margin: const EdgeInsets.symmetric(vertical: 6),
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
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${device.address}:${device.port}',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.arrow_forward),
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

        return ElevatedButton.icon(
          onPressed: authController.startDiscovery,
          icon: const Icon(Icons.refresh),
          label: const Text('Обновить'),
        );
      }),
    );
  }
}
