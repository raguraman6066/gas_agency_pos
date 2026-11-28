import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gas_agencies/app.dart';
import 'package:gas_agencies/core/data/dummy_agency_repository.dart';
import 'package:gas_agencies/core/domain/models.dart';
import 'package:gas_agencies/core/presentation/common_widgets.dart';
import 'package:gas_agencies/core/providers.dart';
import 'package:gas_agencies/features/bookings/presentation/booking_form_screen.dart';
import 'package:gas_agencies/features/bookings/presentation/booking_detail_screen.dart';
import 'package:gas_agencies/features/operations/presentation/operations_screen.dart';

void main() {
  testWidgets(
    'desktop deliveries show today, align statuses, and expose returns',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = DummyAgencyRepository();
      final seed = await repository.load();
      await repository.updateDelivery(
        Delivery(
          id: seed.deliveries.first.id,
          orderId: seed.orders.first.id,
          status: 'Assigned',
          staffId: seed.staff.firstWhere((member) => member.role == 'Staff').id,
        ),
      );
      final product = seed.products.first;
      final booking = AgencyOrder(
        id: '',
        number: '',
        customerId: seed.customers.first.id,
        productId: product.id,
        quantity: 3,
        unitPrice: product.price,
        status: 'Ready for Delivery',
        createdAt: DateTime.now(),
      );
      await repository.createOrder(booking);
      var data = await repository.load();
      final delivered = data.orders.first;
      final delivery = data.deliveries.firstWhere(
        (item) => item.orderId == delivered.id,
      );
      await repository.updateDelivery(
        Delivery(
          id: delivery.id,
          orderId: delivered.id,
          status: 'Assigned',
          staffId: seed.staff.firstWhere((member) => member.role == 'Staff').id,
        ),
      );
      await repository.updateDelivery(
        Delivery(
          id: delivery.id,
          orderId: delivered.id,
          status: 'Delivered',
          staffId: seed.staff.firstWhere((member) => member.role == 'Staff').id,
          deliveredQuantity: 3,
          returnedEmpty: 1,
          damagedEmpty: 1,
        ),
      );
      await repository.createOrder(booking);
      data = await repository.load();
      final unassigned = data.orders.first;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [agencyRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: Scaffold(body: DeliveriesScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text(unassigned.number), findsOneWidget);
      expect(find.textContaining(' · Unassigned'), findsWidgets);
      expect(find.text('Pending'), findsWidgets);
      final deliveredRow = find.ancestor(
        of: find.text(delivered.number),
        matching: find.byType(InkWell),
      );
      Finder inDeliveredRow(String label) =>
          find.descendant(of: deliveredRow, matching: find.text(label));
      expect(inDeliveredRow('Good received 1'), findsOneWidget);
      expect(inDeliveredRow('Damaged 1'), findsOneWidget);
      expect(inDeliveredRow('Remaining 1'), findsOneWidget);
      await tester.tap(inDeliveredRow('Record returns'));
      await tester.pumpAndSettle();
      expect(find.text('Record empty returns'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom dates'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      await tester.tap(find.text('Apply dates'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom range'));
      await tester.pumpAndSettle();
      expect(find.text('This week'), findsWidgets);
      expect(find.text('This month'), findsWidgets);
      await tester.tap(find.text('All dates').last);
      await tester.pumpAndSettle();

      final badges = find.byType(StatusBadge);
      final headerLeft = tester.getTopLeft(find.text('STATUS')).dx;
      final statuses = tester
          .widgetList<StatusBadge>(badges)
          .map((badge) => badge.status);
      expect(statuses, containsAll(['Assigned', 'Delivered']));
      for (final badge in badges.evaluate()) {
        expect(tester.getTopLeft(find.byWidget(badge.widget)).dx, headerLeft);
      }

      await tester.tap(find.text('All people'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unassigned').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<StatusBadge>(badges)
            .map((badge) => badge.status)
            .toSet(),
        {'Pending'},
      );
    },
  );

  testWidgets('dummy staff can sign in and open the dashboard', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agencyRepositoryProvider.overrideWithValue(DummyAgencyRepository()),
        ],
        child: const GasAgencyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Good day 👋'), findsOneWidget);
    expect(find.text('Total customers'), findsOneWidget);
    expect(find.text('Monthly sales'), findsOneWidget);
  });

  testWidgets('dashboard stays usable in a narrow mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = DummyAgencyRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [agencyRepositoryProvider.overrideWithValue(repository)],
        child: const GasAgencyApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Good day 👋'), findsOneWidget);
    final stock = (await repository.load()).inventory;
    final full = stock.fold<int>(0, (total, item) => total + item.filled);
    final empty = stock.fold<int>(0, (total, item) => total + item.empty);
    expect(stock.any((item) => item.booked > 0), isTrue);
    await tester.scrollUntilVisible(
      find.text('Full / Empty'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('$full / $empty'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking detail shows customer, balance, and delivery', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agencyRepositoryProvider.overrideWithValue(DummyAgencyRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: BookingDetailScreen(orderId: 'o1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GA-1001'), findsOneWidget);
    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.textContaining('Booking total'), findsOneWidget);
    expect(find.text('Payment history'), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking form shows inline customer creation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agencyRepositoryProvider.overrideWithValue(DummyAgencyRepository()),
        ],
        child: const MaterialApp(home: Scaffold(body: BookingFormScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New booking'), findsOneWidget);
    expect(find.textContaining('Booking total'), findsOneWidget);
    await tester.tap(find.text('Add customer here'));
    await tester.pumpAndSettle();
    expect(find.text('Save and select customer'), findsOneWidget);
    expect(find.text('Consumer number'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving a booking returns to the booking list', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = DummyAgencyRepository();
    final router = GoRouter(
      initialLocation: '/orders/new',
      routes: [
        GoRoute(
          path: '/orders/new',
          builder: (context, state) =>
              const Scaffold(body: BookingFormScreen()),
        ),
        GoRoute(
          path: '/orders',
          builder: (context, state) =>
              const Scaffold(body: Text('Bookings list')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [agencyRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save booking'));
    await tester.pumpAndSettle();

    expect(find.text('Bookings list'), findsOneWidget);
    expect((await repository.load()).orders, hasLength(3));
  });

  testWidgets('cancelling a booking uses an inline confirmation page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = DummyAgencyRepository();
    final router = GoRouter(
      initialLocation: '/orders/o1',
      routes: [
        GoRoute(
          path: '/orders/:orderId',
          builder: (context, state) => Scaffold(
            body: BookingDetailScreen(
              orderId: state.pathParameters['orderId']!,
            ),
          ),
        ),
        GoRoute(
          path: '/orders/:orderId/cancel',
          builder: (context, state) => Scaffold(
            body: BookingCancelScreen(
              orderId: state.pathParameters['orderId']!,
            ),
          ),
        ),
        GoRoute(
          path: '/orders',
          builder: (context, state) =>
              const Scaffold(body: Text('Bookings list')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [agencyRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm cancellation'), findsOneWidget);
    await tester.tap(find.text('Confirm cancellation'));
    await tester.pumpAndSettle();

    expect(find.text('Bookings list'), findsOneWidget);
    expect(
      (await repository.load()).orders
          .firstWhere((order) => order.id == 'o1')
          .status,
      'Cancelled',
    );
  });
}
