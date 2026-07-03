import 'package:d_pos/features/presentation/cubit/running_orders/running_orders_state.dart';
import 'package:d_pos/utils/app_constants.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../error/failures.dart';
import '../../../../utils/app_strings.dart';
import '../../../domain/use_cases/get_running_orders_use_case.dart';
import '../../../domain/use_cases/print_running_order_use_case.dart';

class RunningOrdersCubit extends Cubit<RunningOrdersState> {
  final GetRunningOrdersUseCase getRunningOrdersUseCase;
  final PrintRunningOrderUseCase printRunningOrderUseCase;

  RunningOrdersCubit({
    required this.getRunningOrdersUseCase,
    required this.printRunningOrderUseCase,
  }) : super(RunningOrdersInitial());

  Future<void> fetchRunningOrders({bool isBackgroundRefresh = false}) async {
    if (!isBackgroundRefresh) {
      emit(RunningOrdersLoading());
    }

    final result = await getRunningOrdersUseCase(
      AppConstants.userId!,
    );

    result.fold(
      (failure) {
        String msg = AppStrings.somethingWentWrong;
        if (failure is ServerFailure) {
          msg = failure.errorResponse.errorDescription ?? msg;
        }
        emit(RunningOrdersError(message: msg));
      },
      (baseResponse) {
        final orders = baseResponse.data?.runningOrders ?? [];
        orders.sort((a, b) => b.id.compareTo(a.id));
        emit(RunningOrdersLoaded(orders: orders));
      },
    );
  }

  Future<void> printOrder(
    int orderId, {
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    final result = await printRunningOrderUseCase(orderId);

    result.fold(
      (failure) {
        String msg = "Print Failed";
        if (failure is ServerFailure) {
          msg = failure.errorResponse.errorDescription ?? msg;
        }
        onError(msg);
      },
      (response) {
        onSuccess(response.message);
      },
    );
  }
}
