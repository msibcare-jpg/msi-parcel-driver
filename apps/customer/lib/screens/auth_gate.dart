import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/backend.dart';
import '../ui/kit.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';

/// Not signed in -> Login, no name yet -> Profile setup, otherwise Home.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthUser?> _auth;
  String? _uid;
  Stream<CustomerProfile?>? _profile;

  @override
  void initState() {
    super.initState();
    _auth = Backend.instance.authChanges();
  }

  Stream<CustomerProfile?> _profileStream(String uid) {
    if (_uid != uid || _profile == null) {
      _uid = uid;
      _profile = Backend.instance.watchProfile(uid);
    }
    return _profile!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: _auth,
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) return const _Loading();
        final user = authSnap.data;
        if (user == null) {
          _uid = null;
          _profile = null;
          return const LoginScreen();
        }
        return StreamBuilder<CustomerProfile?>(
          key: ValueKey(user.uid),
          stream: _profileStream(user.uid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const _Loading();
            final p = snap.data;
            if (p == null) return const ProfileSetupScreen();
            return HomeScreen(profile: p);
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
