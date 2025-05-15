enum TypeMessageWs {
  auth,
  join_room,
  leave_room,
  auth_response,
  auth_pending,
  auth_request,
  media,
  host_info,
}

extension TypeMessageWsExtension on TypeMessageWs {
  String get value {
    return toString().split('.').last;
  }
}
