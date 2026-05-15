import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // RFC 5322-inspired pattern: local@domain.tld
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  // 3–30 chars, letters/digits/underscores only
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,30}$');

  Future<void> _submit({required bool isLogin}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final Map<String, dynamic> data;
      if (isLogin) {
        data = await AuthService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        data = await AuthService.register(
          _usernameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
        );
      }

      await AuthService.saveTokens(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      final user = data['user'] as Map<String, dynamic>;
      final emailVerified = user['email_verified'] as bool? ?? false;
      await AuthService.saveUser(
        user['username'] as String,
        user['email'] as String,
        emailVerified: emailVerified,
      );
      await AuthService.saveRole(user['role'] as String? ?? 'patron');

      if (!mounted) return;

      if (!isLogin && !emailVerified) {
        await _showVerificationDialog(user['email'] as String);
        if (!mounted) return;
      }

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showVerificationDialog(String email) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VerificationDialog(email: email),
    );
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) return 'Username is required';
    if (!_usernameRegex.hasMatch(value.trim())) {
      return 'Username must be 3–30 characters: letters, digits or underscores';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (_isLogin) return null;
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Must contain an uppercase letter';
    if (!value.contains(RegExp(r'[a-z]'))) return 'Must contain a lowercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Must contain a number';
    if (!value.contains(RegExp(r'[!@#\$%^&*()\-_=+\[\]{};:,.<>?/\\|`~]'))) {
      return 'Must contain a special character';
    }
    return null;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Register')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Xabarla',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],

                if (!_isLogin) ...[
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                      helperText: '3–30 characters, letters/digits/underscores',
                    ),
                    textInputAction: TextInputAction.next,
                    validator: _validateUsername,
                  ),
                  const SizedBox(height: 12),
                ],

                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    helperText: _isLogin
                        ? null
                        : 'Min 8 chars, upper & lower case, number, special character',
                    helperMaxLines: 2,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) =>
                      _isSubmitting ? null : _submit(isLogin: _isLogin),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isSubmitting ? null : () => _submit(isLogin: _isLogin),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isLogin ? 'Login' : 'Register'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() {
                            _isLogin = !_isLogin;
                            _errorMessage = null;
                          }),
                  child: Text(_isLogin
                      ? "Don't have an account? Register"
                      : 'Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerificationDialog extends StatefulWidget {
  final String email;
  const _VerificationDialog({required this.email});

  @override
  State<_VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends State<_VerificationDialog> {
  bool _resending = false;
  String? _resendMessage;
  bool _resendError = false;

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _resendMessage = null;
    });
    try {
      await AuthService.resendVerification();
      if (mounted) {
        setState(() {
          _resendMessage = 'Email resent — check your inbox.';
          _resendError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _resendMessage = e.toString();
          _resendError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: Icon(
        Icons.mark_email_unread_outlined,
        size: 40,
        color: theme.colorScheme.primary,
      ),
      title: const Text('Verify your email'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('We sent a verification link to:'),
          const SizedBox(height: 4),
          Text(
            widget.email,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Some features — like creating posts and subscribing — require a verified account. You can continue now and verify later.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_resendMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _resendMessage!,
              style: TextStyle(
                fontSize: 13,
                color: _resendError
                    ? theme.colorScheme.error
                    : Colors.green.shade700,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _resending ? null : _resend,
          child: _resending
              ? const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Resend email'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
