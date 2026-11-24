import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../utils/error_messages.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  late final TextEditingController _password;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final supabaseConfigured = const String.fromEnvironment('SUPABASE_URL')
        .isNotEmpty;
    _email = TextEditingController(
      text: supabaseConfigured ? '' : 'admin@gasagency.demo',
    );
    _password = TextEditingController(
      text: supabaseConfigured ? '' : 'demo123',
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(agencyControllerProvider.notifier)
          .signIn(_email.text.trim(), _password.text);
      if (mounted) context.go('/dashboard');
    } catch (error) {
      if (mounted) {
        setState(() => _error = userFriendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(agencyControllerProvider, (previous, next) {
      if (next.signedIn) context.go('/dashboard');
    });
    final supabaseConfigured = const String.fromEnvironment('SUPABASE_URL')
        .isNotEmpty;
    final wide = MediaQuery.sizeOf(context).width > 760;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          if (wide)
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  color: const Color(0xFF102947),
                  padding: const EdgeInsets.all(56),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2679E8),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.local_fire_department_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'BlueFlame',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 54),
                      const Text(
                        'A better way to\nrun your agency.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          height: 1.17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Orders, deliveries, inventory and payments —\nall in one simple workspace.',
                        style: TextStyle(
                          color: Color(0xFFB9C9DB),
                          fontSize: 15,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const _FeatureLine(
                        icon: Icons.check_circle_outline,
                        text: 'Know exactly what needs attention today',
                      ),
                      const SizedBox(height: 14),
                      const _FeatureLine(
                        icon: Icons.check_circle_outline,
                        text: 'Keep customer and payment records together',
                      ),
                      const SizedBox(height: 46),
                      const Text(
                        'BUILT FOR YOUR EVERYDAY BUSINESS',
                        style: TextStyle(
                          color: Color(0xFF8DA3BC),
                          letterSpacing: 1.4,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!wide) ...[
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFF1769D2),
                            size: 34,
                          ),
                          const SizedBox(height: 20),
                        ],
                        const Text(
                          'Welcome back',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF18283A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sign in to manage your gas agency.',
                          style: TextStyle(
                            color: Color(0xFF778397),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Email address',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'you@agency.com',
                            prefixIcon: Icon(Icons.mail_outline, size: 19),
                          ),
                          validator: (value) =>
                              value == null || !value.contains('@')
                              ? 'Enter a valid email address.'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              size: 19,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 19,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.length < 4
                              ? 'Password must be at least 4 characters.'
                              : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFB42318),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    width: 19,
                                    height: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Sign in'),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: Text(
                            supabaseConfigured
                                ? 'Secure sign in powered by Supabase'
                                : 'Demo: admin@gasagency.demo  ·  demo123',
                            style: const TextStyle(
                              color: Color(0xFF8995A6),
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: const Color(0xFF72B0FF)),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(color: Color(0xFFD6E0EB), fontSize: 12),
        ),
      ),
    ],
  );
}
