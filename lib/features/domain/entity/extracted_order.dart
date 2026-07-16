class ExtractedOrderEntity {
  final List<ExtractedItemEntity> items;

  ExtractedOrderEntity({required this.items});
}

class ExtractedItemEntity {
  final String name;
  final int quantity;
  final List<ExtractedModifierEntity> modifiers;

  ExtractedItemEntity({
    required this.name,
    required this.quantity,
    required this.modifiers,
  });
}

class ExtractedModifierEntity {
  final String name;
  final bool negated;

  ExtractedModifierEntity({required this.name, required this.negated});
}