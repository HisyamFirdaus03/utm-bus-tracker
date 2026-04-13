import '../../models/models.dart';

abstract class AuthRepository {
  Future<AppUser?> login(String email, String password);
  Future<AppUser?> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? matricNumber,
  });
  Future<void> logout();
  Future<AppUser?> getCurrentUser();
}
