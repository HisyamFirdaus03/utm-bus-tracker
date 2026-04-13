// ============================================================
// MOCK - Delete this file when integrating with Firebase Auth
// ============================================================

import '../../models/models.dart';
import '../repositories/auth_repository.dart';
import 'mock_data.dart';

class MockAuthRepository implements AuthRepository {
  AppUser? _currentUser;

  @override
  Future<AppUser?> login(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final user = MockData.users.firstWhere((u) => u.email == email);
      _currentUser = user;
      return user;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AppUser?> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? matricNumber,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final user = AppUser(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      role: role,
      matricNumber: matricNumber,
    );
    _currentUser = user;
    return user;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _currentUser = null;
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    return _currentUser;
  }
}
