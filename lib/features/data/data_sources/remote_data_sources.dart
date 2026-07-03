import 'package:d_pos/features/data/models/request/login_request_model.dart';
import 'package:d_pos/features/data/models/response/login_response_model.dart';

import '../../../core/network/api_helper.dart';
import '../models/common/base_response.dart';
import '../models/request/place_order_request.dart';
import '../models/response/main_screen_response.dart';
import '../models/response/place_order_response.dart';
import '../models/response/print_response_model.dart';
import '../models/response/running_orders_response_model.dart';


abstract class RemoteDataSource {
  Future<LoginResponse> login(LoginRequest loginRequest);

  Future<MainScreenResponse> getMainScreenData();

  Future<BaseResponse<RunningOrderData>> getRunningOrders(int id);

  Future<PrintResponseModel> printRunningOrder(int orderId);

  Future<KitchenOrderResponse> submitKitchenOrder(PlaceOrderRequest request);
}

class RemoteDataSourceImpl implements RemoteDataSource {
  final ApiHelper apiHelper;

  RemoteDataSourceImpl({required this.apiHelper});

  @override
  Future<LoginResponse> login(LoginRequest loginRequest) async {
    try {
      final response = await apiHelper.post(
        "login",
        data: loginRequest.toJson(),
      );
      return LoginResponse.fromJson(response);
    } on Exception {
      rethrow;
    }
  }

  @override
  Future<MainScreenResponse> getMainScreenData() async {
    try {
      final response = await apiHelper.get("main-screen-data");
      return MainScreenResponse.fromJson(response['data']);
    } on Exception {
      rethrow;
    }
  }

  @override
  Future<BaseResponse<RunningOrderData>> getRunningOrders(int id) async {
    try {
      final response = await apiHelper.get("running-orders/$id");
      return BaseResponse<RunningOrderData>.fromJson(
        response,
            (data) => RunningOrderData.fromJson(data),
      );
    } on Exception {
      rethrow;
    }
  }

  @override
  Future<PrintResponseModel> printRunningOrder(int orderId) async {
    try {
      final response = await apiHelper.post(
        "running-orders/print/$orderId",
        data: {},
      );
      return PrintResponseModel.fromJson(response);
    } on Exception {
      rethrow;
    }
  }

  @override
  Future<KitchenOrderResponse> submitKitchenOrder(PlaceOrderRequest request) async {
    try {
      final response = await apiHelper.post(
        "waiter/kitchen-orders/submit",
        data: request.toJson(),
      );
      return KitchenOrderResponse.fromJson(response);
    } on Exception {
      rethrow;
    }
  }
}