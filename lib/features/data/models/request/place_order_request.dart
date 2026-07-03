class PlaceOrderRequest {
  final String saleNo;
  final String randomCode;
  final String customerId;
  final String customerName;
  final String status;
  final int totalItemsInCart;
  final int totalItemsInCartQty;
  final double subTotal;
  final double totalPayable;
  final String saleDate;
  final String dateTime;
  final String orderTime;
  final int orderType;
  final List<OrderItemRequest> items;

  PlaceOrderRequest({
    required this.saleNo,
    required this.randomCode,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.totalItemsInCart,
    required this.totalItemsInCartQty,
    required this.subTotal,
    required this.totalPayable,
    required this.saleDate,
    required this.dateTime,
    required this.orderTime,
    required this.orderType,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      "sale_no": saleNo,
      "random_code": randomCode,
      "customer_id": customerId,
      "customer_name": customerName,
      "status": status,
      "total_items_in_cart": totalItemsInCart,
      "total_items_in_cart_qty": totalItemsInCartQty,
      "sub_total": subTotal,
      "total_payable": totalPayable,
      "sale_date": saleDate,
      "date_time": dateTime,
      "order_time": orderTime,
      "order_type": orderType,
      "items": items.map((x) => x.toJson()).toList(),
    };
  }
}

class OrderItemRequest {
  final int foodMenuId;
  final String menuName;
  final double menuUnitPrice;
  final int qty;
  final String modifiersId;
  final String modifiersName;
  final String modifiersPrice;
  final ModifiersJsonData? modifiersJson;

  OrderItemRequest({
    required this.foodMenuId,
    required this.menuName,
    required this.menuUnitPrice,
    required this.qty,
    this.modifiersId = "",
    this.modifiersName = "",
    this.modifiersPrice = "",
    this.modifiersJson,
  });

  Map<String, dynamic> toJson() {
    dynamic modifiersPayload;

    if (modifiersJson == null) {
      modifiersPayload = [];
    } else if (modifiersJson!.modifiers.isEmpty &&
        modifiersJson!.itemNote.isEmpty) {
      modifiersPayload = [];
    } else {
      modifiersPayload = modifiersJson!.toJson();
    }
    return {
      "food_menu_id": foodMenuId,
      "menu_name": menuName,
      "menu_unit_price": menuUnitPrice,
      "qty": qty,
      "modifiers_id": modifiersId,
      "modifiers_name": modifiersName,
      "modifiers_price": modifiersPrice,
      "modifiers_json": modifiersPayload,
    };
  }
}

class ModifiersJsonData {
  final String itemNote;
  final List<ModifierItem> modifiers;

  ModifiersJsonData({required this.itemNote, required this.modifiers});

  Map<String, dynamic> toJson() {
    return {
      "item_note": itemNote,
      "modifiers": modifiers.map((x) => x.toJson()).toList(),
    };
  }
}

class ModifierItem {
  final int modifierId;
  final String modifierName;
  final double modifierPrice;
  final int totalQty;
  final double totalPrice;
  final List<ModifierUnit> units;

  ModifierItem({
    required this.modifierId,
    required this.modifierName,
    required this.modifierPrice,
    required this.totalQty,
    required this.totalPrice,
    required this.units,
  });

  Map<String, dynamic> toJson() {
    return {
      "modifier_id": modifierId,
      "modifier_name": modifierName,
      "modifier_price": modifierPrice,
      "total_qty": totalQty,
      "total_price": totalPrice,
      "units": units.map((x) => x.toJson()).toList(),
    };
  }
}

class ModifierUnit {
  final int unit;
  final int qty;
  final double linePrice;

  ModifierUnit({
    required this.unit,
    required this.qty,
    required this.linePrice,
  });

  Map<String, dynamic> toJson() {
    return {"unit": unit, "qty": qty, "line_price": linePrice};
  }
}
