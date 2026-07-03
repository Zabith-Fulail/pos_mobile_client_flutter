import 'package:dartz/dartz.dart';

import '../../../../error/failures.dart';
import '../../data/models/pos_models.dart';
import '../repositories/repository.dart';

/// Wraps all category CRUD operations.
/// Uses the existing single [Repository] — no new repository needed.
///
/// Register in dependency_injection.dart:
///   sl.registerLazySingleton(() => CategoriesUseCase(sl()));
class CategoriesUseCase {
  final Repository _repository;

  const CategoriesUseCase(this._repository);

  Future<Either<Failure, List<CategoryModel>>> getAll() {
    return _repository.getCategories();
  }

  Future<Either<Failure, CategoryModel>> create(String name, {String? imageBase64}) {
    return _repository.createCategory(name, imageBase64: imageBase64);
  }

  Future<Either<Failure, CategoryModel>> update(int id, String newName, {String? imageBase64, bool? showLocalImage}) {
    return _repository.updateCategory(id, newName, imageBase64: imageBase64, showLocalImage : showLocalImage);
  }

  Future<Either<Failure, bool>> delete(int id) {
    return _repository.deleteCategory(id);
  }
}