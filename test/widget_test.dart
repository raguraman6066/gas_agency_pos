import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_agencies/app.dart';
import 'package:gas_agencies/core/data/dummy_agency_repository.dart';
import 'package:gas_agencies/core/providers.dart';

void main() {
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agencyRepositoryProvider.overrideWithValue(DummyAgencyRepository()),
        ],
        child: const GasAgencyApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Good day 👋'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
