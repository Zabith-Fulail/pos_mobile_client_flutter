import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';

import '../../error/exceptions.dart';
import '../../features/data/models/response/error_response_model.dart';
import '../../features/presentation/widget/app_dialog.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_enum.dart';
import '../../utils/navigation_routes.dart';

class ApiHelper {
  final Dio dio;

  ApiHelper({required this.dio}) {
    dio.options
      ..baseUrl = "https://sample.com/api/"
      ..connectTimeout = const Duration(seconds: AppConstants.connectionTimeout)
      ..receiveTimeout = const Duration(seconds: AppConstants.connectionTimeout)
      ..headers = {"Content-Type": "application/json", "Accept": "*/*"};
    dio.interceptors.addAll([
      InterceptorsWrapper(
        // onRequest: (options, handler) async {
        //   final token = AppConstants.accessToken;
        //   if (token != null && token.isNotEmpty) {
        //     options.headers["Authorization"] = "Bearer $token";
        //   }
        //   if (options.data != null) {
        //     log("Request Body: ${_prettyJson(options.data)}");
        //   }
        //   return handler.next(options);
        // },
        onRequest: (options, handler) async {
          // 👇 1. Check if the bypass flag is set to true
          final bypassAuth = options.extra['bypass_auth'] == true;

          // Only attach the Bearer token if we are NOT bypassing auth
          if (!bypassAuth) {
            final token = AppConstants.accessToken;
            if (token != null && token.isNotEmpty) {
              options.headers["Authorization"] = "Bearer $token";
            }
          } else {
            // Ensure no lingering Authorization header exists if bypassed
            options.headers.remove("Authorization");
          }

          if (options.data != null) {
            log("Request Body: ${_prettyJson(options.data)}");
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          log("Response Body: ${_prettyJson(response.data)}");
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          final response = e.response;
          final requestOptions = e.requestOptions;

          if (response?.statusCode == 401) {
            final serverErrorCode = response?.data['statusCode'];

            if (serverErrorCode == "010") {
              log("Invalid Token (010) detected. Logging out...");

              AppConstants.accessToken = null;

              final context = Routes.navigatorKey.currentContext;

              if (context != null) {
                Future.delayed(Duration.zero, () {
                  showAppDialog(
                    message:
                        "Your session is invalid or has expired. Please login again.",
                    title: "Session Expired",
                    context: context,
                    type: AppDialogType.error,
                    onConfirmPressed: () {
                      Navigator.of(context).pop();

                    },
                    confirmButtonText: "ok",
                  );
                });
              }
              return handler.reject(e);
            }

            if (serverErrorCode == "011") {
              if (!_isRefreshing) {
                _isRefreshing = true;
                final newToken = await _refreshToken();
                _isRefreshing = false;

                if (newToken != null) {
                  for (final retry in _retryQueue) {
                    await retry(newToken);
                  }
                  _retryQueue.clear();

                  final opts = requestOptions.copyWith(
                    headers: {
                      ...requestOptions.headers,
                      "Authorization": "Bearer $newToken",
                    },
                  );
                  final response = await dio.fetch(opts);
                  return handler.resolve(response);
                } else {
                  AppConstants.accessToken = null;
                  final context = Routes.navigatorKey.currentContext;

                  if (context != null) {
                    Future.delayed(Duration.zero, () {
                      showAppDialog(
                        message:
                            "Your session is invalid or has expired. Please login again.",
                        title: "Session Expired",
                        context: context,
                        type: AppDialogType.error,
                        onConfirmPressed: () {
                          Navigator.of(context).pop();

                          ///todo : uncomment this
                          // Navigate to Login and remove all back stack
                          // Routes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
                          //   Routes.kMobileNumberView,
                          //       (route) => false,
                          // );
                        },
                        // cancelButtonText: "Cancel",
                        confirmButtonText: "ok",
                      );
                    });
                  }
                  return handler.reject(e);
                }
              } else {
                _retryQueue.add((String token) async {
                  final opts = requestOptions.copyWith(
                    headers: {
                      ...requestOptions.headers,
                      "Authorization": "Bearer $token",
                    },
                  );
                  final response = await dio.fetch(opts);
                  handler.resolve(response);
                });
                return;
              }
            }
          }
          return handler.next(e);
        },
      ),
      LogInterceptor(requestBody: false, responseBody: false),
    ]);
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      },
    );
  }

  bool _isRefreshing = false;
  final List<Future<void> Function(String)> _retryQueue = [];

  Future<String?> _refreshToken() async {
    try {
      final refreshToken = AppConstants.accessToken;
      if (refreshToken == null) return null;

      final response = await dio.post(
        "mobile/auth/refresh-token",
        data: {"refreshToken": refreshToken},
        options: Options(headers: {"Authorization": null}),
      );

      if (response.statusCode == 200 && response.data['statusCode'] == "000") {
        final responseData = response.data['data'];

        final newAccessToken = responseData['token'];

        final newRefreshToken = responseData['refreshToken'];

        if (newAccessToken != null) {
          AppConstants.accessToken = newAccessToken;
          // await source.saveAccessToken(newAccessToken);
          // source.setAccessToken(newAccessToken);

          if (newRefreshToken != null) {
            AppConstants.refreshToken = newAccessToken;
            // await source.setRefreshToken(newRefreshToken);
          }

          return newAccessToken;
        }
      }

      return null;
    } catch (e) {
      log("Token Refresh Failed: $e");
      return null;
    }
  }

  String _prettyJson(dynamic data) {
    try {
      return jsonEncode(data);
    } catch (e) {
      return data.toString();
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    try {
      final response = await dio.get(path, queryParameters: queryParams);
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 ||
          e.response?.statusCode == 401 ||
          e.response?.statusCode == 404) {
        log("DioException ${e.response?.data}");
        throw ServerException(ErrorResponseModel.fromJson(e.response?.data));
      }
      log("DioException ${e.message}");
      throw ServerException(ErrorResponseModel(errorDescription: e.message));
    }
  }

  Future<dynamic> post(String path, {dynamic data,Options? options,}) async {
    try {
      final response = await dio.post(path, data: data, options: options,);
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 ||
          e.response?.statusCode == 401 ||
          e.response?.statusCode == 500) {
        log("DioException ${e.response?.data}");
        try {
          throw ServerException(ErrorResponseModel.fromJson(e.response?.data));
        } catch (_) {
          throw ServerException(ErrorResponseModel(
            errorDescription: e.response?.statusMessage ?? e.message,
          ));
        }
      }
      log("DioException ${e.message}");
      throw ServerException(ErrorResponseModel(errorDescription: e.message));
    }
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    try {
      final response = await dio.put(path, data: data);
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 ||
          e.response?.statusCode == 401 ||
          e.response?.statusCode == 500) {
        log("DioException ${e.response?.data}");
        throw ServerException(ErrorResponseModel.fromJson(e.response?.data));
      }
      log("DioException ${e.message}");
      throw ServerException(ErrorResponseModel(errorDescription: e.message));
    }
  }

  Future<Response> delete(String path, {dynamic data}) async {
    return await dio.delete(path, data: data);
  }
}
