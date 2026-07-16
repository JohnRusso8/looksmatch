import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_controller.dart';
import '../../theme/app_theme.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.auth,
    required this.phoneNumber,
    required this.verificationId,
    required this.resendToken,
  });

  final AuthController auth;
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _codeLength = 6;

  final List<TextEditingController> _controllers = List.generate(
    _codeLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _codeLength,
    (_) => FocusNode(),
  );

  bool _submitting = false;
  bool _resending = false;
  int _resendSeconds = 30;
  Timer? _timer;
  late String _verificationId;
  int? _resendToken;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
    _startResendTimer();
  }

  void _startResendTimer({bool rebuild = false}) {
    _timer?.cancel();
    if (rebuild) {
      setState(() => _resendSeconds = 30);
    } else {
      _resendSeconds = 30;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  String get _displayPhoneNumber {
    final digits = widget.phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('1')) {
      return '+1 (${digits.substring(1, 4)}) '
          '${digits.substring(4, 7)}-${digits.substring(7)}';
    }
    return widget.phoneNumber;
  }

  void _handleChanged(int index, String value) {
    if (value.isNotEmpty && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (_code.length == _codeLength) {
      _verify();
    }
  }

  Future<void> _verify() async {
    if (_code.length != _codeLength || _submitting) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      await widget.auth.confirmPhoneCode(
        verificationId: _verificationId,
        smsCode: _code,
      );

      if (!mounted) return;
      _finishAuthentication();
    } catch (error) {
      if (!mounted) return;
      _clearCode();
      _showMessage(authErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _resendCode() async {
    if (_resending || _resendSeconds > 0) return;

    setState(() => _resending = true);

    try {
      final session = await widget.auth.sendPhoneVerificationCode(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: _resendToken,
        onAutomaticVerification: _finishAuthentication,
      );

      if (!mounted) return;
      if (session.automaticallyVerified) {
        _finishAuthentication();
        return;
      }

      setState(() {
        _verificationId = session.verificationId;
        _resendToken = session.resendToken;
      });
      _clearCode();
      _startResendTimer(rebuild: true);
      _showMessage('A new verification code was sent.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(authErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  void _finishAuthentication() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _clearCode() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes.first.requestFocus();
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
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
                child: Icon(Icons.sms_outlined, color: colors.accent, size: 28),
              ),
              const SizedBox(height: 18),
              Text(
                'Verify your number',
                style: TextStyle(
                  color: colors.headerPrimaryText,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code sent to $_displayPhoneNumber',
                style: TextStyle(
                  color: colors.headerSecondaryText,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  _codeLength,
                  (index) => _otpBox(colors, index),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _verify,
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
                    : const Text('Verify'),
              ),
              const SizedBox(height: 16),
              Center(
                child: _resendSeconds > 0
                    ? Text(
                        'Resend code in $_resendSeconds s',
                        style: TextStyle(
                          color: colors.headerSecondaryText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : TextButton(
                        onPressed: _resending ? null : _resendCode,
                        child: _resending
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.accent,
                                ),
                              )
                            : Text(
                                'Resend Code',
                                style: TextStyle(
                                  color: colors.accent,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(LooksMatchColors colors, int index) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          color: colors.headerPrimaryText,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: colors.inputBackground,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: colors.inputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: colors.accent, width: 1.6),
          ),
        ),
        onChanged: (value) => _handleChanged(index, value),
      ),
    );
  }
}
