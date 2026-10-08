import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../core/order_status.dart';
import '../models/delivery_job.dart';
import '../models/driver_profile.dart';
import '../services/backend.dart';
import '../services/location_service.dart';
import '../ui/kit.dart';
import '../widgets/order_widgets.dart';
import 'job_screen.dart';

class HomeScreen extends StatefulWidget {
  final DriverProfile profile;
  const HomeScreen({super.key, required this.profile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Stream<List<DeliveryJob>> _jobs;
  late final Stream<List<WalletTx>> _wallet;
  int _tab = 0;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _jobs = Backend.instance.watchMyJobs(widget.profile.uid);
    _wallet = Backend.instance.watchWallet(widget.profile.uid);
    if (widget.profile.online) {
      LocationService.instance.start();
    }
  }

  Future<void> _toggleOnline(bool goOnline) async {
    setState(() => _switching = true);
    try {
      if (goOnline) {
        final r = await LocationService.instance.start();
        if (r != LocationResult.ok) {
          if (!mounted) return;
          _explainLocation(r);
          return;
        }
      } else {
        await LocationService.instance.stop();
      }
      await Backend.instance.setOnline(goOnline);
      if (mounted) showMessage(context, goOnline ? 'You are online. New jobs will arrive here.' : 'You are offline');
    } catch (e) {
      if (mounted) showMessage(context, 'Could not change status. $e', error: true);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  void _explainLocation(LocationResult r) {
    final text = r == LocationResult.serviceOff
        ? 'Turn on location (GPS) to go online.'
        : 'Allow location access so customers can track deliveries.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'Settings',
        onPressed: () => r == LocationResult.serviceOff
            ? LocationService.instance.openLocationSettings()
            : LocationService.instance.openSettings(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<DeliveryJob>>(
          stream: _jobs,
          builder: (context, jobSnap) {
            return StreamBuilder<List<WalletTx>>(
              stream: _wallet,
              builder: (context, walletSnap) {
                if (jobSnap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not load deliveries.\n${jobSnap.error}', textAlign: TextAlign.center),
                    ),
                  );
                }
                if (!jobSnap.hasData) return const Center(child: CircularProgressIndicator());
                final jobs = jobSnap.data!;
                final wallet = walletSnap.data ?? const <WalletTx>[];
                switch (_tab) {
                  case 1:
                    return _HistoryTab(jobs: jobs);
                  case 2:
                    return _WalletTab(txs: wallet, jobs: jobs);
                  case 3:
                    return _ProfileTab(profile: p);
                  default:
                    return _TodayTab(
                      profile: p,
                      jobs: jobs,
                      wallet: wallet,
                      switching: _switching,
                      onToggle: _toggleOnline,
                      openWallet: () => setState(() => _tab = 2),
                      openHistory: () => setState(() => _tab = 1),
                    );
                }
              },
            );
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'History'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// =================================================================== TODAY
class _TodayTab extends StatelessWidget {
  final DriverProfile profile;
  final List<DeliveryJob> jobs;
  final List<WalletTx> wallet;
  final bool switching;
  final ValueChanged<bool> onToggle;
  final VoidCallback openWallet;
  final VoidCallback openHistory;

  const _TodayTab({
    required this.profile,
    required this.jobs,
    required this.wallet,
    required this.switching,
    required this.onToggle,
    required this.openWallet,
    required this.openHistory,
  });

  @override
  Widget build(BuildContext context) {
    final active = jobs.where((j) => OrderStatus.active.contains(j.status)).toList()
      ..sort((a, b) => (a.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(b.createdAt?.millisecondsSinceEpoch ?? 0));
    final doneToday =
        jobs.where((j) => j.status == OrderStatus.delivered && Period.today.contains(j.deliveredAt)).toList();
    final earnedToday = doneToday.fold<double>(0, (s, j) => s + j.driverEarning);
    final cashHeld = jobs
        .where((j) => j.status == OrderStatus.delivered && j.codCollected && !j.codSettled)
        .fold<double>(0, (s, j) => s + j.codAmount);
    final first = profile.name.split(' ').first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting(), style: const TextStyle(color: AppColors.muted)),
                  Text(first, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink)),
                ],
              ),
            ),
            const Logo(width: 84),
          ],
        ),
        const SizedBox(height: 14),
        HeroCard(
          gradient: profile.online
              ? brandGradient
              : const LinearGradient(colors: [Color(0xFF3A3448), Color(0xFF5A5368)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: profile.online ? AppColors.tealBright : AppColors.white70,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      profile.online ? 'You are online' : 'You are offline',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Switch(
                    value: profile.online,
                    activeTrackColor: AppColors.tealBright,
                    onChanged: switching ? null : onToggle,
                  ),
                ],
              ),
              Text(
                profile.online ? 'Customers can see you on the map.' : 'Go online to start receiving deliveries.',
                style: const TextStyle(color: AppColors.white70),
              ),
              const SizedBox(height: 16),
              Row(children: [
                HeroStat('Earned today', money(earnedToday)),
                const SizedBox(width: 8),
                HeroStat('Delivered', '${doneToday.length}'),
                const SizedBox(width: 8),
                HeroStat('Active', '${active.length}'),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: openWallet,
              child: StatTile(
                label: 'Wallet balance',
                value: money(walletBalance(wallet)),
                icon: Icons.account_balance_wallet_outlined,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: openWallet,
              child: StatTile(
                label: 'Cash to hand over',
                value: money(cashHeld),
                icon: Icons.payments_outlined,
                color: AppColors.warn,
                soft: AppColors.warnSoft,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        if (Backend.instance.isDemo) ...[
          const DemoBanner('Demo mode: sample data. Delivery codes are written in each job\'s notes.'),
          const SizedBox(height: 12),
        ],
        SectionTitle('Your deliveries (${active.length})', trailing: 'History', onTrailing: openHistory),
        if (active.isEmpty)
          EmptyState(
            icon: profile.online ? Icons.inbox_outlined : Icons.power_settings_new_rounded,
            title: profile.online ? 'No deliveries right now' : 'You are offline',
            body: profile.online
                ? 'New jobs from the office appear here automatically.'
                : 'Switch on at the top to start receiving deliveries.',
          ),
        ...active.map((j) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _JobCard(job: j))),
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  final DeliveryJob job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobScreen(job: job))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(job.code,
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.purple, letterSpacing: .3)),
            const Spacer(),
            StatusPill(job.status),
          ]),
          const SizedBox(height: 12),
          OrderProgress(job.status),
          const SizedBox(height: 14),
          RouteLines(from: job.pickupAddress, to: job.dropoffAddress),
          const SizedBox(height: 12),
          Row(children: [
            Pill(job.hasCod ? 'Collect ${money(job.codAmount)}' : 'Prepaid',
                fg: job.hasCod ? AppColors.warn : AppColors.ok,
                bg: job.hasCod ? AppColors.warnSoft : AppColors.okSoft),
            const Spacer(),
            Text('Earn ${money(job.deliveryFee * 0.8)}',
                style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800)),
          ]),
        ],
      ),
    );
  }
}

