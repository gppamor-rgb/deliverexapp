import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import 'session_service.dart';

class ApiClient {
  ApiClient()
    : dio = Dio(
        BaseOptions(
          baseUrl: 'https://deliverexapp.com/api',
          connectTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      ) {
    _allowUntrustedCert();
    _installSessionRefreshInterceptor();
  }

  final Dio dio;

  void _installSessionRefreshInterceptor() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode;
          final roleName = error.requestOptions.extra['sessionRole'];
          final alreadyRetried =
              error.requestOptions.extra['sessionRetry'] == true;

          if ((statusCode != 401 && statusCode != 419) ||
              roleName is! String ||
              alreadyRetried) {
            handler.next(error);
            return;
          }

          final role = switch (roleName) {
            'driver' => MobileSessionRole.driver,
            'customer' => MobileSessionRole.customer,
            _ => null,
          };
          if (role == null) {
            handler.next(error);
            return;
          }

          try {
            final token = await SessionService.instance.refreshAccessToken(
              role: role,
              dio: dio,
            );
            final request = error.requestOptions;
            request.headers['Authorization'] = 'Bearer $token';
            request.extra['sessionRetry'] = true;
            handler.resolve(await dio.fetch<dynamic>(request));
          } on SessionExpiredException {
            handler.next(error);
          }
        },
      ),
    );
  }

  void _allowUntrustedCert() {
    if (!kDebugMode) return;
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    };
  }
}
