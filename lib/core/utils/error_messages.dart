String userFriendlyError(Object error) {
  final raw = error.toString().trim();
  final normalized = raw.toLowerCase();
  if (normalized.contains('invalid login credentials') ||
      normalized.contains('invalid email or password')) {
    return 'Email or password is incorrect.';
  }
  if (normalized.contains('email not confirmed')) {
    return 'Confirm your email address before signing in.';
  }
  if (normalized.contains('not linked to an active agency staff profile') ||
      normalized.contains('does not have an active agency staff profile')) {
    return 'Your password was accepted, but this account is not enabled for '
        'this agency yet. An administrator must run the demo setup SQL using '
        'the same email as your Supabase Auth account.';
  }
  if (normalized.contains('pgrst205') ||
      normalized.contains('schema cache') ||
      normalized.contains('could not find the table')) {
    return 'The agency database is not fully set up yet. Apply the Supabase '
        'migration, then refresh the page.';
  }
  if (normalized.contains('not authorized') ||
      normalized.contains('permission denied') ||
      normalized.contains('42501')) {
    return 'Your account does not have permission for this action. Ask an '
        'administrator to check your agency role.';
  }
  if (normalized.contains('23505') || normalized.contains('duplicate key')) {
    return 'That consumer number or email address is already in use.';
  }
  if (normalized.contains('not enough filled cylinders') ||
      normalized.contains('not enough stock')) {
    return 'There are not enough available filled cylinders for this order.';
  }
  if (normalized.contains('payment exceeds') ||
      normalized.contains('cannot exceed the remaining')) {
    return 'The payment amount is greater than the order’s remaining balance.';
  }
  if (normalized.contains('already completed')) {
    return 'This delivery has already been completed.';
  }
  if (normalized.contains('socketexception') ||
      normalized.contains('clientexception') ||
      normalized.contains('failed host lookup') ||
      normalized.contains('connection refused')) {
    return 'Could not connect to the agency service. Check your internet '
        'connection and try again.';
  }

  final detail = raw
      .replaceFirst(RegExp(r'^(Exception|Bad state|Error):\s*'), '')
      .replaceFirst(RegExp(r'^PostgrestException\(message:\s*'), '')
      .replaceFirst(RegExp(r',\s*code:.*$', dotAll: true), '')
      .trim();
  if (detail.isEmpty || detail == raw && normalized.contains('exception')) {
    return 'Could not complete the request. Please try again, or ask an '
        'administrator for help.';
  }
  return detail;
}
