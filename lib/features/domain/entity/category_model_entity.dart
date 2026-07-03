
import 'package:equatable/equatable.dart';

class CategoryModel extends Equatable {
  final int id;
  final String name;
  final String? imageUrl;
  final String? localPath;

  const CategoryModel({
    required this.id,
    required this.name,
    this.imageUrl,
    this.localPath,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: (json['id'] ?? 0) as int,
      name: (json['category_name'] ?? json['name'] ?? 'Unknown') as String,
      imageUrl: json['category_image'] as String?,
      localPath: json['localPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imageUrl': imageUrl,
    'localPath': localPath,
  };

  CategoryModel copyWith({
    int? id,
    String? name,
    String? imageUrl,
    String? localPath,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      localPath: localPath ?? this.localPath,
    );
  }

  @override
  List<Object?> get props => [id, name, imageUrl, localPath];

  @override
  String toString() =>
      'CategoryModel(id: $id, name: $name, imageUrl: $imageUrl, localPath: $localPath)';
}
