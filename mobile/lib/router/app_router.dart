import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../screens/login/login_screen.dart';
import '../screens/register/register_screen.dart';
import '../screens/student/student_home_screen.dart';
import '../screens/student/plan_route_screen.dart';
import '../screens/student/route_preview_screen.dart';
import '../screens/student/submit_feedback_screen.dart';
import '../screens/student/feedback_history_screen.dart';
import '../screens/student/watchlist_screen.dart';
import '../screens/student/bus_schedule_screen.dart';
import '../screens/driver/driver_home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final user = authState.valueOrNull;
      final loc = state.matchedLocation;
      final isOnAuthPage = loc == '/login' || loc == '/register';

      // Not logged in → force auth pages only
      if (user == null) {
        return isOnAuthPage ? null : '/login';
      }

      // Logged in but on auth page → redirect to role-based home
      if (isOnAuthPage) {
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
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/student',
        builder: (context, state) => const StudentHomeScreen(),
      ),
      GoRoute(
        path: '/plan-route',
        builder: (context, state) => const PlanRouteScreen(),
      ),
      GoRoute(
        path: '/route-preview/:routeId',
        builder: (context, state) => RoutePreviewScreen(
          routeId: state.pathParameters['routeId']!,
          startStopId: state.uri.queryParameters['start'],
          endStopId: state.uri.queryParameters['end'],
        ),
      ),
      GoRoute(
        path: '/feedback',
        builder: (context, state) => const FeedbackHistoryScreen(),
      ),
      GoRoute(
        path: '/submit-feedback',
        builder: (context, state) => const SubmitFeedbackScreen(),
      ),
      GoRoute(
        path: '/watchlist',
        builder: (context, state) => const WatchlistScreen(),
      ),
      GoRoute(
        path: '/schedule',
        builder: (context, state) => const BusScheduleScreen(),
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
