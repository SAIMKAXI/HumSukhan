import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../services/auth_service.dart';
import '../widgets/reusable_widgets.dart';
import '../widgets/modern_ui.dart';
import '../theme/app_theme.dart';

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
    final colors = theme.colorScheme;
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';
    final title = _isSignUp ? (isUrdu ? 'اکاؤنٹ بنائیں' : 'Create your account') : (isUrdu ? 'خوش آمدید' : 'Welcome back');
    final desc = _isSignUp ? (isUrdu ? 'اپنی گفتگو، پروفائل اور اجلاس ایک محفوظ جگہ پر رکھیں۔' : 'Keep your conversations, profile and sessions in one secure place.') : (isUrdu ? 'اپنی محفوظ گفتگو اور معاون فیچرز تک رسائی حاصل کریں۔' : 'Continue to your saved conversations and assistive tools.');
    final privacy = isUrdu ? 'آپ کی رازداری پہلے۔ خام مائیکروفون آڈیو معمول کے کیپشن ورک فلو میں محفوظ نہیں کی جاتی۔' : 'Privacy first. Raw microphone audio is not stored as part of the normal caption workflow.';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const BrandLogo(size: 56),
                  const SizedBox(width: 12),
                  Text('HumSukhan', style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 48),
              Text(title, style: theme.textTheme.displaySmall),
              const SizedBox(height: 10),
              Text(desc, style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant, height: 1.5)),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppTokens.radiusFull)),
                child: Row(
                  children: [
                    Expanded(child: _modeChip(context, isUrdu ? 'سائن اِن' : 'Sign in', !_isSignUp)),
                    Expanded(child: _modeChip(context, isUrdu ? 'سائن اَپ' : 'Sign up', _isSignUp)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_isSignUp) ...[
                TextField(controller: _nameController, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: isUrdu ? 'نام' : 'Name', prefixIcon: const Icon(Icons.person_outline_rounded))),
                const SizedBox(height: 12),
              ],
              TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: isUrdu ? 'ای میل' : 'Email', prefixIcon: const Icon(Icons.mail_outline_rounded))),
              const SizedBox(height: 12),
              TextField(controller: _passwordController, obscureText: _obscurePassword, maxLength: _isSignUp ? 8 : null, decoration: InputDecoration(labelText: isUrdu ? 'پاس ورڈ' : 'Password', helperText: _isSignUp ? (isUrdu ? '8 حروف: بڑے/چھوٹے حروف، نمبر اور خاص علامت۔' : '8 characters with upper/lowercase, number and special character.') : null, prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => _obscurePassword = !_obscurePassword), icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
              if (auth.error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: colors.errorContainer, borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
                  child: Row(children: [Icon(Icons.error_outline_rounded, color: colors.error), const SizedBox(width: 12), Expanded(child: Text(auth.error!, style: TextStyle(color: colors.onErrorContainer))) ]),
                ),
              ],
              const SizedBox(height: 20),
              PrimaryActionButton(label: auth.isLoading ? (isUrdu ? 'براہ کرم انتظار کریں…' : 'Please wait…') : (_isSignUp ? (isUrdu ? 'اکاؤنٹ بنائیں' : 'Create account') : (isUrdu ? 'سائن اِن' : 'Sign in')), icon: _isSignUp ? Icons.arrow_forward_rounded : Icons.login_rounded, onPressed: () { if (!auth.isLoading) _handleSubmit(); }),
              const SizedBox(height: 12),
              PrivacyStrip(text: privacy),
              const SizedBox(height: 16),
              Text(isUrdu ? 'محفوظ • قابلِ اعتماد • آپ کے کنٹرول میں' : 'Private • dependable • in your control', textAlign: TextAlign.center, style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeChip(BuildContext context, String label, bool selected) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        context.read<AuthProvider>().clearError();
        setState(() => _isSignUp = label.toLowerCase().contains('sign up') || label.contains('سائن اَپ'));
      },
      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: selected ? colors.surface : Colors.transparent, borderRadius: BorderRadius.circular(AppTokens.radiusFull), boxShadow: selected ? [BoxShadow(color: colors.primary.withValues(alpha: .08), blurRadius: 10, offset: const Offset(0, 4))] : null),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: selected ? colors.primary : colors.onSurfaceVariant)),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isUrdu ? 'براہ کرم ای میل اور پاس ورڈ درج کریں' : 'Please enter email and password')));
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
    if (_isSignUp) {
      await auth.signUp(email: email, password: password, name: name);
    } else {
      await auth.signIn(email: email, password: password);
    }
  }
}
