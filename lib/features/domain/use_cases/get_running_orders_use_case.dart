import 'package:dartz/dartz.dart';
import '../../../../error/failures.dart';
import '../../data/models/common/base_response.dart';
import '../../data/models/response/running_orders_response_model.dart';
import '../repositories/repository.dart';

class GetRunningOrdersUseCase {
  final Repository repository;

  GetRunningOrdersUseCase(this.repository);

  Future<Either<Failure, BaseResponse<RunningOrderData>>> call(int id) async {
    return await repository.getRunningOrders(id);
  }
}