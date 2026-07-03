import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../../features/data/models/pos_models.dart';
import '../../../../../features/domain/use_cases/main_screen_data_use_case.dart';
import '../../../../error/error_messages.dart';
import '../../../../error/failures.dart';
import '../../../../utils/app_strings.dart';
import '../../../data/data_sources/local_data_sources.dart';
import '../../../data/models/request/place_order_request.dart';
import '../../../domain/repositories/repository.dart';
import '../../../domain/use_cases/categories_use_case.dart';
import '../../../domain/use_cases/submit_kot_use_case.dart';
import 'order_entry_state.dart';

class OrderEntryCubit extends Cubit<OrderEntryState> {
  final MainScreenDataUseCase mainScreenDataUseCase;
  final SubmitKitchenOrderUseCase submitKitchenOrderUseCase;
  final CategoriesUseCase categoriesUseCase;
  final Repository repository;
  final LocalDataSource localDataSource;

  List<ProductModel> _allProducts = [];
  List<ModifierModel> _allModifiers = [];
  List<CategoryModel> _categories = [];
  CategoryModel? _selectedCategory;
  static const branchName = 'pref_01';

  OrderEntryCubit({
    required this.repository,
    required this.localDataSource,
    required this.mainScreenDataUseCase,
    required this.submitKitchenOrderUseCase,
    required this.categoriesUseCase,
  }) : super(OrderEntryInitial());


  void searchProduct(String query) {
    if (state is OrderEntryLoaded) {
      final currentState = state as OrderEntryLoaded;

      final filteredList = _allProducts.where((p) =>
          p.name.toLowerCase().contains(query.toLowerCase())
      ).toList();

      emit(currentState.copyWith(currentProducts: filteredList));
    }
  }


  Future<void> loadInitialData() async {
    emit(OrderEntryLoading());
    final result = await mainScreenDataUseCase();

    result.fold(
      (failure) {

        if (failure is ConnectionFailure){
          emit(
            OrderEntryError(
              message: ErrorMessages().mapFailureToMessage(failure) ?? "",
            ),
          );
        }
        else if (failure is AuthorizedFailure) {
          emit(OrderEntryError(message: AppStrings.unAuthorizedDes));
        }
        else if (failure is ServerFailure) {
          emit(
            OrderEntryError(
              message:
                  failure.errorResponse.errorDescription ??
                  AppStrings.somethingWentWrong,
            ),
          );
        }
        else {
          emit(OrderEntryError(message: AppStrings.somethingWentWrong));
        }
      },
      (data) async {
        _allProducts = data.products;
        _allModifiers = data.modifiers;
        
        List<CategoryModel> categoriesToUse = data.categories;
        
        final localCategoriesResult = await categoriesUseCase.getAll();
        localCategoriesResult.fold(
          (failure) {
          },
          (localCategories) {
            if (localCategories.isNotEmpty) {
              categoriesToUse = localCategories;
            }
          },
        );
        
        _categories = categoriesToUse;

        if (categoriesToUse.isEmpty) {
          return;
        }

        final initialCategory = categoriesToUse.first;
        _selectedCategory = initialCategory;
        final initialProducts = _getProductForCategory(initialCategory.id);

        emit(
          OrderEntryLoaded(
            categories: categoriesToUse,
            currentProducts: initialProducts,
            selectedCategory: initialCategory,
            cartItems: const [],
          ),
        );
      },
    );
  }

   List<ModifierModel> get availableModifiers => _allModifiers;

   Future<void> refreshCategories() async {
     if (state is! OrderEntryLoaded) return;
     final currentState = state as OrderEntryLoaded;

     try {
       final localCategoriesResult = await categoriesUseCase.getAll();
       localCategoriesResult.fold(
         (failure) {
         },
         (localCategories) {
           if (localCategories.isNotEmpty) {
             _categories = localCategories;
             
             CategoryModel selectedCat = currentState.selectedCategory;
             if (!_categories.any((c) => c.id == selectedCat.id)) {
               selectedCat = _categories.first;
               _selectedCategory = selectedCat;
             }
             
             final updatedProducts = _getProductForCategory(selectedCat.id);
             
             emit(
               currentState.copyWith(
                 categories: _categories,
                 selectedCategory: selectedCat,
                 currentProducts: updatedProducts,
               ),
             );
           }
         },
       );
     } catch (e) {
       print(e);
     }
    }

