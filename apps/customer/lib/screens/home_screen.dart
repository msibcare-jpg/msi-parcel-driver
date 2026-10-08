import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../core/order_status.dart';
import '../models/models.dart';
import '../services/backend.dart';
import '../ui/kit.dart';
import '../widgets/order_widgets.dart';
import 'new_order_screen.dart';
import 'order_screen.dart';

class HomeScreen extends StatefulWidget {
  final CustomerProfile profile;
  const HomeScreen({super.key, required this.profile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Stream<List<ParcelOrder>> _orders;
  late final Stream<List<WalletTx>> _wallet;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _orders = Backend.instance.watchMyOrders(widget.profile.uid);
    _wallet = Backend.instance.watchWallet(widget.profile.uid);
  }

  void _newOrder() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewOrderScreen(profile: widget.profile)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<ParcelOrder>>(
          stream: _orders,
          builder: (context, oSnap) {
            return StreamBuilder<List<WalletTx>>(
              stream: _wallet,
              builder: (context, wSnap) {
                if (oSnap.hasError) {
                  return Center(child: Text('Could not load your orders.\n${oSnap.error}', textAlign: TextAlign.center));
                }
                if (!oSnap.hasData) return const Center(child: CircularProgressIndicator());
                final orders = oSnap.data!;
                final wallet = wSnap.data ?? const <WalletTx>[];
                switch (_tab) {
                  case 1:
                    return _OrdersTab(orders: orders);
                  case 2:
                    return _WalletTab(txs: wallet);
                  case 3:
                    return _ProfileTab(profile: widget.profile);
                  default:
                    return _HomeTab(
                      profile: widget.profile,
                      orders: orders,
                      wallet: wallet,
                      onNewOrder: _newOrder,
                      openOrders: () => setState(() => _tab = 1),
                      openWallet: () => setState(() => _tab = 2),
                    );
                }
              },
            );
          },
        ),
      ),
      floatingActionButton: _tab == 0 || _tab == 1
          ? FloatingActionButton.extended(
              onPressed: _newOrder,
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Send parcel', style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Orders'),
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

// =================================================================== HOME
class _HomeTab extends StatelessWidget {
  final CustomerProfile profile;
  final List<ParcelOrder> orders;
  final List<WalletTx> wallet;
  final VoidCallback onNewOrder;
  final VoidCallback openOrders;
  final VoidCallback openWallet;

  const _HomeTab({
    required this.profile,
    required this.orders,
    required this.wallet,
    required this.onNewOrder,
    required this.openOrders,
    required this.openWallet,
  });

  @override
  Widget build(BuildContext context) {
    final active = orders.where((o) => o.isActive).toList();
    final monthDelivered = orders.where((o) => o.status == OrderStatus.delivered && Period.month.contains(o.deliveredAt)).length;
    final recent = orders.where((o) => !o.isActive).take(3).toList();
    final first = profile.name.split(' ').first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greeting(), style: const TextStyle(color: AppColors.muted)),
              Text(first, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink)),
            ]),
          ),
          const Logo(width: 84),
        ]),
        const SizedBox(height: 14),
        HeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Where are we delivering today?',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.2)),
              const SizedBox(height: 6),
              const Text('Same-day pickup across the city. Track every step live.',
                  style: TextStyle(color: AppColors.white70)),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.purple),
                  onPressed: onNewOrder,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send a parcel'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: openOrders,
              child: StatTile(label: 'On the way', value: '${active.length}', icon: Icons.local_shipping_outlined),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: openOrders,
              child: StatTile(
                label: 'Delivered (30d)',
                value: '$monthDelivered',
                icon: Icons.verified_outlined,
                color: AppColors.teal,
                soft: AppColors.tealSoft,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: openWallet,
              child: StatTile(
                label: 'Wallet',
                value: money(walletBalance(wallet)),
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.ok,
                soft: AppColors.okSoft,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        if (Backend.instance.isDemo) ...[
          const DemoBanner('Demo mode: new orders move forward by themselves every few seconds.'),
          const SizedBox(height: 12),
        ],
        SectionTitle('Active deliveries', trailing: active.isEmpty ? null : 'See all', onTrailing: openOrders),
        if (active.isEmpty)
          EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No parcels on the way',
            body: 'Book a pickup and follow your parcel here.',
            action: OutlinedButton(onPressed: onNewOrder, child: const Text('Send a parcel')),
          ),
        ...active.map((o) => Padding(padding: const EdgeInsets.only(bottom: 12), child: OrderCard(order: o))),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 6),
          SectionTitle('Recent', trailing: 'History', onTrailing: openOrders),
          ...recent.map((o) => Padding(padding: const EdgeInsets.only(bottom: 10), child: OrderRow(order: o))),
        ],
      ],
    );
  }
}

