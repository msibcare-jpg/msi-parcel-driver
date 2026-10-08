import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../services/backend.dart';
import '../services/demo_backend.dart';
import '../ui/kit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _country = TextEditingController(text: AppConfig.defaultCountryCode);
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _country.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String? _e164() {
    var cc = _country.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    var local = _phone.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (cc.isEmpty) return null;
    if (local.startsWith('0')) local = local.substring(1);
    if (local.length < 7 || local.length > 12) return null;
    return '+$cc$local';
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendIn = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _send() async {
    final phone = _e164();
    if (phone == null) {
      showMessage(context, 'Enter a valid mobile number.', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await Backend.instance.sendOtp(
        phone,
        onCodeSent: () {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _codeSent = true;
          });
          _startTimer();
        },
        onError: (msg) {
          if (!mounted) return;
          setState(() => _busy = false);
          showMessage(context, msg, error: true);
        },
        onAutoVerified: () {
          if (mounted) setState(() => _busy = false);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, 'Could not send the code. $e', error: true);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      showMessage(context, 'Enter the 6-digit code from the SMS.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await Backend.instance.confirmOtp(code);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = Backend.instance.isDemo;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            const Center(child: Logo(width: 230)),
            const SizedBox(height: 24),
            Text(
              _codeSent ? 'Enter the code' : 'Welcome to MSI Parcel',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              _codeSent
                  ? 'We sent a 6-digit code by SMS to ${_e164() ?? ''}.'
                  : 'Sign in or create an account with your mobile number.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            if (demo) ...[
              DemoBanner(_codeSent
                  ? 'Demo mode: the code is ${DemoBackend.demoSmsCode}.'
                  : 'Demo mode: no SMS is sent. Use any number.'),
              const SizedBox(height: 16),
            ],
            if (!_codeSent) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 92,
                    child: TextField(
                      controller: _country,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Code'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        hintText: '5X XXX XXXX',
                      ),
                      onSubmitted: (_) => _busy ? null : _send(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _send,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Send code'),
              ),
            ] else ...[
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(counterText: '', hintText: '••••••'),
                onSubmitted: (_) => _busy ? null : _verify(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _verify,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Verify & continue'),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _codeSent = false;
                              _code.clear();
                            }),
                    child: const Text('Change number'),
                  ),
                  TextButton(
                    onPressed: (_busy || _resendIn > 0) ? null : _send,
                    child: Text(_resendIn > 0 ? 'Resend in ${_resendIn}s' : 'Resend code'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            const Text(
              AppConfig.tagline,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