// =================================================================== HISTORY
class _HistoryTab extends StatefulWidget {
  final List<DeliveryJob> jobs;
  const _HistoryTab({required this.jobs});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  Period _period = Period.week;

  @override
  Widget build(BuildContext context) {
    final done = widget.jobs.where((j) => j.status == OrderStatus.delivered).toList()
      ..sort((a, b) =>
          (b.deliveredAt?.millisecondsSinceEpoch ?? 0).compareTo(a.deliveredAt?.millisecondsSinceEpoch ?? 0));
    final inPeriod = done.where((j) => _period.contains(j.deliveredAt)).toList();
    final earned = inPeriod.fold<double>(0, (s, j) => s + j.driverEarning);
    final cod = inPeriod.fold<double>(0, (s, j) => s + j.codAmount);
    final avg = inPeriod.isEmpty ? 0.0 : earned / inPeriod.length;
    final series = dailySeries<DeliveryJob>(done, (j) => j.deliveredAt, (j) => j.driverEarning);
    final weekTotal = series.fold<double>(0, (s, v) => s + v);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text('History', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.ink)),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Earnings, last 7 days', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 2),
              Text(money(weekTotal),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.ink)),
              const SizedBox(height: 16),
              BarChart(values: series, labels: dailyLabels(), format: (v) => v.toStringAsFixed(0)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PeriodChips(value: _period, onChanged: (p) => setState(() => _period = p)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.2,
          children: [
            StatTile(label: 'Deliveries', value: '${inPeriod.length}', icon: Icons.local_shipping_outlined),
            StatTile(
                label: 'Earned',
                value: money(earned),
                icon: Icons.trending_up_rounded,
                color: AppColors.ok,
                soft: AppColors.okSoft),
            StatTile(
                label: 'Avg per delivery',
                value: money(avg),
                icon: Icons.speed_rounded,
                color: AppColors.teal,
                soft: AppColors.tealSoft),
            StatTile(
                label: 'COD collected',
                value: money(cod),
                icon: Icons.payments_outlined,
                color: AppColors.warn,
                soft: AppColors.warnSoft),
          ],
        ),
        const SizedBox(height: 8),
        SectionTitle('Completed (${inPeriod.length})'),
        if (inPeriod.isEmpty)
          const EmptyState(
            icon: Icons.history_rounded,
            title: 'Nothing in this period',
            body: 'Completed deliveries will be listed here.',
          ),
        ..._grouped(inPeriod),
      ],
    );
  }

  List<Widget> _grouped(List<DeliveryJob> list) {
    final out = <Widget>[];
    DateTime? current;
    for (final j in list) {
      final d = j.deliveredAt == null ? null : dayOf(j.deliveredAt!);
      if (d != null && (current == null || !sameDay(d, current))) {
        current = d;
        final label = sameDay(d, DateTime.now()) ? 'Today' : '${weekdayShort(d)}, ${shortDate(d)}';
        out.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6, left: 4),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
        ));
      }
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Panel(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.tealSoft, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.check_rounded, color: AppColors.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(j.code, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(j.dropoffAddress,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(money(j.driverEarning, sign: true),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ok)),
                  if (j.hasCod)
                    Text('COD ${money(j.codAmount)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ],
          ),
        ),
      ));
    }
    return out;
  }
}

