import 'package:dartz/dartz.dart';
import '../../../../error/failures.dart';
import '../../data/models/response/main_screen_response.dart';
import '../repositories/repository.dart';

class MainScreenDataUseCase {
  final Repository repository;

  MainScreenDataUseCase(this.repository);

  Future<Either<Failure, MainScreenResponse>> call() async {
    return await repository.getMainScreenData();
  }
}