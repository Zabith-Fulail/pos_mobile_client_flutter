import '../../data/models/pos_models.dart';

class VoiceOrderResult {
  final List<CartItem> addedItems;
  final List<String> unmatchedItemNames;

  VoiceOrderResult({
    required this.addedItems,
    required this.unmatchedItemNames,
  });
}
