import 'dart:convert';

/// A class representing a WebSocket message.
///
/// This class encapsulates the type of the message and any additional fields
/// that may be included in the message payload.
class WsMessage {
  /// The type of the WebSocket message.
  final String type;

  /// A map containing additional fields for the WebSocket message.
  final Map<String, dynamic> _additionalFields;

  /// Constructs a `WsMessage` instance.
  ///
  /// - **Parameters**:
  ///   - `type` (`String`): The type of the WebSocket message. This is required.
  ///   - `additionalFields` (`Map<String, dynamic>?`): Optional additional fields
  ///     to include in the message. Defaults to an empty map if not provided.
  WsMessage({required this.type, Map<String, dynamic>? additionalFields})
    : _additionalFields = additionalFields ?? {};

  /// Sets a field in the additional fields map.
  ///
  /// - **Parameters**:
  ///   - `fieldName` (`String`): The name of the field to set.
  ///   - `value` (`dynamic`): The value to assign to the field.
  void setField(String fieldName, dynamic value) {
    _additionalFields[fieldName] = value;
  }

  /// Retrieves the value of a field from the additional fields map.
  ///
  /// - **Parameters**:
  ///   - `fieldName` (`String`): The name of the field to retrieve.
  /// - **Returns**: The value of the field, or `null` if the field does not exist.
  dynamic getField(String fieldName) {
    return _additionalFields[fieldName];
  }

  /// Checks if a field exists in the additional fields map.
  ///
  /// - **Parameters**:
  ///   - `fieldName` (`String`): The name of the field to check.
  /// - **Returns**: `true` if the field exists, otherwise `false`.
  bool hasField(String fieldName) {
    return _additionalFields.containsKey(fieldName);
  }

  /// Converts the `WsMessage` instance to a JSON-compatible map.
  ///
  /// - **Returns**: A `Map<String, dynamic>` containing the type and additional fields.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> result = {'type': type};

    result.addAll(_additionalFields);

    return result;
  }

  /// Creates a `WsMessage` instance from a JSON-compatible map.
  ///
  /// - **Parameters**:
  ///   - `json` (`Map<String, dynamic>`): A map containing the JSON data.
  /// - **Returns**: A `WsMessage` instance populated with the data from the map.
  factory WsMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;

    final additionalFields =
        Map<String, dynamic>.from(json)
          ..remove('type')
          ..remove('deviceCode');

    return WsMessage(type: type, additionalFields: additionalFields);
  }

  /// Converts the `WsMessage` instance to a JSON string.
  ///
  /// - **Returns**: A `String` containing the JSON representation of the message.
  String toJsonString() {
    return jsonEncode(toJson());
  }
}
