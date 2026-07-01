import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'api_client.dart';

/// Turn whatever error came out of the auth stack into a message the user
/// can actually read. Prefers Firebase Auth codes → readable strings, then
/// unwraps DioException to pull out backend error details.
String friendlyAuthError(Object error) {
  if (error is FirebaseAuthException) {
    return _firebaseAuthMessage(error);
  }
  if (error is DioException) {
    return _dioMessage(error);
  }
  if (error is ApiException) {
    return error.message;
  }
  return error.toString();
}

String _firebaseAuthMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return 'Incorrect email or password.';
    case 'user-not-found':
      return 'No account exists for that email.';
    case 'wrong-password':
      return 'Incorrect password.';
    case 'invalid-email':
      return 'That email address looks malformed.';
    case 'user-disabled':
      return 'This account has been disabled. Contact admin.';
    case 'too-many-requests':
      return 'Too many attempts. Wait a minute and try again.';
    case 'network-request-failed':
      return 'No internet connection.';
    case 'email-already-in-use':
      return 'An account with that email already exists. Try logging in.';
    case 'weak-password':
      return 'Password is too weak. Use at least 6 characters.';
    case 'operation-not-allowed':
      return 'Email/password sign-in is disabled for this project.';
    default:
      return e.message ?? 'Authentication failed (${e.code}).';
  }
}

String _dioMessage(DioException e) {
  // If our onError interceptor wrapped the response in an ApiException,
  // pull the underlying message — that's the backend's `detail` field.
  final inner = e.error;
  if (inner is ApiException) {
    return inner.message;
  }

  // Otherwise try to pull a useful field from the response body.
  final data = e.response?.data;
  if (data is Map) {
    final detail = data['detail'] ?? data['error'] ?? data['message'];
    if (detail != null) return detail.toString();
    // Field-level validation errors from DRF: {"email": ["already exists"]}
    for (final entry in data.entries) {
      final v = entry.value;
      if (v is List && v.isNotEmpty) return '${entry.key}: ${v.first}';
      if (v is String && v.isNotEmpty) return '${entry.key}: $v';
    }
  }

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Server is slow to respond. Try again.';
    case DioExceptionType.connectionError:
      return 'Could not reach the server. Check your internet.';
    case DioExceptionType.badResponse:
      return 'Server error (${e.response?.statusCode}).';
    default:
      return e.message ?? 'Request failed.';
  }
}
