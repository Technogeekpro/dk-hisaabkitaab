import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_store.dart';
import 'data.dart';
import 'forms.dart';
import 'sales_heatmap.dart';
import 'settings.dart';
import 'sign_in.dart';
import 'theme.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(systemUiStyle);
  await appSettings.load();
  if (cloudConfigured) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  }
  runApp(const DkMobilesApp());
}

class DkMobilesApp extends StatelessWidget {
  const DkMobilesApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'D.K. Mobiles Profit',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: const AuthGate(),
  );
}

/// Keeps every app screen behind the current Supabase session.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  Session? _session;

  @override
  void initState() {
    super.initState();
    if (cloudConfigured) {
      final auth = Supabase.instance.client.auth;
      _session = auth.currentSession;
      _authSubscription = auth.onAuthStateChange.listen(
        (state) {
          if (mounted) setState(() => _session = state.session);
        },
        onError: (Object error, StackTrace stackTrace) {
          // A temporary refresh/network error does not itself sign the user out.
        },
      );
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!cloudConfigured) return const HomePage();
    final user = _session?.user;
    if (user == null) return const SignInPage();
    return HomePage(key: ValueKey(user.id));
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Product> _products = [];
  final List<Sale> _sales = [];
  final List<Expense> _expenses = [];
  final List<Payment> _payments = [];
  final List<StaffPayout> _staffPayouts = [];

  /// Dues tab view: 0 partner, 1 staff.
  int _duesView = 0;

  /// 0 Overview, 1 Sales, 2 Dues, 3 Profile, 4 Products (opened from Profile).
  int _tab = 0;
  ProfitPeriod _period = appSettings.defaultPeriod;
  DateTimeRange? _salesRange;
  bool _loading = true;
  String? _loadError;

  CloudStore get _cloud => CloudStore(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onSettingsChanged);
    _load();
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _haptic() {
    if (appSettings.haptics) HapticFeedback.selectionClick();
  }

  void _goTo(int tab) {
    _haptic();
    setState(() => _tab = tab);
  }

  // ---------------------------------------------------------------- data

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final data = cloudConfigured
          ? await (() async {
              await _cloud.importLocalData();
              return _cloud.load();
            })()
          : await LocalStore.load();
      _products
        ..clear()
        ..addAll(data.products);
      _sales
        ..clear()
        ..addAll(data.sales);
      _expenses
        ..clear()
        ..addAll(data.expenses);
      _payments
        ..clear()
        ..addAll(data.payments);
      _staffPayouts
        ..clear()
        ..addAll(data.staffPayouts);
    } catch (_) {
      if (silent) {
        _showMessage('Could not refresh. Check your connection.');
      } else {
        _loadError = cloudConfigured
            ? 'Could not load your cloud data. Check your connection and try again.'
            : 'Could not load saved data.';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _save() {
    if (!cloudConfigured) {
      LocalStore.save(_products, _sales, _expenses, _payments, _staffPayouts);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _cloudWrite(Future<void> Function(CloudStore) action) async {
    if (!cloudConfigured) return true;
    try {
      await action(_cloud);
      return true;
    } catch (_) {
      _showMessage('Could not save. Check your connection and try again.');
      return false;
    }
  }

  Future<bool> _confirmAndDelete(String type, String table, String id) async {
    if (!await _confirmDelete(type)) return false;
    return _cloudWrite((store) => store.delete(table, id));
  }

  ProfitSummary get _lifetimeSummary =>
      ProfitSummary(sales: _sales, expenses: _expenses, payments: _payments);

  Future<void> _showProductForm({Product? product}) async {
    final result = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ProductForm(product: product),
    );
    if (result == null) return;
    if (!await _cloudWrite((store) => store.saveProduct(result))) return;
    if (!mounted) return;
    setState(() {
      if (product == null) {
        _products.add(result);
      } else {
        final index = _products.indexWhere((item) => item.id == product.id);
        if (index >= 0) _products[index] = result;
      }
    });
    _save();
  }

  Future<void> _showSaleForm() async {
    _haptic();
    if (_products.isEmpty) {
      await _showProductForm();
      return;
    }
    final sale = await showModalBottomSheet<Sale>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SaleForm(products: _products),
    );
    if (sale == null) return;
    if (!await _cloudWrite((store) => store.saveSale(sale))) return;
    if (!mounted) return;
    setState(() {
      _sales.insert(0, sale);
      _sales.sort((a, b) => b.date.compareTo(a.date));
      if (salesDay(sale.date) == salesDay(DateTime.now())) {
        _salesRange = null;
        _tab = 0;
      } else {
        _salesRange = _dayRange(sale.date);
        _tab = 1;
      }
    });
    _save();
    _showMessage('Sale saved');
  }

  void _deleteSale(Sale sale) {
    setState(() => _sales.removeWhere((item) => item.id == sale.id));
    _save();
    _showMessage('Sale deleted');
  }

  Future<void> _showExpenseForm() async {
    final expense = await showModalBottomSheet<Expense>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ExpenseForm(),
    );
    if (expense == null) return;
    if (!await _cloudWrite((store) => store.saveExpense(expense))) return;
    if (!mounted) return;
    setState(() {
      _expenses.add(expense);
      _expenses.sort((a, b) => b.date.compareTo(a.date));
    });
    _save();
  }

  Future<void> _showPaymentForm() async {
    final payment = await showModalBottomSheet<Payment>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PaymentForm(partnerName: appSettings.partnerName),
    );
    if (payment == null) return;
    if (!await _cloudWrite((store) => store.savePayment(payment))) return;
    if (!mounted) return;
    setState(() {
      _payments.add(payment);
      _payments.sort((a, b) => b.date.compareTo(a.date));
    });
    _save();
  }

  void _deleteExpense(Expense expense) {
    setState(() => _expenses.removeWhere((item) => item.id == expense.id));
    _save();
  }

  Future<void> _showStaffPayoutForm(String employee, double owed) async {
    final payout = await showModalBottomSheet<StaffPayout>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          StaffPayoutForm(employee: employee, suggestedAmount: owed),
    );
    if (payout == null) return;
    if (!await _cloudWrite((store) => store.saveStaffPayout(payout))) return;
    if (!mounted) return;
    setState(() {
      _staffPayouts.add(payout);
      _staffPayouts.sort((a, b) => b.date.compareTo(a.date));
    });
    _save();
    _showMessage('Paid ${payout.employee} ${money(payout.amount)}');
  }

  void _deleteStaffPayout(StaffPayout payout) {
    setState(() => _staffPayouts.removeWhere((item) => item.id == payout.id));
    _save();
  }

  void _deletePayment(Payment payment) {
    setState(() => _payments.removeWhere((item) => item.id == payment.id));
    _save();
  }

  Future<bool> _confirmDelete(String type) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete this $type?'),
          content: const Text('Your totals will be updated.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.negative),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    setState(() {
      _loadError = null;
      _products.clear();
      _sales.clear();
      _expenses.clear();
      _payments.clear();
      _staffPayouts.clear();
      _tab = 0;
    });
  }

  // ------------------------------------------------------------- helpers

  DateTimeRange _dayRange(DateTime day) =>
      DateTimeRange(start: salesDay(day), end: salesDay(day));

  bool _isSingleDay(DateTimeRange? range) =>
      range != null && range.start == range.end;

  bool _inPeriod(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    return switch (_period) {
      ProfitPeriod.today => !date.isBefore(today),
      ProfitPeriod.week => !date.isBefore(startOfWeek),
      ProfitPeriod.month => date.year == now.year && date.month == now.month,
      ProfitPeriod.lifetime || ProfitPeriod.average => true,
    };
  }

  List<Sale> get _filteredSales =>
      _sales.where((sale) => _inPeriod(sale.date)).toList();

  List<Expense> get _filteredExpenses =>
      _expenses.where((expense) => _inPeriod(expense.date)).toList();

  String? get _email =>
      cloudConfigured ? Supabase.instance.client.auth.currentUser?.email : null;

  String get _initial {
    final source = appSettings.ownerName.isNotEmpty
        ? appSettings.ownerName
        : (_email ?? 'D');
    return source.trim().isEmpty
        ? 'D'
        : source.trim().characters.first.toUpperCase();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    final part = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final name = appSettings.ownerName.split(' ').first;
    return name.isEmpty ? part : '$part, $name';
  }

  String _dayLabel(DateTime day) {
    final today = salesDay(DateTime.now());
    final formatted = DateFormat('EEE, d MMM yyyy').format(day);
    if (day == today) return 'Today · $formatted';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday · $formatted';
    }
    return formatted;
  }

  /// Space so the last item scrolls clear of the bottom bar and the docked
  /// add button.
  double get _listBottom => MediaQuery.paddingOf(context).bottom + 40;

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    if (_loadError != null) return _buildLoadError();

    final firstRun = _products.isEmpty;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyle,
      child: Scaffold(
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: firstRun
                  ? _buildWelcome()
                  : IndexedStack(
                      index: _tab,
                      children: [
                        _buildOverview(),
                        _buildSales(),
                        _buildDues(),
                        _buildProfile(),
                        _buildProducts(),
                      ],
                    ),
            ),
          ),
        ),
        bottomNavigationBar: firstRun ? null : _bottomBar(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: firstRun
            ? null
            : FloatingActionButton(
                tooltip: 'Add sale',
                onPressed: _showSaleForm,
                child: const Icon(Icons.add_rounded, size: 30),
              ),
      ),
    );
  }

  Widget _buildLoadError() => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LeadingBadge(icon: Icons.cloud_off_outlined),
              const SizedBox(height: 16),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _load, child: const Text('Try again')),
              if (cloudConfigured) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: _signOut, child: const Text('Sign out')),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _bottomBar() => BottomAppBar(
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    shadowColor: const Color(0x29000000),
    elevation: 8,
    shape: const CircularNotchedRectangle(),
    notchMargin: 7,
    height: 64,
    padding: EdgeInsets.zero,
    child: Row(
      children: [
        _navItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Overview'),
        _navItem(1, Icons.receipt_long_outlined, Icons.receipt_long, 'Sales'),
        const SizedBox(width: 80),
        _navItem(
          2,
          Icons.account_balance_wallet_outlined,
          Icons.account_balance_wallet,
          'Dues',
        ),
        _navItem(
          3,
          Icons.person_outline_rounded,
          Icons.person_rounded,
          'Profile',
        ),
      ],
    ),
  );

  Widget _navItem(
    int index,
    IconData icon,
    IconData selectedIcon,
    String label,
  ) {
    final selected = (_tab == 4 ? 3 : _tab) == index;
    final color = selected ? AppColors.text : AppColors.textFaint;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: () => _goTo(index),
          radius: 32,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(selected ? selectedIcon : icon, color: color, size: 24),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- welcome

  Widget _buildWelcome() => ListView(
    padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.text,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.phone_iphone_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
      const SizedBox(height: 28),
      const Text('D.K. Mobiles', style: AppText.pageTitle),
      const SizedBox(height: 6),
      Text(
        'Your daily sales and profit, made simple.',
        style: AppText.label.copyWith(fontSize: 15),
      ),
      const SizedBox(height: 32),
      const AppCard(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start with your first product', style: AppText.sectionTitle),
            SizedBox(height: 6),
            Text(
              'Enter the skin or wrap name, buying price and usual selling price. You can add more products any time.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _showProductForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add first product'),
      ),
      if (cloudConfigured) ...[
        const SizedBox(height: 24),
        Text(
          'Signed in as ${_email ?? 'cloud account'}',
          textAlign: TextAlign.center,
          style: AppText.caption,
        ),
        TextButton(onPressed: _signOut, child: const Text('Sign out')),
      ],
    ],
  );

  // ------------------------------------------------------------ overview

  Widget _buildOverview() {
    final sales = _filteredSales;
    final expenses = _filteredExpenses;
    final summary = ProfitSummary(
      sales: sales,
      expenses: expenses,
      payments: const [],
    );
    final activeDays = <DateTime>{
      ..._sales.map((sale) => salesDay(sale.date)),
      ..._expenses.map((expense) => salesDay(expense.date)),
    }.length;
    final divisor = _period == ProfitPeriod.average && activeDays > 0
        ? activeDays
        : 1;
    final myProfit = summary.partnerShare / divisor;
    final due = _lifetimeSummary.due;
    final recentEntries = <Object>[...sales, ...expenses]
      ..sort((a, b) => _entryDate(b).compareTo(_entryDate(a)));

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            sliver: SliverToBoxAdapter(
              child: PageHeader(
                title: 'Profit overview',
                subtitle: _greeting,
                trailing: _avatarButton(),
              ),
            ),
          ),
          SliverAppBar(
            pinned: true,
            primary: false,
            automaticallyImplyLeading: false,
            toolbarHeight: 60,
            titleSpacing: 0,
            title: _periodSelector(),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, _listBottom),
            sliver: SliverList.list(
              children: [
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _period == ProfitPeriod.average
                                  ? 'My profit per active day'
                                  : 'My profit',
                              style: AppText.label.copyWith(fontSize: 14),
                            ),
                          ),
                          const Pill('50% share'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          money(myProfit),
                          key: const Key('my-profit-amount'),
                          style: AppText.display.copyWith(
                            color: myProfit < 0 ? AppColors.negative : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(_periodCaption(activeDays), style: AppText.caption),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: MetricBlock(
                              key: const Key('net-profit-amount'),
                              label: 'Net profit',
                              value: money(summary.netProfit / divisor),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MetricBlock(
                              label: '${appSettings.partnerName}’s share',
                              value: money(summary.partnerShare / divisor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _breakdownRow('Sales', money(summary.revenue / divisor)),
                      const Divider(),
                      _breakdownRow(
                        'Staff incentives',
                        _minus(summary.staffIncentives / divisor),
                      ),
                      const Divider(),
                      _breakdownRow(
                        'Buying cost',
                        _minus(summary.buyingCost / divisor),
                      ),
                      const Divider(),
                      _breakdownRow(
                        'Other expenses',
                        _minus(summary.otherExpenses / divisor),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                  child: Text(
                    '${sales.length} sale${sales.length == 1 ? '' : 's'} · ${expenses.length} expense${expenses.length == 1 ? '' : 's'} · Your profit is half of net profit.',
                    style: AppText.caption,
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  onTap: () => _goTo(2),
                  child: Row(
                    children: [
                      const LeadingBadge(icon: Icons.savings_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              due < -0.005 ? 'Paid ahead' : 'Amount due to you',
                              style: AppText.label,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              money(due.abs()),
                              style: AppText.amount.copyWith(fontSize: 17),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textFaint,
                      ),
                    ],
                  ),
                ),
                SectionHeader(
                  title: 'Recent activity',
                  trailing: TextButton(
                    onPressed: () => _goTo(1),
                    child: const Text('View all'),
                  ),
                ),
                if (recentEntries.isEmpty)
                  const EmptyState(
                    title: 'No activity in this period',
                    subtitle: 'Add a sale or expense to see it here.',
                  )
                else
                  GroupedList(
                    indent: 16,
                    children: [
                      for (final entry in recentEntries.take(5))
                        entry is Sale
                            ? _saleRow(entry)
                            : _expenseRow(entry as Expense),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _periodCaption(int activeDays) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    return switch (_period) {
      ProfitPeriod.today => DateFormat('EEEE, d MMMM').format(today),
      ProfitPeriod.week =>
        '${DateFormat('d MMM').format(weekStart)} – ${DateFormat('d MMM').format(today)}',
      ProfitPeriod.month => DateFormat('MMMM yyyy').format(today),
      ProfitPeriod.lifetime => 'All time',
      ProfitPeriod.average =>
        'Across $activeDays active day${activeDays == 1 ? '' : 's'}',
    };
  }

  Widget _periodSelector() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        for (final period in ProfitPeriod.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _periodPill(period),
          ),
      ],
    ),
  );

  Widget _periodPill(ProfitPeriod period) {
    final selected = _period == period;
    final shape = StadiumBorder(
      side: BorderSide(color: selected ? AppColors.text : AppColors.border),
    );
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.text : Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: () {
            _haptic();
            setState(() => _period = period);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text(
              period.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarButton() => Semantics(
    button: true,
    label: 'Open profile',
    child: InkResponse(
      onTap: () => _goTo(3),
      radius: 24,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          _initial,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    ),
  );

  String _minus(double value) =>
      value.abs() < 0.005 ? money(0) : '−${money(value)}';

  Widget _breakdownRow(String label, String value) => SizedBox(
    height: 50,
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: AppText.label.copyWith(fontSize: 14)),
        ),
        Text(value, style: AppText.amount),
      ],
    ),
  );

  // --------------------------------------------------------------- sales

  Widget _buildSales() {
    final now = DateTime.now();
    bool thisMonth(DateTime date) =>
        date.year == now.year && date.month == now.month;
    final monthSales = _sales.where((sale) => thisMonth(sale.date)).toList();
    final monthSummary = ProfitSummary(
      sales: monthSales,
      expenses: _expenses.where((e) => thisMonth(e.date)).toList(),
      payments: const [],
    );
    final monthUnits = monthSales.fold<int>(
      0,
      (sum, sale) => sum + sale.quantity,
    );
    final daily = summarizeSalesByDay(_sales);
    final monthDaily = summarizeSalesByDay(monthSales);
    final bestDay = monthDaily.entries.isEmpty
        ? null
        : monthDaily.entries.reduce(
            (best, entry) =>
                entry.value.revenue > best.value.revenue ? entry : best,
          );
    final groupedSales = <DateTime, List<Sale>>{};
    for (final sale in _sales) {
      groupedSales.putIfAbsent(salesDay(sale.date), () => []).add(sale);
    }
    final range = _salesRange;
    final visibleDays =
        daily.keys
            .where((day) => range == null || dayInRange(day, range))
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final historyTitle = range == null
        ? 'Sales history'
        : _isSingleDay(range)
        ? 'Sales on ${DateFormat('d MMM yyyy').format(range.start)}'
        : 'Sales ${DateFormat('d MMM').format(range.start)} – ${DateFormat('d MMM').format(range.end)}';

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 16, 20, _listBottom),
        children: [
          const PageHeader(
            title: 'Sales & expenses',
            subtitle: 'Patterns, history and daily costs',
          ),
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('This month', style: AppText.label),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(now),
                      style: AppText.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: MetricBlock(
                        label: 'Revenue',
                        value: money(monthSummary.revenue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricBlock(
                        label: 'My profit',
                        value: money(monthSummary.partnerShare),
                        valueColor: AppColors.positive,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: MetricBlock(
                        label: 'Sales',
                        value: '${monthSales.length}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricBlock(
                        label: 'Items sold',
                        value: '$monthUnits',
                      ),
                    ),
                  ],
                ),
                if (bestDay != null) ...[
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Best day ${DateFormat('d MMM').format(bestDay.key)} · ${money(bestDay.value.revenue)} in sales',
                          style: AppText.caption,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SalesHeatmap(
            sales: _sales,
            expenses: _expenses,
            selectedRange: _salesRange,
            onDaySelected: (day) => setState(() {
              final tapped = _dayRange(day);
              _salesRange = _salesRange == tapped ? null : tapped;
            }),
            onRangeSelected: (range) => setState(() => _salesRange = range),
          ),
          SectionHeader(
            title: historyTitle,
            trailing: range == null
                ? null
                : TextButton(
                    onPressed: () => setState(() => _salesRange = null),
                    child: const Text('Show all'),
                  ),
          ),
          if (visibleDays.isEmpty)
            EmptyState(
              title: _sales.isEmpty
                  ? 'No sales yet'
                  : _isSingleDay(range)
                  ? 'No sales on this day'
                  : 'No sales in these days',
              subtitle: _sales.isEmpty
                  ? 'Tap + to record your first sale.'
                  : 'Choose another day or show all sales.',
            )
          else
            for (final day in visibleDays) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dayLabel(day),
                        style: AppText.label.copyWith(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${daily[day]!.transactions} sale${daily[day]!.transactions == 1 ? '' : 's'} · ${money(daily[day]!.revenue)}',
                      style: AppText.caption.copyWith(
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              GroupedList(
                indent: 16,
                children: [
                  for (final sale in groupedSales[day]!)
                    Dismissible(
                      key: ValueKey(sale.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) =>
                          _confirmAndDelete('sale', 'dk_sales', sale.id),
                      onDismissed: (_) => _deleteSale(sale),
                      background: const DeleteBackground(),
                      child: _saleRow(sale, showDate: false),
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          SectionHeader(
            title: 'Other expenses',
            trailing: TextButton.icon(
              onPressed: _showExpenseForm,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add expense'),
            ),
          ),
          if (_expenses.isEmpty)
            const EmptyState(
              icon: Icons.receipt_outlined,
              title: 'No expenses yet',
              subtitle: 'Record costs like packing or tools with a short note.',
            )
          else
            GroupedList(
              indent: 16,
              children: [
                for (final expense in _expenses)
                  Dismissible(
                    key: ValueKey(expense.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) =>
                        _confirmAndDelete('expense', 'dk_expenses', expense.id),
                    onDismissed: (_) => _deleteExpense(expense),
                    background: const DeleteBackground(),
                    child: _expenseRow(expense),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          const Text(
            'Swipe left on a sale or expense to delete it.',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- dues

  Widget _buildDues() {
    final partner = appSettings.partnerName;
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 16, 20, _listBottom),
        children: [
          PageHeader(
            title: 'Dues',
            subtitle: _duesView == 0
                ? 'Track what $partner has paid you'
                : 'Staff incentives and payouts',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 0, label: Text(partner)),
                const ButtonSegment(value: 1, label: Text('Staff')),
              ],
              selected: {_duesView},
              onSelectionChanged: (selection) {
                _haptic();
                setState(() => _duesView = selection.first);
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_duesView == 0) ..._partnerDues() else ..._staffDues(),
        ],
      ),
    );
  }

  List<Widget> _partnerDues() {
    final summary = _lifetimeSummary;
    final due = summary.due;
    final cleared = _payments.isNotEmpty && due <= 0.005;
    final partner = appSettings.partnerName;
    return [
      AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    due < -0.005 ? 'Paid ahead' : 'Amount due to you',
                    style: AppText.label.copyWith(fontSize: 14),
                  ),
                ),
                if (cleared) const Pill('Cleared'),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(money(due.abs()), style: AppText.display),
            ),
            const SizedBox(height: 6),
            Text(
              cleared
                  ? 'Cleared on ${DateFormat('d MMM yyyy').format(_payments.first.date)}${due < -0.005 ? ' · Extra counts toward future profit.' : ''}'
                  : 'Your earned share minus payments received.',
              style: AppText.caption,
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: MetricBlock(
                    label: 'Your 50% share',
                    value: money(summary.partnerShare),
                    valueColor: AppColors.positive,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricBlock(
                    label: 'Received',
                    value: money(summary.received),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _showPaymentForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Record cash or UPI payment'),
      ),
      const SectionHeader(title: 'Payment history'),
      if (_payments.isEmpty)
        EmptyState(
          icon: Icons.payments_outlined,
          title: 'No payments yet',
          subtitle: 'Record the date and amount whenever $partner pays you.',
        )
      else
        GroupedList(
          children: [
            for (final payment in _payments)
              Dismissible(
                key: ValueKey(payment.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) =>
                    _confirmAndDelete('payment', 'dk_payments', payment.id),
                onDismissed: (_) => _deletePayment(payment),
                background: const DeleteBackground(),
                child: _paymentRow(payment),
              ),
          ],
        ),
    ];
  }

  List<Widget> _staffDues() {
    final now = DateTime.now();
    final monthSales = _sales
        .where(
          (sale) => sale.date.year == now.year && sale.date.month == now.month,
        )
        .toList();
    final lifetime = [
      for (final name in staffMembers)
        StaffSummary(name, _sales, _staffPayouts),
    ];
    final month = {
      for (final name in staffMembers)
        name: StaffSummary(name, monthSales, const []),
    };
    final totalOwed = lifetime.fold<double>(
      0,
      (sum, staff) => sum + (staff.owed > 0 ? staff.owed : 0),
    );
    final monthEarned = month.values.fold<double>(
      0,
      (sum, staff) => sum + staff.earned,
    );
    return [
      AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Owed to staff', style: AppText.label.copyWith(fontSize: 14)),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(money(totalOwed), style: AppText.display),
            ),
            const SizedBox(height: 6),
            Text(
              'Incentives earned minus payouts. Paid from shop profit, so you and ${appSettings.partnerName} each cover half.',
              style: AppText.caption,
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: MetricBlock(
                    label: 'Earned this month',
                    value: money(monthEarned),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricBlock(
                    label: 'Your half',
                    value: money(monthEarned / 2),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SectionHeader(title: 'Employees'),
      for (final staff in lifetime) ...[
        _staffCard(staff, month[staff.name]!),
        const SizedBox(height: 12),
      ],
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'Each item sold pays the product’s fixed incentive (₹15 by default), plus ⅓ of anything sold above the standard price. Discounts still pay the fixed amount.',
          style: AppText.caption,
        ),
      ),
      const SectionHeader(title: 'Payout history'),
      if (_staffPayouts.isEmpty)
        const EmptyState(
          icon: Icons.payments_outlined,
          title: 'No payouts yet',
          subtitle:
              'Tap Pay on an employee when you give them their incentive.',
        )
      else
        GroupedList(
          children: [
            for (final payout in _staffPayouts)
              Dismissible(
                key: ValueKey(payout.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) =>
                    _confirmAndDelete('payout', 'dk_staff_payouts', payout.id),
                onDismissed: (_) => _deleteStaffPayout(payout),
                background: const DeleteBackground(),
                child: EntryRow(
                  leading: _initialAvatar(payout.employee, size: 40),
                  title: payout.employee,
                  subtitle:
                      '${DateFormat('d MMM yyyy').format(payout.date)} · ${payout.method.label}${payout.note.isEmpty ? '' : ' · ${payout.note}'}',
                  trailing: Text(money(payout.amount), style: AppText.amount),
                ),
              ),
          ],
        ),
    ];
  }

  Widget _staffCard(StaffSummary staff, StaffSummary month) {
    final owed = staff.owed;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _initialAvatar(staff.name, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.name,
                      style: AppText.rowTitle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${month.units} item${month.units == 1 ? '' : 's'} this month · ${staff.units} total',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _showStaffPayoutForm(staff.name, owed),
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Pay'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: MetricBlock(
                  label: 'This month',
                  value: money(month.earned),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricBlock(
                  label: 'Total earned',
                  value: money(staff.earned),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricBlock(
                  label: owed < -0.005 ? 'Paid ahead' : 'Owed',
                  value: money(owed.abs()),
                  valueColor: owed > 0.005
                      ? AppColors.text
                      : AppColors.positive,
                ),
              ),
            ],
          ),
          if (staff.earned > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${money(staff.fixed)} fixed + ${money(staff.extra)} extra · ${money(staff.paid)} paid',
              style: AppText.caption.copyWith(fontFeatures: tabularFigures),
            ),
          ],
        ],
      ),
    );
  }

  Widget _initialAvatar(String name, {double size = 40}) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.fill,
      shape: BoxShape.circle,
    ),
    child: Text(
      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  );

  // ------------------------------------------------------------- profile

  Future<String?> _editText(String title, String initial, String hint) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _pickDefaultPeriod() async {
    final period = await showModalBottomSheet<ProfitPeriod>(
      context: context,
      builder: (context) => SafeArea(
        child: RadioGroup<ProfitPeriod>(
          groupValue: appSettings.defaultPeriod,
          onChanged: (value) => Navigator.pop(context, value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Open overview on', style: AppText.sheetTitle),
                ),
              ),
              for (final value in ProfitPeriod.values)
                RadioListTile<ProfitPeriod>(
                  value: value,
                  title: Text(value.label),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (period == null) return;
    await appSettings.update(defaultPeriod: period);
    if (mounted) setState(() => _period = period);
  }

  Widget _buildProfile() {
    final name = appSettings.ownerName;
    final lifetime = _lifetimeSummary;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, _listBottom),
      children: [
        const PageHeader(title: 'Profile', subtitle: 'Account and settings'),
        const SizedBox(height: 20),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.text,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : 'D.K. Mobiles',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.sectionTitle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cloudConfigured
                              ? (_email ?? 'Cloud account')
                              : 'Saved on this device',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                  if (cloudConfigured)
                    const Tooltip(
                      message: 'Synced to cloud',
                      child: Icon(
                        Icons.cloud_done_outlined,
                        size: 20,
                        color: AppColors.positive,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: MetricBlock(
                      label: 'My lifetime profit',
                      value: money(lifetime.partnerShare),
                      valueColor: AppColors.positive,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricBlock(
                      label: 'Sales recorded',
                      value: '${_sales.length}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const GroupLabel('Business'),
        GroupedList(
          indent: 56,
          children: [
            _settingsTile(
              icon: Icons.inventory_2_outlined,
              title: 'Products',
              subtitle:
                  '${_products.length} product${_products.length == 1 ? '' : 's'} · prices and emoji',
              onTap: () => _goTo(4),
            ),
            _settingsTile(
              icon: Icons.badge_outlined,
              title: 'Your name',
              subtitle: name.isEmpty ? 'Not set' : name,
              onTap: () async {
                final value = await _editText('Your name', name, 'e.g. Arbaz');
                if (value != null) await appSettings.update(ownerName: value);
              },
            ),
            _settingsTile(
              icon: Icons.handshake_outlined,
              title: 'Partner name',
              subtitle: '${appSettings.partnerName} · shares 50% of profit',
              onTap: () async {
                final value = await _editText(
                  'Partner name',
                  appSettings.partnerName,
                  'e.g. Brother',
                );
                if (value != null) {
                  await appSettings.update(partnerName: value);
                }
              },
            ),
          ],
        ),
        const GroupLabel('Preferences'),
        GroupedList(
          indent: 56,
          children: [
            _settingsTile(
              icon: Icons.today_outlined,
              title: 'Overview opens on',
              subtitle: appSettings.defaultPeriod.label,
              onTap: _pickDefaultPeriod,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.currency_rupee_rounded),
              title: const Text('Show paise'),
              subtitle: Text(
                appSettings.showPaise ? 'e.g. ₹1,250.00' : 'e.g. ₹1,250',
              ),
              value: appSettings.showPaise,
              onChanged: (value) => appSettings.update(showPaise: value),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.vibration_rounded),
              title: const Text('Haptic feedback'),
              subtitle: const Text('Vibrate on taps and selections'),
              value: appSettings.haptics,
              onChanged: (value) => appSettings.update(haptics: value),
            ),
          ],
        ),
        const GroupLabel('Data'),
        GroupedList(
          indent: 56,
          children: [
            _settingsTile(
              icon: Icons.sync_rounded,
              title: cloudConfigured ? 'Refresh from cloud' : 'Reload data',
              subtitle: cloudConfigured
                  ? 'Fetch the latest sales, expenses and payments'
                  : 'Reload records saved on this device',
              onTap: () async {
                await _load(silent: true);
                _showMessage('Up to date');
              },
            ),
            if (cloudConfigured)
              ListTile(
                onTap: _signOut,
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.negative,
                ),
                title: const Text(
                  'Sign out',
                  style: TextStyle(color: AppColors.negative),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'D.K. Mobiles Profit · v1.0.0',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textFaint, fontSize: 12),
        ),
      ],
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => ListTile(
    onTap: onTap,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: const Icon(
      Icons.chevron_right_rounded,
      color: AppColors.textFaint,
    ),
  );

  // ------------------------------------------------------------ products

  Widget _buildProducts() => ListView(
    padding: EdgeInsets.fromLTRB(12, 8, 20, _listBottom),
    children: [
      PageHeader(
        title: 'Products',
        subtitle: 'Your usual prices',
        leading: IconButton(
          tooltip: 'Back to profile',
          onPressed: () => _goTo(3),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        trailing: TextButton.icon(
          onPressed: _showProductForm,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add'),
        ),
      ),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.only(left: 8),
        child: GroupedList(
          children: [
            for (final product in _products)
              EntryRow(
                onTap: () => _showProductForm(product: product),
                leading: LeadingBadge(emoji: product.emoji),
                title: product.name,
                subtitle:
                    'Buy ${money(product.cost)} · Staff ${money(product.incentive)}',
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(money(product.price), style: AppText.amount),
                    const SizedBox(height: 2),
                    const Text('standard', style: AppText.caption),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Tap a product to edit it. Price changes only affect new sales.',
        textAlign: TextAlign.center,
        style: AppText.caption,
      ),
    ],
  );

  // ---------------------------------------------------------------- rows

  DateTime _entryDate(Object entry) =>
      entry is Sale ? entry.date : (entry as Expense).date;

  /// "4:35 PM", or null for sales saved without a time (past dates).
  String? _timeLabel(DateTime date) => date.hour == 0 && date.minute == 0
      ? null
      : DateFormat('h:mm a').format(date);

  Widget _saleRow(Sale sale, {bool showDate = true}) {
    final mine = sale.myShare;
    final time = _timeLabel(sale.date);
    final when = [
      if (showDate) DateFormat('d MMM').format(sale.date),
      ?time,
    ].join(', ');
    final details = [
      '${sale.quantity} × ${money(sale.price)}',
      if (sale.seller != null) sale.seller!,
      if (when.isNotEmpty) when,
    ].join('  ·  ');
    return _LedgerRow(
      title: sale.productName,
      amount: money(sale.revenue),
      details: details,
      secondary: 'Mine ${money(mine)}',
      secondaryColor: mine < 0 ? AppColors.negative : AppColors.positive,
      note: sale.note,
    );
  }

  Widget _expenseRow(Expense expense) => _LedgerRow(
    title: expense.note,
    amount: '−${money(expense.amount)}',
    amountColor: AppColors.negative,
    details: 'Expense  ·  ${DateFormat('d MMM yyyy').format(expense.date)}',
  );

  Widget _paymentRow(Payment payment) => EntryRow(
    leading: LeadingBadge(
      icon: payment.method == PaymentMethod.cash
          ? Icons.payments_outlined
          : Icons.account_balance_outlined,
    ),
    title: payment.method.label,
    subtitle:
        '${DateFormat('d MMM yyyy').format(payment.date)}${payment.note.isEmpty ? '' : ' · ${payment.note}'}',
    trailing: Text(money(payment.amount), style: AppText.amount),
  );
}

/// Plain two-line ledger row: title and amount on top, details and a
/// secondary figure below, optional note underneath.
class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.title,
    required this.amount,
    required this.details,
    this.amountColor,
    this.secondary,
    this.secondaryColor,
    this.note = '',
  });

  final String title;
  final String amount;
  final String details;
  final Color? amountColor;
  final String? secondary;
  final Color? secondaryColor;
  final String note;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.rowTitle,
              ),
            ),
            const SizedBox(width: 12),
            Text(amount, style: AppText.amount.copyWith(color: amountColor)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                details,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(fontFeatures: tabularFigures),
              ),
            ),
            if (secondary != null) ...[
              const SizedBox(width: 12),
              Text(
                secondary!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: secondaryColor ?? AppColors.textMuted,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ],
        ),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: AppColors.text),
            ),
          ),
        ],
      ],
    ),
  );
}
