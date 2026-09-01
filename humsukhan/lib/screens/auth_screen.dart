import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../services/auth_service.dart';
import '../widgets/reusable_widgets.dart';
import '../widgets/modern_ui.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  final bool recoveryMode;

  const AuthScreen({super.key, this.recoveryMode = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSignUp = false;
  bool _isForgotPassword = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _isForgotPassword = false;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';

    if (widget.recoveryMode) {
      return _buildRecoveryUpdate(context, auth, theme, colors, isUrdu);
    }
    if (_isForgotPassword) {
      return _buildForgotPassword(context, auth, theme, colors, isUrdu);
    }

    final title = _isSignUp
        ? (isUrdu ? 'اکاؤنٹ بنائیں' : 'Create your account')
        : (isUrdu ? 'خوش آمدید' : 'Welcome back');
    final desc = _isSignUp
        ? (isUrdu
            ? 'اپنی گفتگو، پروفائل اور اجلاس ایک محفوظ جگہ پر رکھیں۔'
            : 'Keep your conversations, profile and sessions in one secure place.')
        : (isUrdu
            ? 'اپنی محفوظ گفتگو اور معاون فیچرز تک رسائی حاصل کریں۔'
            : 'Continue to your saved conversations and assistive tools.');
    final privacy = isUrdu
        ? 'آپ کی رازداری پہلے۔ خام مائیکروفون آڈیو معمول کے کیپشن ورک فلو میں محفوظ نہیں کی جاتی۔'
        : 'Privacy first. Raw microphone audio is not stored as part of the normal caption workflow.';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _brandHeader(context, theme),
              const SizedBox(height: 48),
              Text(title, style: theme.textTheme.displaySmall),
              const SizedBox(height: 10),
              Text(desc, style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant, height: 1.5)),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                ),
                child: Row(
                  children: [
                    Expanded(child: _modeChip(context, isUrdu ? 'سائن اِن' : 'Sign in', !_isSignUp)),
                    Expanded(child: _modeChip(context, isUrdu ? 'سائن اَپ' : 'Sign up', _isSignUp)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_isSignUp) ...[
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: isUrdu ? 'نام' : 'Name',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: isUrdu ? 'ای میل' : 'Email',
                  prefixIcon: const Icon(Icons.mail_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                maxLength: _isSignUp ? 8 : null,
                textInputAction: _isSignUp ? TextInputAction.next : TextInputAction.done,
                autofillHints: _isSignUp ? const [AutofillHints.newPassword] : const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: isUrdu ? 'پاس ورڈ' : 'Password',
                  helperText: _isSignUp
                      ? (isUrdu
                          ? '8 حروف: بڑے/چھوٹے حروف، نمبر اور خاص علامت۔'
                          : '8 characters with upper/lowercase, number and special character.')
                      : null,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
              ),
              if (!_isSignUp) ...[
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: auth.isLoading ? null : () {
                      auth.clearError();
                      setState(() => _isForgotPassword = true);
                    },
                    child: Text(isUrdu ? 'پاس ورڈ بھول گئے؟' : 'Forgot password?'),
                  ),
                ),
              ],
              if (auth.error != null) _errorBanner(context, auth.error!),
              const SizedBox(height: 12),
              PrimaryActionButton(
                label: auth.isLoading
                    ? (isUrdu ? 'براہ کرم انتظار کریں…' : 'Please wait…')
                    : (_isSignUp
                        ? (isUrdu ? 'اکاؤنٹ بنائیں' : 'Create account')
                        : (isUrdu ? 'سائن اِن' : 'Sign in')),
                icon: _isSignUp ? Icons.arrow_forward_rounded : Icons.login_rounded,
                onPressed: auth.isLoading ? null : _handleSubmit,
              ),
              const SizedBox(height: 12),
              PrivacyStrip(text: privacy),
              const SizedBox(height: 16),
              Text(
                isUrdu ? 'محفوظ • قابلِ اعتماد • آپ کے کنٹرول میں' : 'Private • dependable • in your control',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brandHeader(BuildContext context, ThemeData theme) => Row(
        children: [
          const BrandLogo(size: 56),
          const SizedBox(width: 12),
          Text('HumSukhan', style: theme.textTheme.titleLarge),
        ],
      );

  Widget _modeChip(BuildContext context, String label, bool selected) {
    final colors = Theme.of(context).colorScheme;
    final isSignUp = label == 'Sign up' || label.contains('سائن اَپ');
    return InkWell(
      onTap: selected
          ? null
          : () {
              context.read<AuthProvider>().clearError();
              setState(() => _isSignUp = isSignUp);
            },
      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusFull),
          boxShadow: selected
              ? [BoxShadow(color: colors.primary.withValues(alpha: .08), blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
        ),
      ),
    );
  }

  Widget _errorBanner(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colors.error),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: colors.onErrorContainer))),
        ],
      ),
    );
  }

  Widget _buildForgotPassword(
    BuildContext context,
    AuthProvider auth,
    ThemeData theme,
    ColorScheme colors,
    bool isUrdu,
  ) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: isUrdu ? 'واپس' : 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: auth.isLoading ? null : () {
            auth.clearError();
            setState(() => _isForgotPassword = false);
          },
        ),
        title: Text(isUrdu ? 'پاس ورڈ دوبارہ حاصل کریں' : 'Reset password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _brandHeader(context, theme),
              const SizedBox(height: 40),
              Icon(Icons.mark_email_read_outlined, size: 56, color: colors.primary),
              const SizedBox(height: 20),
              Text(
                isUrdu ? 'اپنا ای میل درج کریں' : 'Enter your email',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                isUrdu
                    ? 'ہم آپ کو پاس ورڈ تبدیل کرنے کے لیے ری سیٹ لنک بھیجیں گے۔'
                    : 'We’ll send you a secure link to choose a new password.',
                style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: isUrdu ? 'ای میل' : 'Email',
                  prefixIcon: const Icon(Icons.mail_outline_rounded),
                ),
              ),
              if (auth.error != null) _errorBanner(context, auth.error!),
              const SizedBox(height: 20),
              PrimaryActionButton(
                label: auth.isLoading ? (isUrdu ? 'بھیجا جا رہا ہے…' : 'Sending…') : (isUrdu ? 'ری سیٹ لنک بھیجیں' : 'Send reset link'),
                icon: Icons.send_outlined,
                onPressed: auth.isLoading ? null : _handleResetRequest,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecoveryUpdate(
    BuildContext context,
    AuthProvider auth,
    ThemeData theme,
    ColorScheme colors,
    bool isUrdu,
  ) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _brandHeader(context, theme),
              const SizedBox(height: 48),
              Text(isUrdu ? 'نیا پاس ورڈ مقرر کریں' : 'Set a new password', style: theme.textTheme.displaySmall),
              const SizedBox(height: 10),
              Text(
                isUrdu ? 'اپنے اکاؤنٹ کے لیے نیا 8 حروف کا مضبوط پاس ورڈ منتخب کریں۔' : 'Choose a new 8-character strong password for your account.',
                style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                maxLength: 8,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: isUrdu ? 'نیا پاس ورڈ' : 'New password',
                  helperText: isUrdu ? 'بڑے/چھوٹے حروف، نمبر اور خاص علامت۔' : 'Uppercase, lowercase, number and special character.',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                maxLength: 8,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: isUrdu ? 'پاس ورڈ کی تصدیق' : 'Confirm password',
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
              ),
              if (auth.error != null) _errorBanner(context, auth.error!),
              const SizedBox(height: 20),
              PrimaryActionButton(
                label: auth.isLoading ? (isUrdu ? 'اپ ڈیٹ ہو رہا ہے…' : 'Updating…') : (isUrdu ? 'پاس ورڈ اپ ڈیٹ کریں' : 'Update password'),
                icon: Icons.check_circle_outline_rounded,
                onPressed: auth.isLoading ? null : _handlePasswordUpdate,
              ),
            ],
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

    final emailError = AuthService.validateEmail(email);
    if (emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isUrdu ? 'درست ای میل درج کریں' : emailError)));
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isUrdu ? 'پاس ورڈ درج کریں' : 'Please enter your password.')));
      return;
    }
    if (_isSignUp) {
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isUrdu ? 'نام درج کریں' : 'Please enter your name.')));
        return;
      }
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

  Future<void> _handleResetRequest() async {
    final email = _emailController.text.trim();
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';
    final error = AuthService.validateEmail(email);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isUrdu ? 'درست ای میل درج کریں' : error)));
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(email);
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isUrdu ? 'ری سیٹ لنک ای میل کر دیا گیا ہے۔' : 'Password reset link sent. Check your email.')),
    );
    auth.clearError();
    setState(() => _isForgotPassword = false);
  }

  Future<void> _handlePasswordUpdate() async {
    final password = _passwordController.text;
    final confirmation = _confirmPasswordController.text;
    final isUrdu = Localizations.localeOf(context).languageCode == 'ur';
    final error = AuthService.validatePassword(password);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (password != confirmation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isUrdu ? 'پاس ورڈ ایک جیسے نہیں ہیں' : 'Passwords do not match.')),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    await auth.updatePassword(password);
  }
}
