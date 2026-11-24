import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/presentation/app_shell.dart';
import 'core/presentation/login_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/operations/presentation/operations_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) =>
                const OperationsScreen(module: 'Customers'),
          ),
          GoRoute(
            path: '/products',
            builder: (context, state) =>
                const OperationsScreen(module: 'Products'),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) =>
                const OperationsScreen(module: 'Orders'),
          ),
          GoRoute(
            path: '/deliveries',
            builder: (context, state) =>
                const OperationsScreen(module: 'Deliveries'),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) =>
                const OperationsScreen(module: 'Inventory'),
          ),
          GoRoute(
            path: '/payments',
            builder: (context, state) =>
                const OperationsScreen(module: 'Payments'),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) =>
                const OperationsScreen(module: 'Reports'),
          ),
          GoRoute(
            path: '/staff',
            builder: (context, state) =>
                const OperationsScreen(module: 'Staff'),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('That page could not be found.')),
    ),
  );
});

class GasAgencyApp extends ConsumerWidget {
  const GasAgencyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'BlueFlame Agency',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1769D2),
          surface: const Color(0xFFFFFFFF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7F9FC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE7ECF3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF1769D2), width: 1.5),
          ),
        ),
        dividerColor: const Color(0xFFE9EDF3),
      ),
      routerConfig: router,
    );
  }
}
