import 'package:equatable/equatable.dart';

// ── Sentinel wrapper so copyWith can explicitly set nullable fields to null ──
class _Absent {
  const _Absent();
}

const _absent = _Absent();

class CategoryModel extends Equatable {
  final int id;
  final bool showLocalImage;
  final String name;
  final String? imageUrl;
  final String? localPath;

  const CategoryModel({
    required this.id,
    required this.name,
    this.showLocalImage = true,
    this.imageUrl,
    this.localPath,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      name: json['category_name'] ?? json['name'],
      imageUrl: json['category_image'] as String?,
      localPath: json['localPath'] as String?,
      showLocalImage: json['showLocalImage'] as bool? ?? true,
    );
  }

  /// Pass [localPath] = null explicitly to clear it.
  /// Omit [localPath] entirely (or pass the sentinel) to keep the existing value.
  CategoryModel copyWith({
    int? id,
    String? name,
    String? imageUrl,
    bool? showLocalImage,
    Object? localPath = _absent, // ← sentinel pattern
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      // If caller passed a value (including null) use it; otherwise keep existing
      localPath: localPath is _Absent ? this.localPath : localPath as String?,
      showLocalImage: showLocalImage ?? this.showLocalImage,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'localPath': localPath,
    'imageUrl': imageUrl,
    'showLocalImage': showLocalImage,
  };

  @override
  List<Object?> get props => [id, name, imageUrl, localPath, showLocalImage];

  // ── Filter out unwanted categories (e.g., empty or staff categories) ──
  static List<CategoryModel> filterValidCategories(List<CategoryModel> categories) {
    const List<String> excludedCategories = [
      'staff food?',
      'staff food',
    ];
    
    return categories
        .where((category) => !excludedCategories.contains(category.name.toLowerCase()))
        .toList();
  }
}

class ProductModel extends Equatable {
  final int id;
  final String name;
  final String? alternativeName;
  final double price;
  final bool showLocalImage;
  final int categoryId;
  final String? imageUrl;
  final String? localPath;

  const ProductModel({
    required this.id,
    this.showLocalImage = true,
    required this.name,
    required this.alternativeName,
    required this.price,
    required this.categoryId,
    this.imageUrl,
    this.localPath,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final String? rawPhoto = json['photo'] as String?;
    final String? fullImageUrl = (rawPhoto != null && rawPhoto.isNotEmpty)
        ? rawPhoto.replaceAll('temp', 'temp')
        : null;
    return ProductModel(
      id: json['id'] as int,
      alternativeName: json['alternative_name'],
      name: (json['name'] ?? 'Unknown') as String,
      price: (json['sale_price'] ?? json['price'] ?? 0.0).toDouble(),
      categoryId: json['category_id'] ?? 0,
      imageUrl: fullImageUrl,
      localPath: json['localPath'] as String?,
      showLocalImage: json['showLocalImage'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'alternative_name': alternativeName,
    'price': price,
    'category_id': categoryId,
    'photo': imageUrl,
    'localPath': localPath,
    'showLocalImage': showLocalImage,
  };

  /// Pass [localPath] = null explicitly to clear it.
  /// Omit [localPath] entirely (or pass the sentinel) to keep the existing value.
  ProductModel copyWith({
    String? name,
    bool? showLocalImage,
    double? price,
    int? categoryId,
    Object? localPath = _absent, // ← sentinel pattern
  }) {
    return ProductModel(
      id: id,
      alternativeName: alternativeName,
      name: name ?? this.name,
      price: price ?? this.price,
      showLocalImage: showLocalImage ?? this.showLocalImage,
      categoryId: categoryId ?? this.categoryId,
      imageUrl: imageUrl,
      localPath: localPath is _Absent ? this.localPath : localPath as String?,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, alternativeName, price, categoryId, imageUrl, localPath, showLocalImage];
}

class ModifierModel extends Equatable {
  final int id;
  final String name;
  final double price;

  const ModifierModel({
    required this.id,
    required this.name,
    required this.price,
  });

  factory ModifierModel.fromJson(Map<String, dynamic> json) {
    return ModifierModel(
      id: json['id'],
      name: json['name'] ?? "Modifier",
      price: double.tryParse(json['price'].toString()) ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [id, name, price];
}

class CartItem extends Equatable {
  final String uuid;
  final ProductModel product;
  final int quantity;
  final List<ModifierModel> modifiers;
  final String note;

  const CartItem({
    required this.uuid,
    required this.product,
    required this.quantity,
    this.modifiers = const [],
    this.note = '',
  });

  double get total {
    double modifiersTotal = modifiers.fold(0, (sum, mod) => sum + mod.price);
    return (product.price + modifiersTotal) * quantity;
  }

  CartItem copyWith({
    String? uuid,
    ProductModel? product,
    int? quantity,
    List<ModifierModel>? modifiers,
    String? note,
  }) {
    return CartItem(
      uuid: uuid ?? this.uuid,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      modifiers: modifiers ?? this.modifiers,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => [uuid, product, quantity, modifiers, note];
}