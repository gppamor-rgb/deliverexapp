import 'dart:io';

import 'package:deliverex/core/network_errors.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DioException dioError({
    required DioExceptionType type,
    Object? error,
    String? message,
    Response<dynamic>? response,
  }) {
    return DioException(
      requestOptions: RequestOptions(path: '/upload'),
      type: type,
      error: error,
      message: message,
      response: response,
    );
  }

  test('treats broken pipe socket exception as transport error', () {
    final error = dioError(
      type: DioExceptionType.unknown,
      error: SocketException(
        'Broken pipe',
        address: InternetAddress('127.0.0.1'),
        port: 58852,
      ),
    );

    expect(isNetworkTransportError(error), isTrue);
  });

  test('treats known socket messages as transport errors', () {
    final error = dioError(
      type: DioExceptionType.unknown,
      error: 'SocketException: Connection reset by peer',
    );

    expect(isNetworkTransportError(error), isTrue);
  });

  test('treats dio timeout and connection errors as transport errors', () {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.connectionError,
    ]) {
      expect(isNetworkTransportError(dioError(type: type)), isTrue);
    }
  });

  test('does not treat backend validation response as transport error', () {
    final error = dioError(
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/upload'),
        statusCode: 422,
        data: {'message': 'The file is too large.'},
      ),
    );

    expect(isNetworkTransportError(error), isFalse);
  });
}
