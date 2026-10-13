import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_store.dart';
import 'data.dart';
import 'forms.dart';
import 'sign_in.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (cloudConfigured) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  }
  runApp(const DkMobilesApp());
}

const brandInk = Color(0xFF0F172A);
const brandAccent = Color(0xFFD9FF00);
const _ink = brandInk;
const _pale = Color(0xFFF8FAFC);
const _border = Color(0xFFE2E8F0);
final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

String money(num value) => _money.format(value);

Widget surface({required Widget child}) => Container(
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _border),
  ),
  child: child,
);

class DkMobilesApp extends StatelessWidget {
  const DkMobilesApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'D.K. Mobiles Profit',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandInk,
        surface: Colors.white,
        primary: brandInk,
        secondary: brandAccent,
      ),
      scaffoldBackgroundColor: _pale,
      textTheme: Theme.of(
        context,
      ).textTheme.apply(bodyColor: _ink, displayColor: _ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandInk,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: brandAccent,
      ),
    ),
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
  int _tab = 0;
  ProfitPeriod _period = ProfitPeriod.today;
  bool _loading = true;
  String? _loadError;

  CloudStore get _cloud => CloudStore(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
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
      _products.clear();
      _sales.clear();
      _expenses.clear();
      _payments.clear();
      _products.addAll(data.products);
      _sales.addAll(data.sales);
      _expenses.addAll(data.expenses);
      _payments.addAll(data.payments);
    } catch (_) {
      _loadError = cloudConfigured
          ? 'Could not load your cloud data. Check your connection and try again.'
          : 'Could not load saved data.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _save() {
    if (!cloudConfigured) {
      LocalStore.save(_products, _sales, _expenses, _payments);
    }
  }

  Future<bool> _cloudWrite(Future<void> Function(CloudStore) action) async {
    if (!cloudConfigured) return true;
    try {
      await action(_cloud);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save. Check your connection and try again.',
            ),
          ),
        );
      }
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
      backgroundColor: Colors.white,
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
    if (_products.isEmpty) {
      await _showProductForm();
      return;
    }
    final sale = await showModalBottomSheet<Sale>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (_) => SaleForm(products: _products),
    );
    if (sale == null) return;
    if (!await _cloudWrite((store) => store.saveSale(sale))) return;
    if (!mounted) return;
    setState(() {
      _sales.insert(0, sale);
      _sales.sort((a, b) => b.date.compareTo(a.date));
      _tab = 0;
    });
    _save();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sale saved successfully')));
    }
  }

  void _deleteSale(Sale sale) {
    setState(() => _sales.removeWhere((item) => item.id == sale.id));
    _save();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sale deleted')));
  }

  Future<void> _showExpenseForm() async {
    final expense = await showModalBottomSheet<Expense>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
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
      backgroundColor: Colors.white,
      builder: (_) => const PaymentForm(),
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
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;

  List<Sale> get _filteredSales {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    return _sales.where((sale) {
      final date = sale.date;
      return switch (_period) {
        ProfitPeriod.today => !date.isBefore(today),
        ProfitPeriod.week => !date.isBefore(startOfWeek),
        ProfitPeriod.month => date.year == now.year && date.month == now.month,
        ProfitPeriod.lifetime || ProfitPeriod.average => true,
      };
    }).toList();
  }

  List<Expense> get _filteredExpenses {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    return _expenses.where((expense) {
      final date = expense.date;
      return switch (_period) {
        ProfitPeriod.today => !date.isBefore(today),
        ProfitPeriod.week => !date.isBefore(startOfWeek),
        ProfitPeriod.month => date.year == now.year && date.month == now.month,
        ProfitPeriod.lifetime || ProfitPeriod.average => true,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40),
                const SizedBox(height: 16),
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Try again')),
                if (cloudConfigured)
                  TextButton(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (mounted) {
                        setState(() {
                          _loadError = null;
                          _products.clear();
                          _sales.clear();
                          _expenses.clear();
                          _payments.clear();
                        });
                      }
                    },
                    child: const Text('Sign out'),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    final firstRun = _products.isEmpty;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: firstRun
                ? _buildWelcome()
                : IndexedStack(
                    index: _tab,
                    children: [
                      _buildOverview(),
                      _buildSales(),
                      _buildDues(),
                      _buildProducts(),
                    ],
                  ),
          ),
        ),
      ),
      bottomNavigationBar: firstRun
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              indicatorColor: const Color(0xFFD9FF00),
              onDestinationSelected: (index) => setState(() => _tab = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Overview',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Sales',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: 'Dues',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Products',
                ),
              ],
            ),
      floatingActionButton: firstRun || _tab >= 2
          ? null
          : FloatingActionButton.extended(
              onPressed: _showSaleForm,
              backgroundColor: brandInk,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add sale'),
            ),
    );
  }

  Widget _buildWelcome() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFD9FF00),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.phone_iphone_rounded,
            color: brandInk,
            size: 36,
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'D.K. Mobiles',
          style: TextStyle(
            fontSize: 35,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your daily sales and profit, made simple.',
          style: TextStyle(fontSize: 17, color: Color(0xFF64748B)),
        ),
        if (cloudConfigured) ...[const SizedBox(height: 12), _accountRow()],
        const SizedBox(height: 32),
        surface(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start with your first product',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 10),
              Text(
                'Enter the skin or wrap name, buying price and usual selling price. You can add more products any time.',
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _showProductForm,
          icon: const Icon(Icons.add),
          label: const Text('Add first product'),
          style: FilledButton.styleFrom(
            backgroundColor: brandInk,
            padding: const EdgeInsets.symmetric(vertical: 17),
          ),
        ),
      ],
    ),
  );

  Widget _buildOverview() {
    final sales = _filteredSales;
    final expenses = _filteredExpenses;
    final summary = ProfitSummary(
      sales: sales,
      expenses: expenses,
      payments: const [],
    );
    final activeDays = <DateTime>{
      ..._sales.map(
        (sale) => DateTime(sale.date.year, sale.date.month, sale.date.day),
      ),
      ..._expenses.map(
        (expense) =>
            DateTime(expense.date.year, expense.date.month, expense.date.day),
      ),
    }.length;
    final divisor = _period == ProfitPeriod.average && activeDays > 0
        ? activeDays
        : 1;
    final recentEntries = <Object>[...sales, ...expenses]
      ..sort((a, b) => _entryDate(b).compareTo(_entryDate(a)));
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _pageHeading('Profit overview', 'D.K. Mobiles · Skins & wraps'),
                if (cloudConfigured) ...[
                  const SizedBox(height: 8),
                  _accountRow(),
                ],
              ],
            ),
          ),
        ),
        SliverAppBar(
          pinned: true,
          primary: false,
          automaticallyImplyLeading: false,
          toolbarHeight: 64,
          titleSpacing: 20,
          backgroundColor: _pale,
          surfaceTintColor: _pale,
          title: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ProfitPeriod.values
                  .map(
                    (period) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(period.label),
                        selected: _period == period,
                        onSelected: (_) => setState(() => _period = period),
                        selectedColor: const Color(0xFFD9FF00),
                        side: const BorderSide(color: _border),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
          sliver: SliverList.list(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: brandInk,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _period == ProfitPeriod.average
                          ? 'AVERAGE NET PROFIT PER ACTIVE DAY'
                          : 'NET PROFIT',
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        money(summary.netProfit / divisor),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Divider(color: Color(0x66FFFFFF)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _heroDetail(
                            'Your 50% share',
                            money(summary.partnerShare / divisor),
                          ),
                        ),
                        Expanded(
                          child: _heroDetail(
                            'Brother’s 50% share',
                            money(summary.partnerShare / divisor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Sales',
                      money(summary.revenue / divisor),
                      Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      'Buying cost',
                      money(summary.buyingCost / divisor),
                      Icons.shopping_bag_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _statCard(
                'Other expenses',
                money(summary.otherExpenses / divisor),
                Icons.receipt_outlined,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setState(() => _tab = 2),
                borderRadius: BorderRadius.circular(18),
                child: surface(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: brandInk,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _lifetimeSummary.due < -0.005
                                  ? 'Paid ahead'
                                  : 'Amount due to you',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              money(_lifetimeSummary.due.abs()),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: brandInk),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              surface(
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: brandInk),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _period == ProfitPeriod.average
                            ? 'Average is based on $activeDays day${activeDays == 1 ? '' : 's'} with sales or expenses.'
                            : '${sales.length} sales and ${expenses.length} expenses. Net profit = sales − buying cost − expenses.',
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent activity',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _tab = 1),
                    child: const Text('View all'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (recentEntries.isEmpty)
                _emptyCard(
                  'No activity in this period',
                  'Add a sale or expense to see it here.',
                )
              else
                ...recentEntries
                    .take(4)
                    .map(
                      (entry) => entry is Sale
                          ? _saleTile(entry)
                          : _expenseTile(entry as Expense),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSales() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
    children: [
      _pageHeading('Sales & expenses', 'Record daily sales and other costs'),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: _showExpenseForm,
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'Sales',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      if (_sales.isEmpty)
        _emptyCard('No sales yet', 'Record a sale to see it here.')
      else
        ..._sales.map(
          (sale) => Dismissible(
            key: ValueKey(sale.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) =>
                _confirmAndDelete('sale', 'dk_sales', sale.id),
            onDismissed: (_) => _deleteSale(sale),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFC94444),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            child: _saleTile(sale),
          ),
        ),
      const SizedBox(height: 24),
      const Text(
        'Other expenses',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      if (_expenses.isEmpty)
        _emptyCard(
          'No expenses yet',
          'Tap Add expense to record a cost with a note.',
        )
      else
        ..._expenses.map(
          (expense) => Dismissible(
            key: ValueKey(expense.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) =>
                _confirmAndDelete('expense', 'dk_expenses', expense.id),
            onDismissed: (_) => _deleteExpense(expense),
            background: _deleteBackground(),
            child: _expenseTile(expense),
          ),
        ),
    ],
  );

  Widget _buildDues() {
    final summary = _lifetimeSummary;
    final due = summary.due;
    final cleared = _payments.isNotEmpty && due <= 0.005;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
      children: [
        _pageHeading('Partner dues', 'Track what your brother has paid you'),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: brandInk,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                due < -0.005 ? 'PAID AHEAD' : 'AMOUNT DUE TO YOU',
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  money(due.abs()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                cleared
                    ? 'Cleared on ${DateFormat('d MMM yyyy').format(_payments.first.date)}${due < -0.005 ? ' · Extra paid counts toward future profit.' : ''}'
                    : 'Your earned share minus payments received.',
                style: const TextStyle(color: Color(0xFFE2E8F0)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Your 50% share',
                money(summary.partnerShare),
                Icons.pie_chart_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Received',
                money(summary.received),
                Icons.payments_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _showPaymentForm,
          icon: const Icon(Icons.add),
          label: const Text('Record cash or UPI payment'),
          style: FilledButton.styleFrom(
            backgroundColor: brandInk,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 25),
        const Text(
          'Payment history',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (_payments.isEmpty)
          _emptyCard(
            'No payments yet',
            'Record the date and amount whenever your brother pays you.',
          )
        else
          ..._payments.map(
            (payment) => Dismissible(
              key: ValueKey(payment.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) =>
                  _confirmAndDelete('payment', 'dk_payments', payment.id),
              onDismissed: (_) => _deletePayment(payment),
              background: _deleteBackground(),
              child: _paymentTile(payment),
            ),
          ),
      ],
    );
  }

  Widget _buildProducts() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
    children: [
      _pageHeading('Products', 'Set your usual prices here'),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _showProductForm,
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
        style: FilledButton.styleFrom(
          backgroundColor: brandInk,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
      const SizedBox(height: 20),
      ..._products.map(
        (product) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: surface(
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.layers_outlined, color: brandInk),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Buy ${money(product.cost)}  ·  Sell ${money(product.price)}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit product',
                  onPressed: () => _showProductForm(product: product),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Changing a product price will only affect new sales.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
      ),
    ],
  );

  Widget _accountRow() => Row(
    children: [
      const Icon(Icons.cloud_done_outlined, size: 18, color: brandInk),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          Supabase.instance.client.auth.currentUser?.email ?? 'Cloud account',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ),
      TextButton(
        onPressed: () async {
          await Supabase.instance.client.auth.signOut();
          if (!mounted) return;
          setState(() {
            _products.clear();
            _sales.clear();
            _expenses.clear();
            _payments.clear();
            _tab = 0;
          });
        },
        child: const Text('Sign out'),
      ),
    ],
  );

  Widget _saleTile(Sale sale) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: surface(
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.phone_iphone_outlined, color: brandInk),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('d MMM, h:mm a').format(sale.date)} · Qty ${sale.quantity}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(sale.profit),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: sale.profit < 0 ? const Color(0xFFC94444) : brandInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sale ${money(sale.revenue)}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  DateTime _entryDate(Object entry) =>
      entry is Sale ? entry.date : (entry as Expense).date;

  Widget _expenseTile(Expense expense) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: surface(
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0E6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.receipt_outlined, color: Color(0xFFA35C2D)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d MMM yyyy').format(expense.date),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '−${money(expense.amount)}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFFA35C2D),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _paymentTile(Payment payment) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: surface(
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              payment.method == PaymentMethod.cash
                  ? Icons.payments_outlined
                  : Icons.account_balance_outlined,
              color: brandInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.method.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('d MMM yyyy').format(payment.date)}${payment.note.isEmpty ? '' : ' · ${payment.note}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            money(payment.amount),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: brandInk,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _deleteBackground() => Container(
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 24),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFC94444),
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Icon(Icons.delete_outline, color: Colors.white),
  );

  Widget _pageHeading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
      ),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
    ],
  );

  Widget _heroDetail(String title, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
      ),
      const SizedBox(height: 6),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  Widget _statCard(String title, String value, IconData icon) => surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: brandInk),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
          ),
        ),
      ],
    ),
  );

  Widget _emptyCard(String title, String subtitle) => surface(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 40,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    ),
  );
}
