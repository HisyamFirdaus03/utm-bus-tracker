import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../screens/login/login_screen.dart';
import '../screens/student/student_home_screen.dart';
import '../screens/driver/driver_home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final user = authState.valueOrNull;
      final isOnLogin = state.matchedLocation == '/login';

      // Not logged in → force login
      if (user == null) {
        return isOnLogin ? null : '/login';
      }

      // Logged in but on login page → redirect to role-based home
      if (isOnLogin) {
        switch (user.role) {
          case UserRole.student:
            return '/student';
          case UserRole.driver:
            return '/driver';
          case UserRole.admin:
            return '/student'; // admin uses student view for now
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/student',
        builder: (context, state) => const StudentHomeScreen(),
      ),
      GoRoute(
        path: '/driver',
        builder: (context, state) => const DriverHomeScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
