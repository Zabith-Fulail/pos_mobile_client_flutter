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
import '../../domain/entity/extracted_order.dart';
import '../../domain/repositories/repository.dart';
import '../data_sources/remote_data_sources.dart';
import '../models/common/base_response.dart';
import '../models/request/extracted_order_model.dart';
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
        ModifierModel(id: 1, name: 'Extra Cheese', price: 1.50),
        ModifierModel(id: 2, name: 'Extra Chicken', price: 2.50),
        ModifierModel(id: 3, name: 'Extra Beef Patty', price: 3.00),
        ModifierModel(id: 4, name: 'Extra Fries', price: 2.00),
        ModifierModel(id: 5, name: 'Extra Sauce', price: 0.50),
        ModifierModel(id: 6, name: 'Spicy', price: 0.00),
        ModifierModel(id: 7, name: 'No Onion', price: 0.00),
        ModifierModel(id: 8, name: 'No Ice', price: 0.00),
      ],

      categories: [
        CategoryModel(
          id: 1,
          name: 'Burgers',
          imageUrl: 'https://loremflickr.com/600/600/burger?lock=1',
        ),
        CategoryModel(
          id: 2,
          name: 'Fries',
          imageUrl: 'https://loremflickr.com/600/600/french-fries?lock=2',
        ),
        CategoryModel(
          id: 3,
          name: 'Pizza',
          imageUrl: 'https://loremflickr.com/600/600/pizza?lock=3',
        ),
        CategoryModel(
          id: 4,
          name: 'Sandwiches',
          imageUrl: 'https://loremflickr.com/600/600/sandwich?lock=4',
        ),
        CategoryModel(
          id: 5,
          name: 'Rice',
          imageUrl: 'https://loremflickr.com/600/600/fried-rice?lock=5',
        ),
        CategoryModel(
          id: 6,
          name: 'Pasta',
          imageUrl: 'https://loremflickr.com/600/600/pasta?lock=6',
        ),
        CategoryModel(
          id: 7,
          name: 'Desserts',
          imageUrl: 'https://loremflickr.com/600/600/chocolate-cake?lock=7',
        ),
        CategoryModel(
          id: 8,
          name: 'Beverages',
          imageUrl: 'https://loremflickr.com/600/600/coffee?lock=8',
        ),
      ],

      products: [
        // ---------------- Burgers ----------------
        ProductModel(
          id: 1,
          name: 'Classic Beef Burger',
          alternativeName: null,
          price: 8.50,
          categoryId: 1,
          imageUrl: 'https://loremflickr.com/600/600/beef-burger?lock=11',
        ),
        ProductModel(
          id: 2,
          name: 'Cheese Burger',
          alternativeName: null,
          price: 9.00,
          categoryId: 1,
          imageUrl: 'https://loremflickr.com/600/600/cheeseburger?lock=12',
        ),
        ProductModel(
          id: 3,
          name: 'Chicken Burger',
          alternativeName: null,
          price: 8.00,
          categoryId: 1,
          imageUrl: 'https://loremflickr.com/600/600/chicken-burger?lock=13',
        ),
        ProductModel(
          id: 4,
          name: 'Double Beef Burger',
          alternativeName: null,
          price: 11.50,
          categoryId: 1,
          imageUrl: 'https://loremflickr.com/600/600/double-burger?lock=14',
        ),

        // ---------------- Fries ----------------
        ProductModel(
          id: 5,
          name: 'French Fries',
          alternativeName: null,
          price: 3.50,
          categoryId: 2,
          imageUrl: 'https://loremflickr.com/600/600/fries?lock=15',
        ),
        ProductModel(
          id: 6,
          name: 'Cheese Fries',
          alternativeName: null,
          price: 5.00,
          categoryId: 2,
          imageUrl: 'https://loremflickr.com/600/600/cheese-fries?lock=16',
        ),
        ProductModel(
          id: 7,
          name: 'Loaded Fries',
          alternativeName: null,
          price: 6.50,
          categoryId: 2,
          imageUrl: 'https://loremflickr.com/600/600/loaded-fries?lock=17',
        ),

        // ---------------- Pizza ----------------
        ProductModel(
          id: 8,
          name: 'Margherita Pizza',
          alternativeName: null,
          price: 11.00,
          categoryId: 3,
          imageUrl: 'https://loremflickr.com/600/600/margherita-pizza?lock=18',
        ),
        ProductModel(
          id: 9,
          name: 'Pepperoni Pizza',
          alternativeName: null,
          price: 13.00,
          categoryId: 3,
          imageUrl: 'https://loremflickr.com/600/600/pepperoni-pizza?lock=19',
        ),
        ProductModel(
          id: 10,
          name: 'BBQ Chicken Pizza',
          alternativeName: null,
          price: 14.50,
          categoryId: 3,
          imageUrl: 'https://loremflickr.com/600/600/bbq-pizza?lock=20',
        ),

        // ---------------- Sandwiches ----------------
        ProductModel(
          id: 11,
          name: 'Club Sandwich',
          alternativeName: null,
          price: 7.50,
          categoryId: 4,
          imageUrl: 'https://loremflickr.com/600/600/club-sandwich?lock=21',
        ),
        ProductModel(
          id: 12,
          name: 'Chicken Sandwich',
          alternativeName: null,
          price: 7.00,
          categoryId: 4,
          imageUrl: 'https://loremflickr.com/600/600/chicken-sandwich?lock=22',
        ),

        // ---------------- Rice ----------------
        ProductModel(
          id: 13,
          name: 'Chicken Fried Rice',
          alternativeName: null,
          price: 9.50,
          categoryId: 5,
          imageUrl: 'https://loremflickr.com/600/600/chicken-fried-rice?lock=23',
        ),
        ProductModel(
          id: 14,
          name: 'Seafood Fried Rice',
          alternativeName: null,
          price: 11.00,
          categoryId: 5,
          imageUrl: 'https://loremflickr.com/600/600/seafood-rice?lock=24',
        ),
        ProductModel(
          id: 15,
          name: 'Vegetable Fried Rice',
          alternativeName: null,
          price: 8.50,
          categoryId: 5,
          imageUrl: 'https://loremflickr.com/600/600/vegetable-rice?lock=25',
        ),

        // ---------------- Pasta ----------------
        ProductModel(
          id: 16,
          name: 'Chicken Alfredo',
          alternativeName: null,
          price: 12.50,
          categoryId: 6,
          imageUrl: 'https://loremflickr.com/600/600/alfredo-pasta?lock=26',
        ),
        ProductModel(
          id: 17,
          name: 'Spaghetti Bolognese',
          alternativeName: null,
          price: 12.00,
          categoryId: 6,
          imageUrl: 'https://loremflickr.com/600/600/spaghetti?lock=27',
        ),

        // ---------------- Desserts ----------------
        ProductModel(
          id: 18,
          name: 'Chocolate Cake',
          alternativeName: null,
          price: 5.00,
          categoryId: 7,
          imageUrl: 'https://loremflickr.com/600/600/chocolate-cake?lock=28',
        ),
        ProductModel(
          id: 19,
          name: 'Brownie',
          alternativeName: null,
          price: 4.50,
          categoryId: 7,
          imageUrl: 'https://loremflickr.com/600/600/brownie?lock=29',
        ),
        ProductModel(
          id: 20,
          name: 'Ice Cream Sundae',
          alternativeName: null,
          price: 4.00,
          categoryId: 7,
          imageUrl: 'https://loremflickr.com/600/600/ice-cream?lock=30',
        ),

        // ---------------- Beverages ----------------
        ProductModel(
          id: 21,
          name: 'Coca Cola',
          alternativeName: null,
          price: 2.50,
          categoryId: 8,
          imageUrl: 'https://loremflickr.com/600/600/coca-cola?lock=31',
        ),
        ProductModel(
          id: 22,
          name: 'Orange Juice',
          alternativeName: null,
          price: 3.50,
          categoryId: 8,
          imageUrl: 'https://loremflickr.com/600/600/orange-juice?lock=32',
        ),
        ProductModel(
          id: 23,
          name: 'Iced Coffee',
          alternativeName: null,
          price: 4.00,
          categoryId: 8,
          imageUrl: 'https://loremflickr.com/600/600/iced-coffee?lock=33',
        ),
        ProductModel(
          id: 24,
          name: 'Milkshake',
          alternativeName: null,
          price: 5.50,
          categoryId: 8,
          imageUrl: 'https://loremflickr.com/600/600/milkshake?lock=34',
        ),
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

  @override
  Future<Either<Failure, ExtractedOrderEntity>> extractOrderFromSpeech(String transcript) async {
    try {
      final ExtractedOrderModel result = await remoteDataSource.extractOrder(transcript);

      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
    } catch (e) {
      return Left(
          ServerFailure(ErrorResponseModel(errorDescription: e.toString())));
    }
  }
}