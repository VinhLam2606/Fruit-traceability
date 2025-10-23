abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final String username;
  final String walletAddress;
  final String accountType;

  AuthSuccess({
    required this.username,
    required this.walletAddress,
    required this.accountType,
  });
}

class AuthFailure extends AuthState {
  final String message;
  AuthFailure(this.message);
}

class AuthLoggedOut extends AuthState {}

class AuthEmailVerificationPending extends AuthState {
  final String email;
  AuthEmailVerificationPending({required this.email});
}

class AuthPasswordResetEmailSent extends AuthState {
  final String email;
  AuthPasswordResetEmailSent(this.email);
}
