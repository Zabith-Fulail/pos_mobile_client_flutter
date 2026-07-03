import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/pos_models.dart';
import '../../../domain/use_cases/categories_use_case.dart';
import 'manage_categories_state.dart';

/// CategoriesUseCase contract (adapt to your domain layer):
/// - Future getCategories()
/// - Future createCategory(String name)
/// - Future updateCategory(int id, String name)
/// - Future deleteCategory(int id)

class CategoriesCubit extends Cubit<CategoriesState> {
  final CategoriesUseCase categoriesUseCase;

  List<CategoryModel> _categories = [];

  CategoriesCubit({required this.categoriesUseCase})
      : super(CategoriesInitial());

  Future<void> fetchCategories() async {
    emit(CategoriesLoading());

    final result = await categoriesUseCase.getAll();

    result.fold(
      (failure) => emit(CategoriesError(message: failure.toString())),
      (categories) {
        _categories = categories;
        emit(CategoriesLoaded(categories: _categories));
      },
    );
  }

  Future<void> createCategory(String name, {String? imageBase64}) async {
    if (name.trim().isEmpty) return;

    emit(CategoryActionLoading(categories: _categories));

    final result = await categoriesUseCase.create(name.trim(), imageBase64: imageBase64);

    result.fold(
      (failure) => emit(
        CategoryActionError(
          categories: _categories,
          message: 'Failed to create category: ${failure.toString()}',
        ),
      ),
      (newCategory) {
        _categories = [..._categories, newCategory];
        emit(
          CategoryActionSuccess(
            categories: _categories,
            message: '"${newCategory.name}" added successfully.',
          ),
        );
      },
    );
  }

  Future<void> updateCategory(
      int id,
      String newName, {
        String? imageBase64,
        bool? showLocalImage,
      }) async {
    if (newName.trim().isEmpty) return;

    emit(CategoryActionLoading(categories: _categories));

    final result = await categoriesUseCase.update(
      id,
      newName.trim(),
      imageBase64: imageBase64,
      showLocalImage: showLocalImage,
    );

    result.fold(
          (failure) => emit(
        CategoryActionError(
          categories: _categories,
          message: 'Failed to update category: ${failure.toString()}',
        ),
      ),
          (updated) {
        _categories =
            _categories.map((c) => c.id == id ? updated : c).toList();
        emit(
          CategoryActionSuccess(
            categories: _categories,
            message: '"${updated.name}" updated successfully.',
          ),
        );
      },
    );
  }

  Future<void> deleteCategory(int id) async {
    final target = _categories.firstWhere(
      (c) => c.id == id,
      orElse: () => CategoryModel(id: id, name: ''),
    );

    emit(CategoryActionLoading(categories: _categories));

    final result = await categoriesUseCase.delete(id);

    result.fold(
      (failure) => emit(
        CategoryActionError(
          categories: _categories,
          message: 'Failed to delete category: ${failure.toString()}',
        ),
      ),
      (_) {
        _categories = _categories.where((c) => c.id != id).toList();
        emit(
          CategoryActionSuccess(
            categories: _categories,
            message: '"${target.name}" removed.',
          ),
        );
      },
    );
  }
}