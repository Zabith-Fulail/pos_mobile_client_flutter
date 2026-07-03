import 'dart:convert';
import 'dart:io';

import 'package:d_pos/features/data/models/request/login_request_model.dart';
import 'package:d_pos/features/data/models/response/login_response_model.dart';
import 'package:d_pos/features/data/models/pos_models.dart';
import 'package:d_pos/utils/app_constants.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/network_info.dart';
import '../../../core/service/image_downloader_service.dart';
import '../../../error/exceptions.dart';
import '../../../error/failures.dart';
import '../../domain/repositories/repository.dart';
import '../data_sources/remote_data_sources.dart';
import '../models/common/base_response.dart';
import '../models/request/place_order_request.dart';
import '../models/response/error_response_model.dart';
import '../models/response/main_screen_response.dart';
import '../models/response/place_order_response.dart';
import '../models/response/print_response_model.dart';
import '../models/response/running_orders_response_model.dart';

class RepositoryImpl implements Repository {
  final RemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  RepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  MainScreenResponse? _cachedMainScreenData;

  static const String _categoriesKey = 'local_categories';
  static const String _productsKey = 'local_products';


  Future<List<CategoryModel>?> _loadLocalCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_categoriesKey);
    if (raw == null) return null;
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveLocalCategories(List<CategoryModel> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _categoriesKey,
      jsonEncode(categories.map((c) => c.toJson()).toList()),
    );
  }

  int _nextLocalId(List<CategoryModel> categories) {
    if (categories.isEmpty) return 1;
    return categories.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;
  }


  Future<List<ProductModel>?> _loadLocalProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_productsKey);
    if (raw == null) return null;
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => ProductModel.fromJson(e)).toList();
  }

  Future<void> _saveLocalProducts(List<ProductModel> products) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _productsKey,
      jsonEncode(products.map((p) => p.toJson()).toList()),
    );
  }


  @override
  Future<Either<Failure, LoginResponse>> login(
      LoginRequest loginRequest) async {
    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.login(loginRequest);
        if (response.accessToken.isNotEmpty) {
          AppConstants.accessToken = response.accessToken;
        }
        AppConstants.userId = response.user.id;
        return Right(response);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.errorResponseModel));
      } on UnAuthorizedException catch (e) {
        return Left(AuthorizedFailure(e.errorResponseModel));
      } catch (e) {
        return Left(
            ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
      }
    } else {
      return Left(ConnectionFailure());
    }
  }

  MainScreenResponse _mockMainScreenData() {
    return const MainScreenResponse(
      waiter: WaiterModel(
        id: 1,
        fullName: 'Demo Waiter',
        emailAddress: 'demo@example.com',
      ),
      modifiers: [
        ModifierModel(id: 1, name: 'Extra Cheese', price: 1.5),
        ModifierModel(id: 2, name: 'Spicy', price: 0.0),
        ModifierModel(id: 3, name: 'No Onion', price: 0.0),
      ],
      categories: [
        CategoryModel(id: 1, name: 'Beverages'),
        CategoryModel(id: 2, name: 'Burgers'),
        CategoryModel(id: 3, name: 'Desserts'),
      ],
      products: [
        ProductModel(id: 1, name: 'Iced Coffee', alternativeName: null, price: 3.5, categoryId: 1),
        ProductModel(id: 2, name: 'Fresh Juice', alternativeName: null, price: 2.5, categoryId: 1),
        ProductModel(id: 3, name: 'Cheese Burger', alternativeName: null, price: 6.0, categoryId: 2),
        ProductModel(id: 4, name: 'Chicken Burger', alternativeName: null, price: 5.5, categoryId: 2),
        ProductModel(id: 5, name: 'Chocolate Cake', alternativeName: null, price: 4.0, categoryId: 3),
      ],
    );
  }
  @override
  Future<Either<Failure, MainScreenResponse>> getMainScreenData() async {
    if (AppConstants.useMockData) {
      return Right(_mockMainScreenData());
    }

    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.getMainScreenData();

        final localCats = await _loadLocalCategories() ?? [];
        final List<CategoryModel> syncedCats = [];
        final serverCatIds = response.categories.map((c) => c.id).toSet();

        for (var serverCat in response.categories) {
          final localMatch =
              localCats.where((c) => c.id == serverCat.id).firstOrNull;
          String? finalPath = localMatch?.localPath;

          if ((finalPath == null || finalPath.isEmpty) &&
              serverCat.imageUrl != null &&
              serverCat.imageUrl!.isNotEmpty) {
            finalPath = await ImageStorageService.downloadAndSaveImage(
              serverCat.imageUrl!,
              'cat_${serverCat.id}',
            );
          }

          syncedCats.add(serverCat.copyWith(
            localPath: finalPath,
            name: localMatch?.name ?? serverCat.name,
            showLocalImage: localMatch?.showLocalImage ?? true,
          ));
        }

        syncedCats
            .addAll(localCats.where((c) => !serverCatIds.contains(c.id)));
        
        final filteredCats = CategoryModel.filterValidCategories(syncedCats);
        
        await _saveLocalCategories(filteredCats);

        final localProds = await _loadLocalProducts() ?? [];
        final List<ProductModel> syncedProds = [];
        final serverProdIds = response.products.map((p) => p.id).toSet();

        for (var serverProd in response.products) {
          final localMatch =
              localProds.where((p) => p.id == serverProd.id).firstOrNull;
          String? finalPath = localMatch?.localPath;

          if ((finalPath == null || finalPath.isEmpty) &&
              serverProd.imageUrl != null &&
              serverProd.imageUrl!.isNotEmpty) {
            finalPath = await ImageStorageService.downloadAndSaveImage(
              serverProd.imageUrl!,
              'prod_${serverProd.id}',
            );
          }

          syncedProds.add(serverProd.copyWith(
            localPath: finalPath,
            name: localMatch?.name ?? serverProd.name,
            showLocalImage: localMatch?.showLocalImage ?? true,
          ));
        }

        syncedProds
            .addAll(localProds.where((p) => !serverProdIds.contains(p.id)));
        await _saveLocalProducts(syncedProds);

        return Right(
            response.copyWith(categories: filteredCats, products: syncedProds));
      } catch (e) {
        return Left(
            ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
      }
    } else {
      return Left(ConnectionFailure());
    }
  }


  @override
  Future<Either<Failure, BaseResponse<RunningOrderData>>> getRunningOrders(
      int id) async {
    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.getRunningOrders(id);
        return Right(response);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.errorResponseModel));
      } on UnAuthorizedException catch (e) {
        return Left(AuthorizedFailure(e.errorResponseModel));
      } catch (e) {
        return Left(
            ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
      }
    } else {
      return Left(ConnectionFailure());
    }
  }


  @override
  Future<Either<Failure, PrintResponseModel>> printRunningOrder(
      int orderId) async {
    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.printRunningOrder(orderId);
        return Right(response);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.errorResponseModel));
      } on UnAuthorizedException catch (e) {
        return Left(AuthorizedFailure(e.errorResponseModel));
      } catch (e) {
        return Left(
            ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
      }
    } else {
      return Left(ConnectionFailure());
    }
  }


  @override
  Future<Either<Failure, void>> logout() async {
    try {
      AppConstants.accessToken = '';
      AppConstants.userId = null;
      _cachedMainScreenData = null;
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure());
    }
  }


  @override
  Future<Either<Failure, KitchenOrderResponse>> submitKitchenOrder(
      PlaceOrderRequest request) async {
    if (await networkInfo.isConnected) {
      try {
        final response = await remoteDataSource.submitKitchenOrder(request);
        return Right(response);
      } on ServerException catch (e) {
        return Left(ServerFailure(e.errorResponseModel));
      } on UnAuthorizedException catch (e) {
        return Left(AuthorizedFailure(e.errorResponseModel));
      } catch (e) {
        return Left(
            ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
      }
    } else {
      return Left(ConnectionFailure());
    }
  }


  @override
  Future<Either<Failure, List<CategoryModel>>> getCategories() async {
    try {
      final local = await _loadLocalCategories();
      if (local != null) {
        final filtered = CategoryModel.filterValidCategories(local);
        return Right(filtered);
      }

      if (_cachedMainScreenData != null) {
        final cats = _cachedMainScreenData!.categories;
        final filtered = CategoryModel.filterValidCategories(cats);
        await _saveLocalCategories(filtered);
        return Right(filtered);
      }

      return const Right([]);
    } catch (e) {
      return Left(
          ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
    }
  }

  @override
  Future<Either<Failure, CategoryModel>> createCategory(String name,
      {String? imageBase64}) async {
    try {
      final current = await _loadLocalCategories() ?? [];
      final newCat = CategoryModel(
        id: _nextLocalId(current),
        name: name,
        localPath: imageBase64,
      );
      await _saveLocalCategories([...current, newCat]);
      return Right(newCat);
    } catch (e) {
      return Left(
          ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
    }
  }

  @override
  Future<Either<Failure, CategoryModel>> updateCategory(
      int id,
      String newName, {
        String? imageBase64,
        bool clearImage = false,
        bool? showLocalImage,
      }) async {
    try {
      final current = await _loadLocalCategories() ?? [];
      final index = current.indexWhere((c) => c.id == id);
      if (index == -1) {
        return Left(ServerFailure(
            ErrorResponseModel(errorDescription: 'Category not found')));
      }

      String? finalPath = current[index].localPath;

      if (clearImage) {
        finalPath = null;
      } else if (imageBase64 != null && imageBase64.isNotEmpty) {
        finalPath = imageBase64;
      }

      final updated = current[index].copyWith(
        name: newName,
        localPath: finalPath,
        showLocalImage: showLocalImage ?? current[index].showLocalImage,
      );

      final list = List<CategoryModel>.from(current)..[index] = updated;
      await _saveLocalCategories(list);
      return Right(updated);
    } catch (e) {
      return Left(
          ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteCategory(int id) async {
    try {
      final current = await _loadLocalCategories() ?? [];
      await _saveLocalCategories(current.where((c) => c.id != id).toList());
      return const Right(true);
    } catch (e) {
      return Left(
          ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
    }
  }


  @override
  Future<Either<Failure, List<ProductModel>>> getProducts() async {
    try {
      final local = await _loadLocalProducts();
      return Right(local ?? []);
    } catch (e) {
      return Left(
          ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
    }
  }

  @override
  Future<Either<Failure, ProductModel>> createProduct(
      String name, String alternativeName, double price, int categoryId,
      {String? imageBase64}) async {
    try {
      final current = await _loadLocalProducts() ?? [];
      final newId = current.isEmpty
          ? 1
          : current.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1;

      String? finalPath;
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        finalPath = await _saveBase64AsFile(imageBase64, 'prod_$newId');
      }

      final newProd = ProductModel(
        id: newId,
        alternativeName: alternativeName,
        name: name,
        price: price,
        categoryId: categoryId,
        localPath: finalPath,
      );

      await _saveLocalProducts([...current, newProd]);
      debugPrint(
          "PRODUCT CREATED: ${newProd.name} | PATH: ${newProd.localPath}");
      return Right(newProd);
    } catch (e) {
      return Left(
          ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
    }
  }

  @override
  Future<Either<Failure, ProductModel>> updateProduct(
      int id,
      String name,
      double price,
      int categoryId, {
        String? imageBase64,
        bool clearImage = false,
        bool? showLocalImage,
      }) async {
    try {
      final current = await _loadLocalProducts() ?? [];
      final index = current.indexWhere((p) => p.id == id);
      if (index == -1) {
        return Left(ServerFailure(
            ErrorResponseModel(errorDescription: "Product not found")));
      }

      String? finalPath = current[index].localPath;

      if (clearImage) {
        finalPath = null;
      } else if (imageBase64 != null && imageBase64.isNotEmpty) {
        if (imageBase64.startsWith('/')) {
          finalPath = imageBase64;
        } else {
          finalPath =
          await _saveBase64AsFile(imageBase64, 'prod_updated_$id');
        }
      }

      final updated = current[index].copyWith(
        name: name,
        price: price,
        categoryId: categoryId,
        localPath: finalPath,
        showLocalImage: showLocalImage ?? current[index].showLocalImage,
      );

      final list = List<ProductModel>.from(current)..[index] = updated;
      await _saveLocalProducts(list);

      debugPrint(
          "PRODUCT UPDATED: ${updated.name} | PATH: ${updated.localPath} | SHOW_LOCAL: ${updated.showLocalImage}");
      return Right(updated);
    } catch (e) {
      return Left(
          ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteProduct(int id) async {
    try {
      final current = await _loadLocalProducts() ?? [];
      await _saveLocalProducts(current.where((p) => p.id != id).toList());
      return const Right(true);
    } catch (e) {
      return Left(
          ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
    }
  }

  @override
  Future<Either<Failure, List<ProductModel>>> getLocalProducts() async {
    try {
      final local = await _loadLocalProducts();
      return Right(local ?? []);
    } catch (e) {
      return Left(
          ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
    }
  }


  Future<String?> _saveBase64AsFile(String base64Str, String fileName) async {
    try {
      final cleanBase64 = base64Str.trim().split(',').last;
      final directory = await getApplicationDocumentsDirectory();
      final dirPath = p.join(directory.path, 'product_images');
      await Directory(dirPath).create(recursive: true);
      final filePath = p.join(dirPath, '$fileName.jpg');
      final file = File(filePath);
      await file.writeAsBytes(base64Decode(cleanBase64));
      return filePath;
    } catch (e) {
      debugPrint("_saveBase64AsFile FAILED: $e");
      return null;
    }
  }
}