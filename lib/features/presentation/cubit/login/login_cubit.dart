import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../error/error_messages.dart';
import '../../../../error/failures.dart';
import '../../../../utils/app_constants.dart';
import '../../../../utils/app_strings.dart';
import '../../../data/data_sources/local_data_sources.dart';
import '../../../data/models/request/login_request_model.dart';
import '../../../domain/use_cases/login_use_case.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  final LoginUseCase loginUseCase;
  final LocalDataSource localDataSource;
  LoginCubit({
    required this.loginUseCase,
    required this.localDataSource,
  }) : super(LoginInitial());
  static const branchName = 'pref_01';

  Future<void> login(String emailAddress, String password) async {
    emit(LoginLoading());
    if (AppConstants.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      await saveBranch('Demo Branch');
      emit(LoginSuccess(token: 'mock-token'));
      return;
    }
    final request = LoginRequest(emailAddress: emailAddress, password: password);

    final loginResult = await loginUseCase(request);

    loginResult.fold(
          (failure) {
        if (failure is ConnectionFailure) {
          emit(LoginFailure(
              message: ErrorMessages().mapFailureToMessage(failure) ?? ""));
        } else if (failure is AuthorizedFailure) {
          emit(LoginFailure(
              message: AppStrings.unAuthorizedDes));
        } else if (failure is ServerFailure) {
          emit(LoginFailure(
              message: failure.errorResponse.errorDescription ??
                  AppStrings.somethingWentWrong));
        } else {
          emit(LoginFailure(
              message: AppStrings.somethingWentWrong));
        }
      },
          (response) async {
            saveBranch(response.user.outlet?.outletName ?? "");
        emit(LoginSuccess(token: response.accessToken));
      },
    );
  }

  Future<void> saveBranch(String branch) => localDataSource.saveBranch(branch);

  Future<String> getBranch() => localDataSource.getBranch();

}