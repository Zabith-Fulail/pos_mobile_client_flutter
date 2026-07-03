import 'package:equatable/equatable.dart';
import '../../../data/models/pos_models.dart';

abstract class ProductsState extends Equatable {
  const ProductsState();

  @override
  List<Object?> get props => [];
}

class ProductsInitial extends ProductsState {}

class ProductsLoading extends ProductsState {}

class ProductsLoaded extends ProductsState {
  final List<ProductModel> products;
  const ProductsLoaded(this.products);

  @override
  List<Object?> get props => [products];
}

class ProductActionLoading extends ProductsState {
  final List<ProductModel> products;
  const ProductActionLoading(this.products);

  @override
  List<Object?> get props => [products];
}

class ProductActionSuccess extends ProductsState {
  final List<ProductModel> products;
  final String message;
  const ProductActionSuccess(this.products, this.message);

  @override
  List<Object?> get props => [products, message];
}

class ProductsError extends ProductsState {
  final String message;
  const ProductsError(this.message);

  @override
  List<Object?> get props => [message];
}

class ProductActionError extends ProductsState {
  final List<ProductModel> products;
  final String message;
  const ProductActionError(this.products, this.message);

  @override
  List<Object?> get props => [products, message];
}