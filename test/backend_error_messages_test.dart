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
}
