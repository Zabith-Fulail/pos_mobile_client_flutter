import 'package:dartz/dartz.dart';
import '../../../../error/failures.dart';
import '../../data/models/response/print_response_model.dart';
import '../repositories/repository.dart';

class PrintRunningOrderUseCase {
  final Repository repository;

  PrintRunningOrderUseCase(this.repository);

  Future<Either<Failure, PrintResponseModel>> call(int orderId) async {
    return await repository.printRunningOrder(orderId);
  }
}