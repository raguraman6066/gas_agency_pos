import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/presentation/app_shell.dart';
import 'core/presentation/login_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/bookings/presentation/booking_form_screen.dart';
import 'features/bookings/presentation/booking_detail_screen.dart';
import 'features/operations/presentation/operations_screen.dart';
import 'features/payments/presentation/payment_entry_screen.dart';
import 'features/settings/presentation/settings_screen.dart';

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
            builder: (context, state) => const CustomersScreen(),
          ),
          GoRoute(path: '/products', redirect: (_, _) => '/settings/products'),
          GoRoute(
            path: '/settings/products',
            builder: (context, state) => const ProductsScreen(),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const BookingsScreen(),
          ),
          GoRoute(
            path: '/orders/new',
            builder: (context, state) => const BookingFormScreen(),
          ),
          GoRoute(
            path: '/orders/:orderId/edit',
            builder: (context, state) =>
                BookingFormScreen(orderId: state.pathParameters['orderId']!),
          ),
          GoRoute(
            path: '/orders/:orderId/cancel',
            builder: (context, state) =>
                BookingCancelScreen(orderId: state.pathParameters['orderId']!),
          ),
          GoRoute(
            path: '/orders/:orderId/payment',
            builder: (context, state) =>
                PaymentEntryScreen(orderId: state.pathParameters['orderId']!),
          ),
          GoRoute(
            path: '/orders/:orderId',
            builder: (context, state) =>
                BookingDetailScreen(orderId: state.pathParameters['orderId']!),
          ),
          GoRoute(
            path: '/deliveries',
            builder: (context, state) => const DeliveriesScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/payments',
            builder: (context, state) => const PaymentsScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(path: '/staff', redirect: (_, _) => '/settings/staff'),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/settings/staff',
            builder: (context, state) => const StaffScreen(),
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
      title: 'Kathiravan Gas Agency',
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFB42318)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFB42318), width: 1.5),
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
