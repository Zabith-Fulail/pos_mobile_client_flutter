import '../../../domain/entity/extracted_order.dart';

class ExtractedOrderModel extends ExtractedOrderEntity {
  ExtractedOrderModel({required super.items});

  factory ExtractedOrderModel.fromJson(Map<String, dynamic> json) {
    return ExtractedOrderModel(
      items: (json['items'] as List?)
          ?.map((i) => ExtractedItemModel.fromJson(i as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }
}

class ExtractedItemModel extends ExtractedItemEntity {
  ExtractedItemModel({
    required super.name,
    required super.quantity,
    required super.modifiers,
  });

  factory ExtractedItemModel.fromJson(Map<String, dynamic> json) {
    return ExtractedItemModel(
      name: json['name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      modifiers: (json['modifiers'] as List?)
          ?.map((m) => ExtractedModifierModel.fromJson(m as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }
}

class ExtractedModifierModel extends ExtractedModifierEntity {
  ExtractedModifierModel({required super.name, required super.negated});

  factory ExtractedModifierModel.fromJson(Map<String, dynamic> json) {
    return ExtractedModifierModel(
      name: json['name'] as String? ?? '',
      negated: json['negated'] as bool? ?? false,
    );
  }
}