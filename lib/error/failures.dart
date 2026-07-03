import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../features/data/models/response/error_response_model.dart';

abstract class Failure extends Equatable {
  const Failure();

  @override
  List<Object?> get props => [];
}

class ServerFailure extends Failure {
  final ErrorResponseModel errorResponse;
  final DioExceptionType? errorType;

  const ServerFailure(this.errorResponse, {this.errorType});

  @override
  List<Object?> get props => [errorResponse, errorType];
}

class CacheFailure extends Failure {
  @override
  List<Object?> get props => [];
}

class ConnectionFailure extends Failure {
  @override
  List<Object?> get props => [];
}

class AuthorizedFailure extends Failure {
  final ErrorResponseModel errorResponse;

  const AuthorizedFailure(this.errorResponse);

  @override
  List<Object?> get props => [errorResponse];
}
