import 'package:flutter/material.dart';

import '../../services/auth_controller.dart';
import '../../theme/app_theme.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isCreatingAccount = true;
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email';
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!valid) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Enter a password';
    if (password.length < 6) return 'Use at least 6 characters';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      if (_isCreatingAccount) {
        await widget.auth.createAccountWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await widget.auth.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      _showMessage(authErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.headerBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: colors.headerIconColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isCreatingAccount ? 'Create your account' : 'Welcome back',
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isCreatingAccount
                      ? 'Sign up with your email to start getting matches.'
                      : 'Sign in with the email on your LooksMatch account.',
                  style: TextStyle(
                    color: colors.headerSecondaryText,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.inputBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.inputBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _modeButton(
                          colors: colors,
                          label: 'Create Account',
                          selected: _isCreatingAccount,
                          onTap: () =>
                              setState(() => _isCreatingAccount = true),
                        ),
                      ),
                      Expanded(
                        child: _modeButton(
                          colors: colors,
                          label: 'Sign In',
                          selected: !_isCreatingAccount,
                          onTap: () =>
                              setState(() => _isCreatingAccount = false),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: _fieldDecoration(
                    colors,
                    hint: 'Email',
                    icon: Icons.mail_outline_rounded,
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: _fieldDecoration(
                    colors,
                    hint: 'Password',
                    icon: Icons.lock_outline_rounded,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: colors.headerSecondaryText,
                      ),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primaryButtonBackground,
                    foregroundColor: colors.primaryButtonText,
                    disabledBackgroundColor: colors.primaryButtonBackground
                        .withOpacity(0.5),
                    minimumSize: const Size.fromHeight(52),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: colors.primaryButtonText,
                          ),
                        )
                      : Text(_isCreatingAccount ? 'Create Account' : 'Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeButton({
    required LooksMatchColors colors,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? colors.accent.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? colors.accent : colors.headerSecondaryText,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    LooksMatchColors colors, {
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: colors.inputHint,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: colors.accent),
      suffixIcon: suffix,
      filled: true,
      fillColor: colors.inputBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: colors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: colors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: colors.deleteBackground),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: colors.deleteBackground, width: 1.5),
      ),
    );
  }
}
