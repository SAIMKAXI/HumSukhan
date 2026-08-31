import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../services/auth_service.dart';
import '../widgets/reusable_widgets.dart';

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
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.scaffoldBackgroundColor, theme.colorScheme.surfaceContainerHighest],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset('assets/logo.png', width: 140, height: 140, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isSignUp ? 'Create Account' : 'Welcome Back',
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp
                      ? 'Create your HumSukhan account to keep your profile and sessions available across devices.'
                      : 'Sign in to access your saved sessions and profile.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_isSignUp) ...[
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  maxLength: _isSignUp ? 8 : null,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText: _isSignUp ? 'Exactly 8 characters with upper/lowercase, number, and special character.' : null,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
                    child: Text(auth.error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryActionButton(
                  label: auth.isLoading ? 'Please wait…' : (_isSignUp ? 'Create Account' : 'Sign In'),
                  icon: _isSignUp ? Icons.person_add : Icons.login,
                  onPressed: auth.isLoading ? () {} : _handleSubmit,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: auth.isLoading
                      ? null
                      : () {
                          context.read<AuthProvider>().clearError();
                          setState(() => _isSignUp = !_isSignUp);
                        },
                  child: Text(_isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Sign up"),
                ),
                const SizedBox(height: 24),
                PrivacyNotice(
                  text: 'Your account data is stored securely. Audio is processed for captions; HumSukhan does not store raw microphone audio as part of the normal caption workflow.',
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
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter email and password')));
      return;
    }
    if (_isSignUp) {
      final error = AuthService.validatePassword(password);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
    }
    final auth = context.read<AuthProvider>();
    final success = _isSignUp
        ? await auth.signUp(email: email, password: password, name: name)
        : await auth.signIn(email: email, password: password);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }
}
