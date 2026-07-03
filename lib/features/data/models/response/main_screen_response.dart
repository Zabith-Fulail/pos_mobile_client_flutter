import 'package:equatable/equatable.dart';

import '../pos_models.dart';

class MainScreenResponse extends Equatable {
  final WaiterModel waiter;
  final List<ModifierModel> modifiers;
  final List<CategoryModel> categories;
  final List<ProductModel> products;

  const MainScreenResponse({
    required this.waiter,
    required this.modifiers,
    required this.categories,
    required this.products,
  });

  factory MainScreenResponse.fromJson(Map<String, dynamic> json) {
    return MainScreenResponse(
      waiter: WaiterModel.fromJson(json['waiter']),
      modifiers: (json['modifiers'] as List)
          .map((i) => ModifierModel.fromJson(i))
          .toList(),
      categories: (json['categories'] as List)
          .map((i) => CategoryModel.fromJson(i))
          .toList(),
      products: (json['products'] as List)
          .map((i) => ProductModel.fromJson(i))
          .toList(),
    );
  }
  MainScreenResponse copyWith({
    WaiterModel? waiter,
    List<ModifierModel>? modifiers,
    List<CategoryModel>? categories,
    List<ProductModel>? products,
  }) {
    return MainScreenResponse(
      waiter: waiter ?? this.waiter,
      modifiers: modifiers ?? this.modifiers,
      categories: categories ?? this.categories,
      products: products ?? this.products,
    );
  }
  @override
  List<Object?> get props => [waiter, modifiers, categories, products];
}

class WaiterModel extends Equatable {
  final int id;
  final String fullName;
  final String emailAddress;

  const WaiterModel({
    required this.id,
    required this.fullName,
    required this.emailAddress,
  });

  factory WaiterModel.fromJson(Map<String, dynamic> json) {
    return WaiterModel(
      id: json['id'],
      fullName: json['full_name'],
      emailAddress: json['email_address'],
    );
  }

  @override
  List<Object?> get props => [id, fullName, emailAddress];
}
