import '../../../data/models/response/running_orders_response_model.dart';

abstract class RunningOrdersState {}

class RunningOrdersInitial extends RunningOrdersState {}

class RunningOrdersLoading extends RunningOrdersState {}

class RunningOrdersLoaded extends RunningOrdersState {
  final List<RunningOrderModel> orders;

  RunningOrdersLoaded({required this.orders});
}

class RunningOrdersError extends RunningOrdersState {
  final String message;

  RunningOrdersError({required this.message});
}
