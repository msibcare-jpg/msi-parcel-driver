import 'dart:async';

import 'package:flutter/material.dart';

import '../models/driver_profile.dart';
import '../services/backend.dart';
import '../ui/kit.dart';
import '../widgets/order_widgets.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'pending_screen.dart';
import 'register_screen.dart';

/// Decides which screen the driver sees:
/// not signed in -> Login, no profile -> Register,
/// pending/rejected/suspended -> Pending, approved -> Home.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthUser?> _auth;
  String? _uid;
  Stream<DriverProfile?>? _driver;

  @override
  void initState() {
    super.initState();
    _auth = Backend.instance.authChanges();
  }

  Stream<DriverProfile?> _driverStream(String uid) {
    if (_uid != uid || _driver == null) {
      _uid = uid;
      _driver = Backend.instance.watchDriver(uid);
    }
    return _driver!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: _auth,
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        final user = authSnap.data;
        if (user == null) {
          _uid = null;
          _driver = null;
          return const LoginScreen();
        }
        return StreamBuilder<DriverProfile?>(
          key: ValueKey(user.uid),
          stream: _driverStream(user.uid),
          builder: (context, snap) {
            if (snap.hasError) {
              return _ErrorView(message: '${snap.error}');
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const _Loading();
            }
            final profile = snap.data;
            if (profile == null) return const RegisterScreen();
            if (profile.isApproved) return HomeScreen(profile: profile);
            return PendingScreen(profile: profile);
          },
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Logo(width: 240),
            SizedBox(height: 24),
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 12),
              const Text('Could not load your account.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Backend.instance.signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
