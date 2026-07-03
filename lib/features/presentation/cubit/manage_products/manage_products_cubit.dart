import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/pos_models.dart';
import '../../../domain/repositories/repository.dart';
import 'manage_products_state.dart';

class ProductsCubit extends Cubit<ProductsState> {
  final Repository repository;

  ProductsCubit({required this.repository}) : super(ProductsInitial());

  Future<void> fetchProducts() async {
    emit(ProductsLoading());
    final result = await repository.getProducts();
    result.fold(
          (failure) => emit(const ProductsError("Failed to load products")),
          (products) => emit(ProductsLoaded(products)),
    );
  }

  Future<void> createProduct(String name,String alternativeName, double price, int categoryId, {String? imageBase64}) async {
    final currentProducts = state is ProductsLoaded ? (state as ProductsLoaded).products : <ProductModel>[];
    emit(ProductActionLoading(currentProducts));

    final result = await repository.createProduct(name, alternativeName, price, categoryId, imageBase64: imageBase64);
    result.fold(
          (failure) => emit(ProductActionError(currentProducts, "Failed to create product")),
          (newProduct) {
        final updatedList = List<ProductModel>.from(currentProducts)..add(newProduct);
        emit(ProductActionSuccess(updatedList, "Product created successfully"));
      },
    );
  }

  Future<void> updateProduct(int id, String name, double price, int categoryId, {String? imageBase64, bool? showLocalImage, bool clearImage = false}) async {
    final currentProducts = _getCurrentProducts();
    emit(ProductActionLoading(currentProducts));

    final result = await repository.updateProduct(id, name, price, categoryId, imageBase64: imageBase64, showLocalImage : showLocalImage, clearImage : clearImage,   );
    result.fold(
          (failure) => emit(ProductActionError(currentProducts, "Failed to update product")),
          (updatedProduct) {
        final updatedList = currentProducts.map((p) => p.id == id ? updatedProduct : p).toList();
        emit(ProductActionSuccess(updatedList, "Product updated successfully"));
      },
    );
  }

  Future<void> deleteProduct(int id) async {
    final currentProducts = _getCurrentProducts();
    emit(ProductActionLoading(currentProducts));

    final result = await repository.deleteProduct(id);
    result.fold(
          (failure) => emit(ProductActionError(currentProducts, "Failed to delete product")),
          (_) {
        final updatedList = currentProducts.where((p) => p.id != id).toList();
        emit(ProductActionSuccess(updatedList, "Product deleted successfully"));
      },
    );
  }

  List<ProductModel> _getCurrentProducts() {
    if (state is ProductsLoaded) return (state as ProductsLoaded).products;
    if (state is ProductActionLoading) return (state as ProductActionLoading).products;
    if (state is ProductActionSuccess) return (state as ProductActionSuccess).products;
    if (state is ProductActionError) return (state as ProductActionError).products;
    return [];
  }
}