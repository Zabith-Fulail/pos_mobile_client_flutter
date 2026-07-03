import 'package:equatable/equatable.dart';

class ErrorResponse extends Equatable {
  const ErrorResponse({
    this.responseCode,
    this.responseDescription,
  });

  final String? responseCode;
  final String? responseDescription;

  @override
  List<Object> get props => [responseDescription!, responseCode!];
}