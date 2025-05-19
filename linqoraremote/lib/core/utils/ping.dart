// Метод для определения нужного интервала в зависимости от режима
import '../constants/server.dart';

Duration getCurrentPingInterval(bool isBackground) {
  return Duration(
    seconds: isBackground ? backgroundPingInterval : activePingInterval,
  );
}
