import 'package:equatable/equatable.dart';

import '../../../data/models/pos_models.dart';
import '../../../data/models/response/place_order_response.dart';

abstract class OrderEntryState extends Equatable {
  const OrderEntryState();

  @override
  List<Object> get props => [];
}

class OrderEntryInitial extends OrderEntryState {}

class OrderEntryLoading extends OrderEntryState {}

class OrderEntryLoaded extends OrderEntryState {
  final List<CategoryModel> categories;
  final List<ProductModel> currentProducts;
  final CategoryModel selectedCategory;
  final List<CartItem> cartItems;

  const OrderEntryLoaded({
    required this.categories,
    required this.currentProducts,
    required this.selectedCategory,
    required this.cartItems,
  });

  double get grandTotal => cartItems.fold(0, (sum, item) => sum + item.total);

  OrderEntryLoaded copyWith({
    List<CategoryModel>? categories,
    List<ProductModel>? currentProducts,
    CategoryModel? selectedCategory,
    List<CartItem>? cartItems,
  }) {
    return OrderEntryLoaded(
      categories: categories ?? this.categories,
      currentProducts: currentProducts ?? this.currentProducts,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      cartItems: cartItems ?? this.cartItems,
    );
  }

  @override
  List<Object> get props => [
    categories,
    currentProducts,
    selectedCategory,
    cartItems,
  ];
}

class OrderEntryError extends OrderEntryState {
  final String message;

  const OrderEntryError({required this.message});
}

class OrderSubmissionSuccess extends OrderEntryState {
  final KitchenOrderResponse response;

  const OrderSubmissionSuccess({required this.response});
}
