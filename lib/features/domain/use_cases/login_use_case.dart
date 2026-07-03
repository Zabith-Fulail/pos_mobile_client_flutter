import 'package:d_pos/features/data/models/request/login_request_model.dart';
import 'package:d_pos/features/data/models/response/login_response_model.dart';
import 'package:dartz/dartz.dart';

import '../../../../error/failures.dart';
import '../repositories/repository.dart';

class LoginUseCase {
  final Repository repository;

  LoginUseCase(this.repository);

  Future<Either<Failure, LoginResponse>> call(
    LoginRequest loginRequest,
  ) async => await repository.login(loginRequest);
}
