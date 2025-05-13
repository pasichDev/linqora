enum TypeMessageWs {
  auth,
  join_room,
  leave_room,
  cursor_command,
  media,
}

extension TypeMessageWsExtension on TypeMessageWs {
  String get value {
    return toString().split('.').last;
  }
}
