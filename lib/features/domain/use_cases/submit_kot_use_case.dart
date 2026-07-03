import 'package:dartz/dartz.dart';

import '../../../error/failures.dart';
import '../../data/models/request/place_order_request.dart';
import '../../data/models/response/place_order_response.dart';
import '../repositories/repository.dart';

class SubmitKitchenOrderUseCase {
  final Repository repository;

  SubmitKitchenOrderUseCase(this.repository);

  Future<Either<Failure, KitchenOrderResponse>> call(
    PlaceOrderRequest params,
  ) async {
    return await repository.submitKitchenOrder(params);
  }
}
