import 'package:flutter/material.dart';

import '../../services/auth_controller.dart';
import '../../theme/app_theme.dart';
import 'otp_verification_screen.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final digits = _nationalPhoneDigits(value ?? '');
    if (digits.length != 10) return 'Enter a valid 10-digit phone number';
    return null;
  }

  String _nationalPhoneDigits(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('1')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  String get _phoneNumber => '+1${_nationalPhoneDigits(_phoneController.text)}';

  void _finishAuthentication() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      final session = await widget.auth.sendPhoneVerificationCode(
        phoneNumber: _phoneNumber,
        onAutomaticVerification: _finishAuthentication,
      );

      if (!mounted) return;
      if (session.automaticallyVerified) {
        _finishAuthentication();
        return;
      }

      setState(() => _submitting = false);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            auth: widget.auth,
            phoneNumber: _phoneNumber,
            verificationId: session.verificationId,
            resendToken: session.resendToken,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(authErrorMessage(error));
    } finally {
      if (mounted && _submitting) {
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
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors.scoreBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phone_iphone_rounded,
                    color: colors.accent,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Enter your phone number',
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We\'ll text you a code to verify it\'s you. Standard message '
                  'and data rates may apply.',
                  style: TextStyle(
                    color: colors.headerSecondaryText,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: '(555) 123-4567',
                    hintStyle: TextStyle(
                      color: colors.inputHint,
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                      child: Text(
                        '+1',
                        style: TextStyle(
                          color: colors.headerPrimaryText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                    filled: true,
                    fillColor: colors.inputBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: colors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: colors.accent, width: 1.5),
                    ),
                  ),
                  validator: _validatePhone,
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _submitting ? null : _sendCode,
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
                      : const Text('Send Code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