   void selectCategory(CategoryModel category) {
    if (state is OrderEntryLoaded) {
      final currentState = state as OrderEntryLoaded;
      _selectedCategory = category;

      emit(
        currentState.copyWith(
          selectedCategory: category,
          currentProducts: _getProductForCategory(category.id),
        ),
      );
    }
  }

  List<ProductModel> _getProductForCategory(int categoryId) {
    return _allProducts.where((p) => p.categoryId == categoryId).toList();
  }

  void resetAfterSubmission() {
    if (_categories.isEmpty || _selectedCategory == null) {
      loadInitialData();
      return;
    }

    emit(
      OrderEntryLoaded(
        categories: _categories,
        selectedCategory: _selectedCategory!,
        currentProducts: _getProductForCategory(_selectedCategory!.id),
        cartItems: const [],
      ),
    );
  }

  void addToCart(ProductModel product) {
    if (state is OrderEntryLoaded) {
      final currentState = state as OrderEntryLoaded;

      final newItem = CartItem(
        uuid: const Uuid().v4(),
        product: product,
        quantity: 1,
      );

      final updatedCart = List<CartItem>.from(currentState.cartItems)
        ..add(newItem);
      emit(currentState.copyWith(cartItems: updatedCart));
    }
  }

  void updateQuantity(String itemUuid, int change) {
    if (state is OrderEntryLoaded) {
      final currentState = state as OrderEntryLoaded;

      final updatedCart =
          currentState.cartItems.map((item) {
            if (item.uuid == itemUuid) {
              final newQty = item.quantity + change;
              return newQty > 0 ? item.copyWith(quantity: newQty) : item;
            }
            return item;
          }).toList();

      emit(currentState.copyWith(cartItems: updatedCart));
    }
  }

  void updateCartItemDetails(
    String uuid,
    List<ModifierModel> newModifiers,
    String newNote,
  ) {
    if (state is OrderEntryLoaded) {
      final currentState = state as OrderEntryLoaded;

      final updatedCart =
          currentState.cartItems.map((item) {
            if (item.uuid == uuid) {
              return item.copyWith(modifiers: newModifiers, note: newNote);
            }
            return item;
          }).toList();

      emit(currentState.copyWith(cartItems: updatedCart));
    }
  }

  void clearCart() {
    if (state is OrderEntryLoaded) {
      emit((state as OrderEntryLoaded).copyWith(cartItems: []));
    }
  }

  void removeItem(String uuid) {
    if (state is OrderEntryLoaded) {
      final currentState = state as OrderEntryLoaded;

      final updatedCart =
          currentState.cartItems.where((item) => item.uuid != uuid).toList();

      emit(currentState.copyWith(cartItems: updatedCart));
    }
  }

