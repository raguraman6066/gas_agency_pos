import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/data/agency_repository.dart';
import 'core/data/dummy_agency_repository.dart';
import 'core/data/supabase_agency_repository.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  final supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');
  AgencyRepository repository;
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
    repository = SupabaseAgencyRepository(Supabase.instance.client);
  } else {
    repository = DummyAgencyRepository();
  }
  runApp(
    ProviderScope(
      overrides: [agencyRepositoryProvider.overrideWithValue(repository)],
      child: const GasAgencyApp(),
    ),
  );
}
