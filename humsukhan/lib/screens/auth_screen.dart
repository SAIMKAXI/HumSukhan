import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/reusable_widgets.dart';

/// Authentication screen with Supabase.
///
/// Provides:
/// - Email/password sign in
/// - Email/password sign up
/// - Anonymous sign in (for quick start)
/// - Skip option (offline mode)
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTokens.warmIvory, AppTokens.softCream],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                // Logo
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTokens.deepSage.withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  _isSignUp ? 'Create Account' : 'Welcome Back',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.textDeepForest,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp
                      ? 'Sign up to sync your data across devices'
                      : 'Sign in to access your saved sessions',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTokens.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Name field (sign up only)
                if (_isSignUp) ...[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Email field
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Password field
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),

                // Error message
                if (auth.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTokens.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      auth.error!,
                      style: const TextStyle(color: AppTokens.error, fontSize: 13),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Sign in/up button
                PrimaryActionButton(
                  label: auth.isLoading
                      ? 'Please wait...'
                      : (_isSignUp ? 'Create Account' : 'Sign In'),
                  icon: _isSignUp ? Icons.person_add : Icons.login,
                  onPressed: auth.isLoading ? () {} : _handleSubmit,
                ),

                const SizedBox(height: 12),

                // Toggle sign in/up
                TextButton(
                  onPressed: auth.isLoading
                      ? null
                      : () => setState(() {
                            _isSignUp = !_isSignUp;
                            auth.clearError();
                          }),
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign in'
                        : "Don't have an account? Sign up",
                    style: const TextStyle(color: AppTokens.deepSage),
                  ),
                ),

                const SizedBox(height: 16),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: AppTokens.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 16),

                // Anonymous sign in
                OutlinedButton.icon(
                  onPressed: auth.isLoading
                      ? null
                      : () async {
                          final success = await auth.signInAnonymously();
                          if (success && context.mounted) {
                            Navigator.of(context).pushReplacementNamed('/home');
                          }
                        },
                  icon: const Icon(Icons.explore, color: AppTokens.deepSage),
                  label: const Text(
                    'Try Without Account',
                    style: TextStyle(color: AppTokens.deepSage),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: const BorderSide(color: AppTokens.deepSage),
                  ),
                ),

                const SizedBox(height: 12),

                // Skip (offline mode)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/home');
                  },
                  child: const Text(
                    'Skip for now (offline mode)',
                    style: TextStyle(color: AppTokens.textMuted),
                  ),
                ),

                const SizedBox(height: 24),

                // Privacy note
                const PrivacyNotice(
                  text: 'Your data is encrypted and stored securely. '
                      'Audio is never stored — only text captions and metadata.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    bool success;

    if (_isSignUp) {
      success = await auth.signUp(email: email, password: password, name: name);
    } else {
      success = await auth.signIn(email: email, password: password);
    }

    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }
}
