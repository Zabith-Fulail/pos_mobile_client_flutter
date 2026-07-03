class PrintResponseModel {
  final String message;
  final String printUrl;
  final PrinterDetails? printerResponse;

  PrintResponseModel({
    required this.message,
    required this.printUrl,
    this.printerResponse,
  });

  factory PrintResponseModel.fromJson(Map<String, dynamic> json) {
    return PrintResponseModel(
      message: json['message'] ?? "Print request sent",
      printUrl: json['print_url'] ?? "",
      printerResponse: json['printer_response'] != null
          ? PrinterDetails.fromJson(json['printer_response'])
          : null,
    );
  }
}

class PrinterDetails {
  final String status;
  final String printer;
  final String ip;
  final int port;

  PrinterDetails({
    required this.status,
    required this.printer,
    required this.ip,
    required this.port,
  });

  factory PrinterDetails.fromJson(Map<String, dynamic> json) {
    return PrinterDetails(
      status: json['status'] ?? "",
      printer: json['printer'] ?? "",
      ip: json['ip'] ?? "",
      port: json['port'] ?? 9100,
    );
  }
}