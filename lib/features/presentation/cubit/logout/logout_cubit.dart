import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/use_cases/logout_use_case.dart';
import 'logout_state.dart';

class LogoutCubit extends Cubit<LogoutState> {
  final LogoutUseCase logoutUseCase;

  LogoutCubit({required this.logoutUseCase}) : super(LogoutInitial());

  Future<void> logout() async {
    emit(LogoutLoading());

    final result = await logoutUseCase();

    result.fold(
      (failure) => emit(LogoutError("Logout Failed")),
      (success) => emit(LogoutSuccess()),
    );
  }
}