  Future<void> submitOrder({
    required String customerId,
    required String customerName,
    required int orderType,
  }) async {
    if (state is! OrderEntryLoaded) return;
    final currentState = state as OrderEntryLoaded;

    if (currentState.cartItems.isEmpty) return;

    emit(OrderEntryLoading());

    try {
      double subTotal = 0;
      int totalItemsQty = 0;

      for (var item in currentState.cartItems) {
        double itemTotal = item.product.price * item.quantity;
        for (var mod in item.modifiers) {
          itemTotal += (mod.price * item.quantity);
        }
              subTotal += itemTotal;
        totalItemsQty += item.quantity;
      }

      final now = DateTime.now();
      final dateFormatter = DateFormat('yyyy-MM-dd');
      final timeFormatter = DateFormat('h:mm:ss a');
      final dateTimeFormatter = DateFormat('yyyy-MM-dd h:mm:ss a');

      List<OrderItemRequest> orderItems =
          currentState.cartItems.expand((cartItem) {
            return List.generate(cartItem.quantity, (index) {
              String modIdsStr = "";
              String modPricesStr = "";
              ModifiersJsonData? modJsonData;

              if (cartItem.modifiers.isNotEmpty) {
                modIdsStr = cartItem.modifiers.map((m) => m.id).join(',');
                modPricesStr = cartItem.modifiers
                    .map((m) => m.price.toStringAsFixed(2))
                    .join(',');

                final Map<int, List<ModifierModel>> groupedMods = {};
                for (var mod in cartItem.modifiers) {
                  if (!groupedMods.containsKey(mod.id)) {
                    groupedMods[mod.id] = [];
                  }
                  groupedMods[mod.id]!.add(mod);
                }

                List<ModifierItem> modItems =
                    groupedMods.entries.map((entry) {
                      final mod = entry.value.first;

                      final int totalQtyForLine = entry.value.length;
                      final double totalPrice = mod.price * totalQtyForLine;

                      return ModifierItem(
                        modifierId: mod.id,
                        modifierName: mod.name,
                        modifierPrice: mod.price,
                        totalQty: totalQtyForLine,
                        totalPrice: totalPrice,
                        units: [
                          ModifierUnit(
                            unit: 1,
                            qty: totalQtyForLine,
                            linePrice: totalPrice,
                          ),
                        ],
                      );
                    }).toList();

                modJsonData = ModifiersJsonData(
                  itemNote: cartItem.note,
                  modifiers: modItems,
                );
              } else if (cartItem.note.isNotEmpty) {
                modJsonData = ModifiersJsonData(
                  itemNote: cartItem.note,
                  modifiers: [],
                );
              }

              return OrderItemRequest(
                foodMenuId: cartItem.product.id,
                menuName: cartItem.product.name,
                menuUnitPrice: cartItem.product.price,
                qty: 1,
                modifiersId: modIdsStr,
                modifiersName: "",
                modifiersPrice: modPricesStr,
                modifiersJson: modJsonData,
              );
            });
          }).toList();

      final request = PlaceOrderRequest(
        saleNo: _generateSaleNo(),
        randomCode: _generateRandomCode(),
        customerId: customerId,
        customerName: customerName,
        status: "Pending",

        totalItemsInCart: orderItems.length,
        totalItemsInCartQty: totalItemsQty,

        subTotal: subTotal,
        totalPayable: subTotal,
        saleDate: dateFormatter.format(now),
        dateTime: dateTimeFormatter.format(now),
        orderTime: timeFormatter.format(now),
        orderType: orderType,
        items: orderItems,
      );

      final result = await submitKitchenOrderUseCase(request);

      result.fold(
        (failure) {
          String errorMsg = AppStrings.somethingWentWrong;
          if (failure is ServerFailure) {
            errorMsg = failure.errorResponse.errorDescription ?? errorMsg;
          }
          emit(OrderEntryError(message: errorMsg));
        },
        (response) {
          emit(OrderSubmissionSuccess(response: response));
        },
      );
    } catch (e) {
      emit(OrderEntryError(message: "Error preparing order: $e"));
    }
  }

  String _generateSaleNo() {
    final dateStr = DateFormat('yyMMdd').format(DateTime.now());
    final random = Random().nextInt(9999);
    return "POS-$dateStr-$random";
  }

  String _generateRandomCode() {
    final random = Random().nextInt(999999);
    return "RND-${DateFormat('yyMMdd').format(DateTime.now())}-$random";
  }

  Future<void> refreshAllLocalData() async {
    final localCatsResult = await categoriesUseCase.getAll();

    final localProdsResult = await repository.getLocalProducts();

    localCatsResult.fold((f) => null, (localCats) {
      localProdsResult.fold((f) => null, (localProds) {
        _categories = localCats;
        _allProducts = localProds;

        if (state is OrderEntryLoaded) {
          final currentState = state as OrderEntryLoaded;

          CategoryModel selectedCat = currentState.selectedCategory;
          if (!_categories.any((c) => c.id == selectedCat.id)) {
            selectedCat = _categories.isNotEmpty ? _categories.first : selectedCat;
          }

          emit(currentState.copyWith(
            categories: _categories,
            selectedCategory: selectedCat,
            currentProducts: _getProductForCategory(selectedCat.id),
          ));
        }
      });
    });
  }

  Future<String> getBranch() => localDataSource.getBranch();
}
