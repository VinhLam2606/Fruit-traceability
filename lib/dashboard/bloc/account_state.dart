part of 'account_bloc.dart';

sealed class AccountState {}

class AccountInitial extends AccountState {}

class AccountLoading extends AccountState {}

class AccountLoaded extends AccountState {
  final String userName;
  final String userAddress;
  final String role;
  AccountLoaded({
    required this.userName,
    required this.userAddress,
    required this.role,
  });
}

class AccountError extends AccountState {
  final String error;
  AccountError(this.error);
}
