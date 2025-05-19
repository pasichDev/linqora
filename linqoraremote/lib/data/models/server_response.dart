class ServerResponse<T> {
  final String type;
  final T? data;
  final ErrorInfo? error;

  ServerResponse({required this.type, this.data, this.error});

  factory ServerResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>)? dataConverter,
  ) {
    T? parsedData;
    if (json['data'] != null && dataConverter != null) {
      parsedData = dataConverter(json['data'] as Map<String, dynamic>);
    }

    ErrorInfo? errorInfo;
    if (json['error'] != null) {
      errorInfo = ErrorInfo.fromJson(json['error'] as Map<String, dynamic>);
    }

    return ServerResponse(
      type: json['type'] as String,
      data: parsedData,
      error: errorInfo,
    );
  }

  bool get hasError => error != null;
}

class ErrorInfo {
  final int? code;
  final String message;

  ErrorInfo({this.code, required this.message});

  factory ErrorInfo.fromJson(Map<String, dynamic> json) {
    return ErrorInfo(
      code: json['code'] != null ? int.tryParse(json['code'].toString()) : null,
      message: json['message'] as String,
    );
  }
}
