// MSI Parcel UI kit — shared by the Customer and Driver apps.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ------------------------------------------------------------------ colors
class AppColors {
  static const purple = Color(0xFF4E1A86);
  static const purpleDeep = Color(0xFF2E0B57);
  static const purpleSoft = Color(0xFFEFE7FA);
  static const teal = Color(0xFF0E9C9C);
  static const tealBright = Color(0xFF2FD3C8);
  static const tealSoft = Color(0xFFE0F5F3);
  static const bg = Color(0xFFF6F4FA);
  static const card = Colors.white;
  static const ink = Color(0xFF1D1530);
  static const muted = Color(0xFF6E6683);
  static const line = Color(0xFFE6E1EF);
  static const ok = Color(0xFF16794A);
  static const okSoft = Color(0xFFE1F4EA);
  static const warn = Color(0xFFB86A00);
  static const warnSoft = Color(0xFFFFF1DB);
  static const bad = Color(0xFFB42318);
  static const badSoft = Color(0xFFFDE8E6);
  static const white70 = Color(0xB3FFFFFF);
  static const white20 = Color(0x33FFFFFF);
  static const white12 = Color(0x1FFFFFFF);
  static const shadow = Color(0x142E0B57);
}

const brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.purpleDeep, AppColors.purple, Color(0xFF6A2BA8)],
);

const tealGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0A7F80), AppColors.teal, AppColors.tealBright],
);

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.purple,
      primary: AppColors.purple,
      secondary: AppColors.teal,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.purple, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.purpleSoft,
        elevation: 0,
        height: 68,
      ),
    );
  }
}

// ------------------------------------------------------------------ format
const String kCurrency = 'SAR';

String money(double v, {bool sign = false}) {
  final s = v.abs().toStringAsFixed(2);
  final prefix = sign ? (v > 0 ? '+' : (v < 0 ? '−' : '')) : (v < 0 ? '−' : '');
  return '$prefix$kCurrency $s';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String shortTime(DateTime? t) {
  if (t == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.day} ${_months[t.month - 1]}, ${two(t.hour)}:${two(t.minute)}';
}

String shortDate(DateTime t) => '${t.day} ${_months[t.month - 1]}';
String weekdayShort(DateTime t) => _weekdays[t.weekday - 1];

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ------------------------------------------------------------------ periods
enum Period { today, week, month, all }

extension PeriodX on Period {
  String get label {
    switch (this) {
      case Period.today:
        return 'Today';
      case Period.week:
        return '7 days';
      case Period.month:
        return '30 days';
      case Period.all:
        return 'All';
    }
  }

  bool contains(DateTime? t) {
    if (t == null) return this == Period.all;
    final now = DateTime.now();
    final today = dayOf(now);
    switch (this) {
      case Period.today:
        return !t.isBefore(today);
      case Period.week:
        return !t.isBefore(today.subtract(const Duration(days: 6)));
      case Period.month:
        return !t.isBefore(today.subtract(const Duration(days: 29)));
      case Period.all:
        return true;
    }
  }
}

class PeriodChips extends StatelessWidget {
  final Period value;
  final ValueChanged<Period> onChanged;
  const PeriodChips({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: Period.values.map((p) {
          final sel = p == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: sel ? brandGradient : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  p.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: sel ? Colors.white : AppColors.muted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ------------------------------------------------------------------ helpers
void showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.bad : AppColors.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
}

Future<void> callNumber(BuildContext context, String phone) async {
  final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (cleaned.isEmpty) return;
  final ok = await launchUrl(Uri(scheme: 'tel', path: cleaned));
  if (!ok && context.mounted) showMessage(context, 'Could not open the phone app.');
}

/// Opens Google Maps. With coordinates it starts turn-by-turn directions
/// to the exact pin; otherwise it searches the written address.
Future<void> openMap(BuildContext context, String address, {double? lat, double? lng}) async {
  final hasPin = lat != null && lng != null && (lat != 0 || lng != 0);
  final uri = hasPin
      ? Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': '$lat,$lng',
          'travelmode': 'driving',
        })
      : Uri.https('www.google.com', '/maps/search/', {
          'api': '1',
          'query': address,
        });
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showMessage(context, 'Could not open maps.');
}

// ------------------------------------------------------------------ widgets
class Logo extends StatelessWidget {
  final double width;
  const Logo({super.key, this.width = 220});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/images/msi_parcel_logo.png', width: width);
  }
}

/// White rounded card with a soft shadow.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? AppColors.line),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: box,
    );
  }
}

