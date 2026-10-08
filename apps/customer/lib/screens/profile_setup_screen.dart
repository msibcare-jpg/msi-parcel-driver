import 'package:flutter/material.dart';

import '../services/backend.dart';
import '../ui/kit.dart';

/// First sign in: ask for the customer's name.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      showMessage(context, 'Enter your name.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await Backend.instance.saveProfile(name);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),
            const Center(child: Logo(width: 200)),
            const SizedBox(height: 28),
            const Text('What should we call you?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink)),
            const SizedBox(height: 6),
            const Text('Drivers see this name when they pick up your parcel.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name or shop name'),
              onSubmitted: (_) => _busy ? null : _save(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Continue'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(onPressed: () => Backend.instance.signOut(), child: const Text('Use another number')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