// =================================================================== WALLET
class _WalletTab extends StatelessWidget {
  final List<WalletTx> txs;
  final List<DeliveryJob> jobs;
  const _WalletTab({required this.txs, required this.jobs});

  @override
  Widget build(BuildContext context) {
    final balance = walletBalance(txs);
    final weekEarn = txs
        .where((t) => t.type == 'earning' && Period.week.contains(t.createdAt))
        .fold<double>(0, (s, t) => s + t.amount);
    final cashHeld = jobs
        .where((j) => j.status == OrderStatus.delivered && j.codCollected && !j.codSettled)
        .fold<double>(0, (s, j) => s + j.codAmount);
    final paidOut = txs.where((t) => t.type == 'payout').fold<double>(0, (s, t) => s - t.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text('Wallet', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.ink)),
        const SizedBox(height: 14),
        HeroCard(
          gradient: tealGradient,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Balance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              Text(money(balance),
                  style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                balance >= 0 ? 'MSI Parcel owes you this amount.' : 'Hand over cash to the office to clear this.',
                style: const TextStyle(color: AppColors.white70),
              ),
              const SizedBox(height: 16),
              Row(children: [
                HeroStat('Earned (7 days)', money(weekEarn)),
                const SizedBox(width: 8),
                HeroStat('Cash with you', money(cashHeld)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            children: [
              InfoRow('Paid out', money(paidOut)),
              const InfoRow('Your share', '80% of each delivery fee'),
              const InfoRow('Payouts', 'Weekly bank transfer'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const SectionTitle('Transactions'),
        if (txs.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No transactions yet',
            body: 'Earnings and cash movements show here after your first delivery.',
          )
        else
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(children: txs.take(60).map((t) => WalletTxTile(t)).toList()),
          ),
      ],
    );
  }
}

// =================================================================== PROFILE
class _ProfileTab extends StatelessWidget {
  final DriverProfile profile;
  const _ProfileTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        HeroCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Text(
                  profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 26, color: AppColors.purple, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(profile.name,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 6),
                  const Pill('Approved driver', fg: AppColors.purple, bg: Colors.white),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          child: Column(children: [
            InfoRow('Mobile', profile.phone),
            InfoRow('City', profile.city),
            InfoRow('Vehicle', profile.vehicleType),
            InfoRow('Plate', profile.plateNumber),
          ]),
        ),
        const SizedBox(height: 12),
        const Panel(
          child: Row(children: [
            Icon(Icons.support_agent_rounded, color: AppColors.purple),
            SizedBox(width: 12),
            Expanded(
              child: Text('Need help? Call the MSI Parcel office: ${AppConfig.supportPhone}',
                  style: TextStyle(color: AppColors.ink)),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            await LocationService.instance.stop();
            await Backend.instance.signOut();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: 12),
        const Center(
            child: Text('MSI Parcel Driver v0.5', style: TextStyle(color: AppColors.muted, fontSize: 12))),
      ],
    );
  }
}
