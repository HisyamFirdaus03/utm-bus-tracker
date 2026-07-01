import 'package:firebase_auth/firebase_auth.dart';

import '../../core/api_client.dart';
import '../../models/models.dart';
import '../repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Future<AppUser?> login(String email, String password) async {
    // Don't catch FirebaseAuthException here — the UI's `friendlyAuthError`
    // helper pattern-matches on the exception's `.code` to show messages
    // like "Incorrect email or password" instead of a raw stack trace.
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    return getCurrentUser();
  }

  @override
  Future<AppUser?> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? matricNumber,
  }) async {
    final response = await ApiClient.instance.dio.post(
      '/api/auth/register/',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'role': role.name,
        'matric_number': matricNumber,
      },
    );
    // Backend created the Firebase Auth user server-side via
    // firebase-admin. Now sign the local client into that account so
    // subsequent API calls carry the ID token.
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    if (_auth.currentUser == null) return null;
    final response = await ApiClient.instance.dio.get('/api/auth/me/');
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }
}