/// Big brand-colored card used at the top of dashboards.
class HeroCard extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;
  const HeroCard({
    super.key,
    required this.child,
    this.gradient = brandGradient,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(color: Color(0x404E1A86), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -50,
              child: Container(
                width: 170,
                height: 170,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.white12),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -70,
              child: Container(
                width: 130,
                height: 130,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.white12),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final String? trailing;
  final VoidCallback? onTrailing;
  const SectionTitle(this.text, {super.key, this.trailing, this.onTrailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailing,
              child: Text(trailing!,
                  style: const TextStyle(color: AppColors.purple, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color soft;
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.purple,
    this.soft = AppColors.purpleSoft,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// Small white stat shown inside a HeroCard.
class HeroStat extends StatelessWidget {
  final String label;
  final String value;
  const HeroStat(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white12,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.white20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: AppColors.purpleSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 30, color: AppColors.purple),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class DemoBanner extends StatelessWidget {
  final String text;
  const DemoBanner(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warnSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, size: 18, color: AppColors.warn),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.warn, fontSize: 13))),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color fg;
  final Color bg;
  const Pill(this.text, {super.key, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class RouteLines extends StatelessWidget {
  final String from;
  final String to;
  const RouteLines({super.key, required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const SizedBox(height: 4),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.teal, width: 3),
              ),
            ),
            Container(width: 2, height: 22, color: AppColors.line),
            const Icon(Icons.location_on, size: 16, color: AppColors.purple),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(from, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5)),
              const SizedBox(height: 14),
              Text(to,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class ProgressSteps extends StatelessWidget {
  final int step; // 0..5
  final bool failed;
  const ProgressSteps({super.key, required this.step, this.failed = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final on = !failed && i < step;
        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: i == 4 ? 0 : 5),
            decoration: BoxDecoration(
              gradient: on ? tealGradient : null,
              color: on ? null : AppColors.line,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}

/// One bar per day. [values] oldest first, [labels] same length.
class BarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final String Function(double) format;
  final double height;
  const BarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.format,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 0.0 : values.reduce(math.max);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final v = values[i];
          final frac = maxV <= 0 ? 0.0 : v / maxV;
          final last = i == values.length - 1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (v > 0)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(format(v),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: last ? AppColors.purple : AppColors.muted,
                          )),
                    ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: math.max(frac, 0.04),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: last ? brandGradient : tealGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(labels[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: last ? AppColors.ink : AppColors.muted,
                        fontWeight: last ? FontWeight.w800 : FontWeight.w500,
                      )),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Sums [items] per day for the last [days] days (oldest first).
List<double> dailySeries<T>(List<T> items, DateTime? Function(T) when, double Function(T) amount, {int days = 7}) {
  final today = dayOf(DateTime.now());
  final out = List<double>.filled(days, 0);
  for (final it in items) {
    final t = when(it);
    if (t == null) continue;
    final diff = today.difference(dayOf(t)).inDays;
    if (diff >= 0 && diff < days) out[days - 1 - diff] += amount(it);
  }
  return out;
}

List<String> dailyLabels({int days = 7}) {
  final today = dayOf(DateTime.now());
  return List.generate(days, (i) {
    final d = today.subtract(Duration(days: days - 1 - i));
    return i == days - 1 ? 'Today' : weekdayShort(d);
  });
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const InfoRow(this.label, this.value, {super.key, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Expanded(
            child: Text(value,
                style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: AppColors.ink)),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ wallet
class WalletTx {
  final String id;
  final String type;
  final double amount; // + money in, − money out
  final String orderCode;
  final String note;
  final DateTime? createdAt;

  const WalletTx({
    required this.id,
    required this.type,
    required this.amount,
    this.orderCode = '',
    this.note = '',
    this.createdAt,
  });

  factory WalletTx.fromMap(String id, Map<String, dynamic> m, DateTime? Function(dynamic) parseTime) {
    final a = m['amount'];
    return WalletTx(
      id: id,
      type: (m['type'] ?? '').toString(),
      amount: a is num ? a.toDouble() : double.tryParse('${a ?? ''}') ?? 0,
      orderCode: (m['orderCode'] ?? '').toString(),
      note: (m['note'] ?? '').toString(),
      createdAt: parseTime(m['createdAt']),
    );
  }

  String get title {
    switch (type) {
      case 'earning':
        return 'Delivery earning';
      case 'cod_collected':
        return 'Cash collected (to hand over)';
      case 'cod_settled':
        return 'Cash handed to office';
      case 'payout':
        return 'Payout';
      case 'cod_received':
        return 'Cash on delivery received';
      case 'delivery_fee':
        return 'Delivery fee';
      case 'topup':
        return 'Wallet top-up';
      case 'withdrawal':
        return 'Withdrawal';
      case 'bonus':
        return 'Bonus';
      default:
        return note.isNotEmpty ? note : type;
    }
  }

  IconData get icon {
    switch (type) {
      case 'earning':
      case 'bonus':
        return Icons.trending_up_rounded;
      case 'cod_collected':
        return Icons.payments_outlined;
      case 'cod_settled':
        return Icons.account_balance_outlined;
      case 'cod_received':
        return Icons.savings_outlined;
      case 'delivery_fee':
        return Icons.local_shipping_outlined;
      case 'topup':
        return Icons.add_card_outlined;
      case 'withdrawal':
      case 'payout':
        return Icons.north_east_rounded;
      default:
        return Icons.receipt_long_outlined;
    }
  }
}

double walletBalance(List<WalletTx> txs) => txs.fold<double>(0, (s, t) => s + t.amount);

class WalletTxTile extends StatelessWidget {
  final WalletTx tx;
  const WalletTxTile(this.tx, {super.key});

  @override
  Widget build(BuildContext context) {
    final inflow = tx.amount >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: inflow ? AppColors.okSoft : AppColors.warnSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(tx.icon, color: inflow ? AppColors.ok : AppColors.warn, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(
                  [if (tx.orderCode.isNotEmpty) tx.orderCode, shortTime(tx.createdAt)].join(' · '),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Text(
            money(tx.amount, sign: true),
            style: TextStyle(fontWeight: FontWeight.w800, color: inflow ? AppColors.ok : AppColors.warn),
          ),
        ],
      ),
    );
  }
}
