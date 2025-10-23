abstract class AuthEvent {}

class AuthStarted extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  AuthLoginRequested(this.email, this.password);
}

class AuthRegisterRequested extends AuthEvent {
  final String username;
  final String email;
  final String password;
  final String accountType;
  AuthRegisterRequested({
    required this.username,
    required this.email,
    required this.password,
    required this.accountType,
  });
}

class AuthEmailVerificationChecked extends AuthEvent {
  final String email;
  AuthEmailVerificationChecked(this.email);
}

class AuthLogoutRequested extends AuthEvent {}