class OrderCard extends StatelessWidget {
  final ParcelOrder order;
  const OrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Panel(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderScreen(order: o))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(o.code, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.purple, letterSpacing: .3)),
            const Spacer(),
            StatusPill(o.status),
          ]),
          const SizedBox(height: 12),
          OrderProgress(o.status),
          const SizedBox(height: 14),
          RouteLines(from: o.pickupAddress, to: o.dropoffAddress),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.person_outline, size: 16, color: AppColors.muted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(o.receiverName,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted)),
            ),
            Text(money(o.deliveryFee), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ]),
        ],
      ),
    );
  }
}

class OrderRow extends StatelessWidget {
  final ParcelOrder order;
  const OrderRow({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final o = order;
    final cancelled = o.status == OrderStatus.cancelled;
    return Panel(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderScreen(order: o))),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: cancelled ? AppColors.badSoft : (o.isActive ? AppColors.purpleSoft : AppColors.tealSoft),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            cancelled ? Icons.close_rounded : (o.isActive ? Icons.local_shipping_outlined : Icons.check_rounded),
            color: cancelled ? AppColors.bad : (o.isActive ? AppColors.purple : AppColors.teal),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${o.receiverName} · ${o.code}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(o.dropoffAddress,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(money(o.deliveryFee), style: const TextStyle(fontWeight: FontWeight.w800)),
          if (o.hasCod) Text('COD ${money(o.codAmount)}', style: const TextStyle(fontSize: 12, color: AppColors.ok)),
        ]),
      ]),
    );
  }
}

// =================================================================== ORDERS / HISTORY
class _OrdersTab extends StatefulWidget {
  final List<ParcelOrder> orders;
  const _OrdersTab({required this.orders});

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  Period _period = Period.month;

  @override
  Widget build(BuildContext context) {
    final all = widget.orders;
    final inPeriod = all.where((o) => _period.contains(o.createdAt)).toList();
    final delivered = inPeriod.where((o) => o.status == OrderStatus.delivered).toList();
    final spent = delivered.fold<double>(0, (s, o) => s + o.deliveryFee);
    final cod = delivered.fold<double>(0, (s, o) => s + o.codAmount);
    final series = dailySeries<ParcelOrder>(
      all.where((o) => o.status != OrderStatus.cancelled).toList(),
      (o) => o.createdAt,
      (o) => 1,
    );
    final weekCount = series.fold<double>(0, (s, v) => s + v).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        const Text('Orders', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.ink)),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Parcels sent, last 7 days', style: TextStyle(color: AppColors.muted)),
              Text('$weekCount', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.ink)),
              const SizedBox(height: 14),
              BarChart(values: series, labels: dailyLabels(), format: (v) => v.toStringAsFixed(0), height: 130),
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
            StatTile(label: 'Orders', value: '${inPeriod.length}', icon: Icons.receipt_long_outlined),
            StatTile(
                label: 'Delivered',
                value: '${delivered.length}',
                icon: Icons.verified_outlined,
                color: AppColors.teal,
                soft: AppColors.tealSoft),
            StatTile(
                label: 'Delivery fees',
                value: money(spent),
                icon: Icons.local_shipping_outlined,
                color: AppColors.warn,
                soft: AppColors.warnSoft),
            StatTile(
                label: 'COD collected for you',
                value: money(cod),
                icon: Icons.savings_outlined,
                color: AppColors.ok,
                soft: AppColors.okSoft),
          ],
        ),
        const SizedBox(height: 8),
        SectionTitle('All orders (${inPeriod.length})'),
        if (inPeriod.isEmpty)
          const EmptyState(icon: Icons.history_rounded, title: 'No orders in this period', body: 'Your parcels will be listed here.'),
        ..._grouped(inPeriod),
      ],
    );
  }

  List<Widget> _grouped(List<ParcelOrder> list) {
    final out = <Widget>[];
    DateTime? current;
    for (final o in list) {
      final d = o.createdAt == null ? null : dayOf(o.createdAt!);
      if (d != null && (current == null || !sameDay(d, current))) {
        current = d;
        final label = sameDay(d, DateTime.now()) ? 'Today' : '${weekdayShort(d)}, ${shortDate(d)}';
        out.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6, left: 4),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
        ));
      }
      out.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: OrderRow(order: o)));
    }
    return out;
  }
}

