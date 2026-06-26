import 'dart:io';

import 'package:dio/dio.dart';

bool isNetworkTransportError(DioException error) {
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.connectionError) {
    return true;
  }

  if (error.type != DioExceptionType.unknown) {
    return false;
  }

  final cause = error.error;
  if (cause is SocketException) {
    return true;
  }

  final message = [
    error.message,
    cause?.toString(),
  ].whereType<String>().join(' ').toLowerCase();

  return message.contains('broken pipe') ||
      message.contains('connection reset') ||
      message.contains('connection aborted') ||
      message.contains('software caused connection abort');
}
