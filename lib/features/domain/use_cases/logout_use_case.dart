import 'package:dartz/dartz.dart';
import '../../../../error/failures.dart';
import '../repositories/repository.dart';

class LogoutUseCase {
  final Repository repository;

  LogoutUseCase(this.repository);

  Future<Either<Failure, void>> call() async {
    return await repository.logout();
  }
}