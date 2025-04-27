import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../models/discovered_service.dart';

class MDnsProvider {
  Function()? onConnected;
  Function()? onEmpty;

  Future<void> enableMulticast() async {
    const wifiMulticastChannel = MethodChannel('android.net.wifi.WifiManager');
    try {
      final result = await wifiMulticastChannel.invokeMethod(
        'acquireMulticastLock',
      );
      if (kDebugMode) {
        print(result);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Не вдалося активувати multicast: $e");
      }
    }
  }

  Future<List<DiscoveredService>> discoverDevices(String deviceCode) async {
    List<DiscoveredService> devices = [];
    await enableMulticast();

    final MDnsClient client = MDnsClient();
    await client.start();
    if (kDebugMode) {
      print('Починаю пошук... Ціль: $deviceCode');
    }

    await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer('_$deviceCode._tcp.local'),
    )) {
      if (kDebugMode) {
        print('Знайшов PTR: ${ptr.domainName}');
      }
      onConnected?.call();
      await for (final SrvResourceRecord srv in client
          .lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(ptr.domainName),
          )) {
        await for (final IPAddressResourceRecord ip in client
            .lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(srv.target),
            )) {
          devices.add(
            DiscoveredService(
              name: ptr.domainName,
              address: ip.address.address,
            ),
          );
        }
      }
    }

    if (devices.isEmpty) {
      onEmpty?.call();
    }
    client.stop();
    return devices;
  }
}
