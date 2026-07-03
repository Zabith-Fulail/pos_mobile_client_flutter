import 'package:d_pos/features/data/models/pos_models.dart';
import 'package:d_pos/features/data/models/request/login_request_model.dart';
import 'package:d_pos/features/data/models/response/login_response_model.dart';
import 'package:dartz/dartz.dart';

import '../../../error/failures.dart';
import '../../data/models/common/base_response.dart';
import '../../data/models/request/place_order_request.dart';
import '../../data/models/response/main_screen_response.dart';
import '../../data/models/response/place_order_response.dart';
import '../../data/models/response/print_response_model.dart';
import '../../data/models/response/running_orders_response_model.dart';

abstract class Repository {
  Future<Either<Failure, LoginResponse>> login(LoginRequest loginRequest);

  Future<Either<Failure, MainScreenResponse>> getMainScreenData();

  Future<Either<Failure, BaseResponse<RunningOrderData>>> getRunningOrders(
      int id);

  Future<Either<Failure, PrintResponseModel>> printRunningOrder(int orderId);

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, KitchenOrderResponse>> submitKitchenOrder(
      PlaceOrderRequest request);

  Future<Either<Failure, List<CategoryModel>>> getCategories();

  Future<Either<Failure, CategoryModel>> createCategory(
      String name, {
        String? imageBase64,
      });

  Future<Either<Failure, CategoryModel>> updateCategory(
      int id,
      String newName, {
        String? imageBase64,
        bool clearImage = false,
        bool? showLocalImage,
      });

  Future<Either<Failure, bool>> deleteCategory(int id);

  Future<Either<Failure, List<ProductModel>>> getProducts();

  Future<Either<Failure, ProductModel>> createProduct(
      String name,
      String alternativeName,
      double price,
      int categoryId, {
        String? imageBase64,
      });

  Future<Either<Failure, ProductModel>> updateProduct(
      int id,
      String name,
      double price,
      int categoryId, {
        String? imageBase64,
        bool clearImage = false,
        bool? showLocalImage,
      });

  Future<Either<Failure, bool>> deleteProduct(int id);

  Future<Either<Failure, List<ProductModel>>> getLocalProducts();
}