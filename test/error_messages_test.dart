import 'package:flutter_test/flutter_test.dart';
import 'package:gas_agencies/core/utils/error_messages.dart';

void main() {
  test('login errors are presented in plain language', () {
    expect(
      userFriendlyError(Exception('Invalid login credentials')),
      'Email or password is incorrect.',
    );
    expect(
      userFriendlyError(
        StateError(
          'Your password was accepted, but this account is not linked to an '
          'active agency staff profile.',
        ),
      ),
      contains('not enabled for this agency'),
    );
  });

  test('database setup and stock errors explain the next action', () {
    expect(
      userFriendlyError(Exception('PGRST205: table missing from schema cache')),
      contains('Apply the Supabase migration'),
    );
    expect(
      userFriendlyError(StateError('Not enough filled cylinders available')),
      contains('not enough available filled cylinders'),
    );
  });
}
