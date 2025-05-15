import 'dart:convert';

class WsMessage {
  final String type;
  final Map<String, dynamic> _additionalFields;

  WsMessage({required this.type, Map<String, dynamic>? additionalFields})
    : _additionalFields = additionalFields ?? {};

  /// Встановлює додаткове поле в повідомленні
  void setField(String fieldName, dynamic value) {
    _additionalFields[fieldName] = value;
  }

  /// Отримує додаткове поле з повідомлення
  dynamic getField(String fieldName) {
    return _additionalFields[fieldName];
  }

  /// Перевіряє чи є поле в повідомленні
  bool hasField(String fieldName) {
    return _additionalFields.containsKey(fieldName);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = {'type': type};

    result.addAll(_additionalFields);

    return result;
  }

  /// Створення екземпляру з Map
  factory WsMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;

    // Копіюємо всі поля крім type і deviceCode в additionalFields
    final additionalFields =
        Map<String, dynamic>.from(json)
          ..remove('type')
          ..remove('deviceCode');

    return WsMessage(type: type, additionalFields: additionalFields);
  }

  /// Перетворення моделі в JSON-рядок
  String toJsonString() {
    return jsonEncode(toJson());
  }
}

/**
 *  // Приклад 1: Повідомлення з полем room як String
    final WsMessage leaveRoomMessage = WsMessage(
    type: 'leave_room',
    deviceCode: 'device123',
    )..setField('room', 'room456');

    print('Приклад 1:');
    print(leaveRoomMessage.toJson());

    // Приклад 2: Повідомлення з полем channels як List
    final WsMessage subscribeMessage = WsMessage(
    type: 'subscribe',
    deviceCode: 'device123',
    )..setField('channels', ['channel1', 'channel2', 'channel3']);

    print('\nПриклад 2:');
    print(subscribeMessage.toJson());

    // Приклад 3: Повідомлення з полем data як Map
    final WsMessage dataMessage = WsMessage(
    type: 'send_data',
    deviceCode: 'device123',
    )..setField('data', {
    'temperature': 25.5,
    'humidity': 60,
    'active': true
    });

    print('\nПриклад 3:');
    print(dataMessage.toJson());

    // Приклад 4: Створення повідомлення з JSON
    final Map<String, dynamic> jsonData = {
    'type': 'leave_room',
    'deviceCode': 'device123',
    'room': 'meeting',
    'userId': 42
    };
 */
