import '../../models/common/base_response.dart';

class RunningOrderData extends Serializable{
  final List<RunningOrderModel> runningOrders;

  RunningOrderData({required this.runningOrders});

  factory RunningOrderData.fromJson(Map<String, dynamic> json) {
    return RunningOrderData(
      runningOrders: (json['running_orders'] as List?)
          ?.map((e) => RunningOrderModel.fromJson(e))
          .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    throw UnimplementedError();
  }
}

class RunningOrderModel {
  final int id;
  final String saleNo;
  final String customerName;
  final String status;
  final double totalPayable;
  final String orderTime;
  final String tableText;
  final List<RunningOrderDetailModel> details;

  RunningOrderModel({
    required this.id,
    required this.saleNo,
    required this.customerName,
    required this.status,
    required this.totalPayable,
    required this.orderTime,
    required this.tableText,
    required this.details,
  });

  factory RunningOrderModel.fromJson(Map<String, dynamic> json) {
    return RunningOrderModel(
      id: json['id'] ?? 0,
      saleNo: json['sale_no'] ?? '',
      customerName: json['customer_id'] ?? 'Unknown', // JSON shows customer_id holds the name "nnew oder"
      status: json['status'] ?? 'Unknown',
      totalPayable: double.tryParse(json['total_payable']?.toString() ?? '0') ?? 0.0,
      orderTime: json['order_time'] ?? '',
      tableText: json['orders_table_text'] ?? '',
      details: (json['details'] as List?)
          ?.map((e) => RunningOrderDetailModel.fromJson(e))
          .toList() ??
          [],
    );
  }
}

class RunningOrderDetailModel {
  final int id;
  final String menuName;
  final int qty;
  final double price;

  RunningOrderDetailModel({
    required this.id,
    required this.menuName,
    required this.qty,
    required this.price,
  });

  factory RunningOrderDetailModel.fromJson(Map<String, dynamic> json) {
    return RunningOrderDetailModel(
      id: json['id'] ?? 0,
      menuName: json['menu_name'] ?? '',
      qty: int.tryParse(json['qty']?.toString() ?? '0') ?? 0,
      price: double.tryParse(json['menu_price_with_discount']?.toString() ?? '0') ?? 0.0,
    );
  }
}