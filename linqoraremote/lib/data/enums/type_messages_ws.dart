enum TypeMessageWs { auth, join_room, leave_room, cursor_command }

extension TypeMessageWsExtension on TypeMessageWs {
  String get value {
    return toString().split('.').last;
  }
}
