import 'package:dio/dio.dart';

import '../features/data/models/response/error_response_model.dart';

class ServerException implements Exception {
  final ErrorResponseModel errorResponseModel;
  final DioExceptionType? errorType;

  ServerException(this.errorResponseModel, {this.errorType});
}

class CacheException implements Exception {}

class UnAuthorizedException implements Exception {
  final ErrorResponseModel errorResponseModel;

  UnAuthorizedException(this.errorResponseModel);
}

class DioExceptions implements Exception {
  final ErrorResponseModel? errorResponseModel;

  DioExceptions({this.errorResponseModel});
}
