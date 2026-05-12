import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:disasteraid_app/features/auth/presentation/auth_provider.dart';
import 'package:disasteraid_app/core/theme/app_theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cnicController = TextEditingController();
  bool _obscurePassword = true;
  bool _usePhone = false;
  String _selectedRole = 'DONOR';

  // No ADMIN role — per security requirements
  static const _roles = [
    ('DONOR', 'Donor', Icons.favorite, 'Support relief campaigns'),
    ('BENEFICIARY', 'Beneficiary', Icons.person, 'Request aid assistance'),
    ('VOLUNTEER', 'Volunteer', Icons.handshake, 'Deliver aid on ground'),
    ('NGO', 'NGO', Icons.business, 'Manage campaigns & tasks'),
    (
      'COORDINATOR',
      'Coordinator',
      Icons.manage_accounts,
      'Coordinate operations'
    ),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _cnicController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authProvider.notifier).register(
          email: _usePhone ? null : _emailController.text.trim(),
          phone: _usePhone ? _emailController.text.trim() : null,
          password: _passwordController.text,
          name: _nameController.text.trim(),
          role: _selectedRole,
          cnic: _cnicController.text.isNotEmpty
              ? _cnicController.text.trim()
              : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/dashboard');
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Role Selection ──
                Text(
                  'I am a...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _roles.map((role) {
                    final isSelected = _selectedRole == role.$1;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(role.$3, size: 16),
                          const SizedBox(width: 4),
                          Text(role.$2),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor:
                          AppTheme.primaryColor.withValues(alpha: 0.2),
                      onSelected: (_) =>
                          setState(() => _selectedRole = role.$1),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // ── Name ──
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),

                // ── Email / Phone Toggle ──
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Email')),
                    ButtonSegment(value: true, label: Text('Phone')),
                  ],
                  selected: {_usePhone},
                  onSelectionChanged: (v) =>
                      setState(() => _usePhone = v.first),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _emailController,
                  keyboardType: _usePhone
                      ? TextInputType.phone
                      : TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: _usePhone ? 'Phone Number' : 'Email',
                    prefixIcon: Icon(
                      _usePhone ? Icons.phone : Icons.email_outlined,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return _usePhone
                          ? 'Phone is required'
                          : 'Email is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── CNIC (Optional) ──
                TextFormField(
                  controller: _cnicController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'CNIC (Optional)',
                    prefixIcon: Icon(Icons.badge_outlined),
                    hintText: '3520112345678',
                  ),
                ),
                const SizedBox(height: 16),

                // ── Password ──
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // ── Submit ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: authState.status == AuthStatus.loading
                        ? null
                        : _handleRegister,
                    child: authState.status == AuthStatus.loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 16),

                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Already have an account? Sign In'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
