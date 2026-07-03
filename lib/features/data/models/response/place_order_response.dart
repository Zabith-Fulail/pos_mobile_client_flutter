class KitchenOrderResponse {
  final String message;
  final int kitchenSaleId;
  final String saleNo;
  final String randomCode;
  final KotPrintResponse? kotPrint;

  const KitchenOrderResponse({
    required this.message,
    required this.kitchenSaleId,
    required this.saleNo,
    required this.randomCode,
    this.kotPrint,
  });

  factory KitchenOrderResponse.fromJson(Map<String, dynamic> json) {
    return KitchenOrderResponse(
      message: json["message"] ?? "",
      kitchenSaleId: json["kitchen_sale_id"] ?? 0,
      saleNo: json["sale_no"] ?? "",
      randomCode: json["random_code"] ?? "",
      kotPrint: json["kot_print"] != null
          ? KotPrintResponse.fromJson(json["kot_print"])
          : null,
    );
  }
}

class KotPrintResponse {
  final bool ok;
  final int status;
  final KotBodyResponse? body;

  KotPrintResponse({required this.ok, required this.status, this.body});

  factory KotPrintResponse.fromJson(Map<String, dynamic> json) {
    return KotPrintResponse(
      ok: json["ok"] ?? false,
      status: json["status"] ?? 0,
      body: json["body"] != null ? KotBodyResponse.fromJson(json["body"]) : null,
    );
  }
}

class KotBodyResponse {
  final String status;
  final String printer;

  KotBodyResponse({required this.status, required this.printer});

  factory KotBodyResponse.fromJson(Map<String, dynamic> json) {
    return KotBodyResponse(
      status: json["status"] ?? "",
      printer: json["printer"] ?? "",
    );
  }
}