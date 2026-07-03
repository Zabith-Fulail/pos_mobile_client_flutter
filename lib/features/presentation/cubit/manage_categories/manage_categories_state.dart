import 'package:equatable/equatable.dart';
import '../../../data/models/pos_models.dart';

abstract class CategoriesState extends Equatable {
  const CategoriesState();
  @override
  List<Object?> get props => [];
}

class CategoriesInitial extends CategoriesState {}

class CategoriesLoading extends CategoriesState {}

class CategoriesLoaded extends CategoriesState {
  final List<CategoryModel> categories;
  const CategoriesLoaded({required this.categories});

  @override
  List<Object?> get props => [categories];
}

class CategoriesError extends CategoriesState {
  final String message;
  const CategoriesError({required this.message});

  @override
  List<Object?> get props => [message];
}

class CategoryActionLoading extends CategoriesState {
  final List<CategoryModel> categories;
  const CategoryActionLoading({required this.categories});

  @override
  List<Object?> get props => [categories];
}

class CategoryActionSuccess extends CategoriesState {
  final List<CategoryModel> categories;
  final String message;
  const CategoryActionSuccess({required this.categories, required this.message});

  @override
  List<Object?> get props => [categories, message];
}

class CategoryActionError extends CategoriesState {
  final List<CategoryModel> categories;
  final String message;
  const CategoryActionError({required this.categories, required this.message});

  @override
  List<Object?> get props => [categories, message];
}