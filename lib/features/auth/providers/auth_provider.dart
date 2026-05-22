import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/mock_auth_service.dart';

final mockAuthServiceProvider = Provider<MockAuthService>((ref) {
  return MockAuthService();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AppUser?>((ref) {
  return AuthController(ref.watch(mockAuthServiceProvider));
});

class AuthController extends StateNotifier<AppUser?> {
  AuthController(this._authService) : super(null);

  final MockAuthService _authService;

  void login(String email) {
    state = _authService.login(email);
  }

  void loginWithGoogleMock() {
    state = _authService.login('aluno@uni.com');
  }

  void logout() {
    state = null;
  }
}
