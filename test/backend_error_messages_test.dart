import 'package:deliverex/core/backend_error_messages.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts top-level backend message', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/driver/documents'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/driver/documents'),
        statusCode: 422,
        data: {'message': 'The file is too large.'},
      ),
      type: DioExceptionType.badResponse,
    );

    expect(messageFromDioException(error), 'The file is too large.');
  });

  test('prefers Laravel field validation errors', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/driver/documents'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/driver/documents'),
        statusCode: 422,
        data: {
          'message': 'The given data was invalid.',
          'errors': {
            'file': ['The file must be an image or PDF.'],
          },
        },
      ),
      type: DioExceptionType.badResponse,
    );

    expect(messageFromDioException(error), 'The file must be an image or PDF.');
  });

  test('uses explicit server error message for 500 responses', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/driver/status'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/driver/status'),
        statusCode: 500,
        data: {'message': 'Server Error'},
      ),
      type: DioExceptionType.badResponse,
    );

    expect(
      messageFromDioException(
        error,
        serverErrorMessage:
            'The server could not update the delivery status. Please try again or contact your administrator.',
      ),
      'The server could not update the delivery status. Please try again or contact your administrator.',
    );
  });

  test('keeps validation messages before fallback behavior', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/driver/status'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/driver/status'),
        statusCode: 422,
        data: {'message': 'Invalid status transition.'},
      ),
      type: DioExceptionType.badResponse,
    );

    expect(
      messageFromDioException(
        error,
        serverErrorMessage:
            'The server could not update the delivery status. Please try again or contact your administrator.',
      ),
      'Invalid status transition.',
    );
  });

  test('uses clean session expired message for auth failures', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/driver/profile'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/driver/profile'),
        statusCode: 401,
        data: {'message': 'Unauthenticated.'},
      ),
      type: DioExceptionType.badResponse,
    );

    expect(
      messageFromDioException(error),
      'Session expired. Please sign in again.',
    );
  });
}
