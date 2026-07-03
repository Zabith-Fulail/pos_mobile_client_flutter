import 'package:d_pos/features/data/models/common/base_response.dart';

class OrderItem extends Serializable{
  final String foodMenuId;
  final String menuName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String itemNote;

  OrderItem({
    required this.foodMenuId,
    required this.menuName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.itemNote,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final qty = int.tryParse(json['qty'] ?? '0') ?? 0;
    final price =
        double.tryParse(json['menu_unit_price'] ?? '0') ?? 0;

    return OrderItem(
      foodMenuId: json['food_menu_id'] ?? '',
      menuName: json['menu_name'] ?? '',
      quantity: qty,
      unitPrice: price,
      totalPrice: qty * price,
      itemNote: json['item_note'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    // TODO: implement toJson
    throw UnimplementedError();
  }
}