// =================================================================== WALLET
class _WalletTab extends StatelessWidget {
  final List<WalletTx> txs;
  const _WalletTab({required this.txs});

  Future<void> _withdraw(BuildContext context, double balance) async {
    final ctrl = TextEditingController(text: balance > 0 ? balance.toStringAsFixed(0) : '');
    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Withdraw to bank', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Available: ${money(balance)}', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '$kCurrency  '),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text.trim()) ?? 0),
              child: const Text('Request withdrawal'),
            ),
          ],
        ),
      ),
    );
    if (amount == null || !context.mounted) return;
    try {
      await Backend.instance.requestWithdrawal(amount);
      if (context.mounted) showMessage(context, 'Request sent. The office will transfer ${money(amount)}.');
    } catch (e) {
      if (context.mounted) showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = walletBalance(txs);
    final codIn = txs.where((t) => t.type == 'cod_received' && Period.month.contains(t.createdAt)).fold<double>(0, (s, t) => s + t.amount);
    final fees = txs.where((t) => t.type == 'delivery_fee' && Period.month.contains(t.createdAt)).fold<double>(0, (s, t) => s - t.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
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
                Text('MSI Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              Text(money(balance), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                balance >= 0 ? 'Cash collected for you, after delivery fees.' : 'Delivery fees due. Top up to clear.',
                style: const TextStyle(color: AppColors.white70),
              ),
              const SizedBox(height: 16),
              Row(children: [
                HeroStat('COD in (30d)', money(codIn)),
                const SizedBox(width: 8),
                HeroStat('Fees (30d)', money(fees)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => showMessage(context, 'Top up with Mada and Apple Pay is coming soon.'),
              icon: const Icon(Icons.add_card_outlined),
              label: const Text('Top up'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: balance > 0 ? () => _withdraw(context, balance) : null,
              icon: const Icon(Icons.north_east_rounded),
              label: const Text('Withdraw'),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        const SectionTitle('Transactions'),
        if (txs.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No transactions yet',
            body: 'Cash collected for you and delivery fees appear here.',
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
  final CustomerProfile profile;
  const _ProfileTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        HeroCard(
          child: Row(children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              child: Text(profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 26, color: AppColors.purple, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(profile.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                Text(profile.phone, style: const TextStyle(color: AppColors.white70)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        const Panel(
          child: Column(children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.support_agent_rounded, color: AppColors.purple),
              title: Text('Help & support'),
              subtitle: Text(AppConfig.supportPhone),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.shield_outlined, color: AppColors.purple),
              title: Text('Safe delivery'),
              subtitle: Text('Every parcel is handed over only with your delivery code.'),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => Backend.instance.signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: 12),
        const Center(child: Text('MSI Parcel v0.1 · ${AppConfig.tagline}', style: TextStyle(color: AppColors.muted, fontSize: 12))),
      ],
    );
  }
}
