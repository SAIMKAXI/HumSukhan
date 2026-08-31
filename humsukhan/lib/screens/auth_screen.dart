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
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';
    final createTitle = isUrdu ? 'اکاؤنٹ بنائیں' : 'Create Account';
    final signInTitle = isUrdu ? 'خوش آمدید' : 'Welcome Back';
    final createDesc = isUrdu ? 'اپنا HumSukhan اکاؤنٹ بنائیں تاکہ آپ کی پروفائل اور اجلاس آپ کی ڈیوائسز پر دستیاب رہیں۔' : 'Create your HumSukhan account to keep your profile and sessions available across devices.';
    final signInDesc = isUrdu ? 'اپنے محفوظ شدہ اجلاس اور پروفائل تک رسائی کے لیے سائن اِن کریں۔' : 'Sign in to access your saved sessions and profile.';
    final nameLabel = isUrdu ? 'نام' : 'Name';
    final emailLabel = isUrdu ? 'ای میل' : 'Email';
    final passwordLabel = isUrdu ? 'پاس ورڈ' : 'Password';
    final passwordHint = isUrdu ? 'بالکل 8 حروف، بڑے/چھوٹے حروف، نمبر اور خاص علامت کے ساتھ۔' : 'Exactly 8 characters with upper/lowercase, number, and special character.';
    final waitLabel = isUrdu ? 'براہ کرم انتظار کریں…' : 'Please wait…';
    final haveAccount = isUrdu ? 'پہلے سے اکاؤنٹ ہے؟ سائن اِن کریں' : 'Already have an account? Sign in';
    final needAccount = isUrdu ? 'اکاؤنٹ نہیں ہے؟ سائن اَپ کریں' : "Don't have an account? Sign up";
    final privacy = isUrdu ? 'آپ کے اکاؤنٹ کا ڈیٹا محفوظ رکھا جاتا ہے۔ کیپشنز کے لیے آڈیو عارضی طور پر پروسیس ہوتی ہے؛ معمول کے کیپشن ورک فلو میں خام مائیکروفون آڈیو محفوظ نہیں کی جاتی۔' : 'Your account data is stored securely. Audio is processed for captions; HumSukhan does not store raw microphone audio as part of the normal caption workflow.';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [theme.scaffoldBackgroundColor, theme.colorScheme.surfaceContainerHighest])),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Center(child: ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.asset('assets/logo.png', width: 140, height: 140, fit: BoxFit.cover))),
                const SizedBox(height: 24),
                Text(_isSignUp ? createTitle : signInTitle, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(_isSignUp ? createDesc : signInDesc, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: isUrdu ? 1.7 : null), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                if (_isSignUp) ...[
                  TextField(controller: _nameController, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: nameLabel, prefixIcon: const Icon(Icons.person_outline))),
                  const SizedBox(height: 16),
                ],
                TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: emailLabel, prefixIcon: const Icon(Icons.email_outlined))),
                const SizedBox(height: 16),
                TextField(controller: _passwordController, obscureText: _obscurePassword, maxLength: _isSignUp ? 8 : null, decoration: InputDecoration(labelText: passwordLabel, helperText: _isSignUp ? passwordHint : null, helperMaxLines: 2, prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)))),
                if (auth.error != null) ...[
                  const SizedBox(height: 12),
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)), child: Text(auth.error!, style: TextStyle(color: theme.colorScheme.onErrorContainer))),
                ],
                const SizedBox(height: 24),
                PrimaryActionButton(label: auth.isLoading ? waitLabel : (_isSignUp ? createTitle : (isUrdu ? 'سائن اِن' : 'Sign In')), icon: _isSignUp ? Icons.person_add : Icons.login, onPressed: auth.isLoading ? null : _handleSubmit),
                const SizedBox(height: 12),
                TextButton(onPressed: auth.isLoading ? null : () { context.read<AuthProvider>().clearError(); setState(() => _isSignUp = !_isSignUp); }, child: Text(_isSignUp ? haveAccount : needAccount)),
                const SizedBox(height: 24),
                PrivacyNotice(text: privacy),
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
    // Navigation is owned by the auth gate. Do not push /home here; doing both
    // causes duplicate/stale navigator stacks when Supabase emits auth events.
  }
}
