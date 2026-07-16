import 'package:dartz/dartz.dart';
import '../../../../error/failures.dart';
import '../entity/extracted_order.dart';
import '../repositories/repository.dart';

class ExtractOrderFromSpeechUseCase {
  final Repository repository;

  ExtractOrderFromSpeechUseCase(this.repository);

  Future<Either<Failure, ExtractedOrderEntity>> call(String transcript) async {
    return await repository.extractOrderFromSpeech(transcript);
  }
}