import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/driver_profile.dart';
import '../services/backend.dart';
import '../services/demo_backend.dart';
import '../ui/kit.dart';
import '../widgets/order_widgets.dart';
import 'register_screen.dart';

/// Shown while the office reviews the application,
/// or when it was rejected / the account is suspended.
class PendingScreen extends StatelessWidget {
  final DriverProfile profile;
  const PendingScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final rejected = profile.status == DriverStatus.rejected;
    final suspended = profile.status == DriverStatus.suspended;
    final IconData icon = rejected
        ? Icons.error_outline
        : suspended
            ? Icons.block
            : Icons.hourglass_top_rounded;
    final Color color = rejected || suspended ? AppColors.bad : AppColors.teal;
    final String title = rejected
        ? 'Application not approved'
        : suspended
            ? 'Account paused'
            : 'Application received';
    final String body = rejected
        ? (profile.rejectReason?.isNotEmpty == true
            ? profile.rejectReason!
            : 'Some details need to be fixed. Update your application and send it again.')
        : suspended
            ? 'Your account is paused. Contact the MSI Parcel office: ${AppConfig.supportPhone}'
            : 'Thanks, ${profile.name.split(' ').first}. Our team is checking your documents. '
                'This screen updates by itself once you are approved.';

    final backend = Backend.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
        actions: [
          TextButton(onPressed: () => backend.signOut(), child: const Text('Sign out')),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 10),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 15)),
            const SizedBox(height: 24),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Name', profile.name),
                  _row('Mobile', profile.phone),
                  _row('City', profile.city),
                  _row('Vehicle', '${profile.vehicleType} · ${profile.plateNumber}'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (rejected)
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RegisterScreen(previous: profile)),
                ),
                child: const Text('Update and send again'),
              ),
            if (backend is DemoBackend && !rejected && !suspended) ...[
              const DemoBanner('Demo mode: in the real app the office approves you from the Admin panel.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => backend.demoApprove(),
                child: const Text('Demo: approve me now'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 80, child: Text(k, style: const TextStyle(color: AppColors.muted))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
