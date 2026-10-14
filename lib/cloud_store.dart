import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);
bool get cloudConfigured =>
    supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

typedef AppData = ({
  List<Product> products,
  List<Sale> sales,
  List<Expense> expenses,
  List<Payment> payments,
});

class CloudStore {
  CloudStore(this.client);

  final SupabaseClient client;

  String get _ownerId {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in to save your data.');
    return id;
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<List<Map<String, dynamic>>> _all(String table) async {
    final rows = <Map<String, dynamic>>[];
    const pageSize = 500;
    while (true) {
      final page = await client
          .from(table)
          .select()
          .eq('owner_id', _ownerId)
          .order('id')
          .range(rows.length, rows.length + pageSize - 1);
      rows.addAll(page);
      if (page.length < pageSize) return rows;
    }
  }

  Future<AppData> load() async {
    final products = await _all('dk_products');
    final sales = await _all('dk_sales');
    final expenses = await _all('dk_expenses');
    final payments = await _all('dk_payments');
    final result = (
      products: products
          .map(
            (row) => Product(
              id: row['client_id'] as String,
              name: row['name'] as String,
              cost: (row['cost'] as num).toDouble(),
              price: (row['price'] as num).toDouble(),
              emoji: row['emoji'] as String? ?? '📱',
            ),
          )
          .toList(),
      sales: sales
          .map(
            (row) => Sale(
              id: row['client_id'] as String,
              productName: row['product_name'] as String,
              cost: (row['cost'] as num).toDouble(),
              price: (row['price'] as num).toDouble(),
              quantity: row['quantity'] as int,
              date: DateTime.parse(row['sold_at'] as String).toLocal(),
              productEmoji: row['product_emoji'] as String? ?? '📱',
            ),
          )
          .toList(),
      expenses: expenses
          .map(
            (row) => Expense(
              id: row['client_id'] as String,
              amount: (row['amount'] as num).toDouble(),
              note: row['note'] as String,
              date: DateTime.parse(row['expense_date'] as String),
            ),
          )
          .toList(),
      payments: payments
          .map(
            (row) => Payment(
              id: row['client_id'] as String,
              amount: (row['amount'] as num).toDouble(),
              method: PaymentMethod.values.byName(row['method'] as String),
              date: DateTime.parse(row['paid_on'] as String),
              note: row['note'] as String,
            ),
          )
          .toList(),
    );
    result.sales.sort((a, b) => b.date.compareTo(a.date));
    result.expenses.sort((a, b) => b.date.compareTo(a.date));
    result.payments.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  Future<void> saveProduct(Product product) =>
      client.from('dk_products').upsert({
        'owner_id': _ownerId,
        'client_id': product.id,
        'name': product.name,
        'cost': product.cost,
        'price': product.price,
        'emoji': product.emoji,
      }, onConflict: 'owner_id,client_id');

  Future<void> saveSale(Sale sale) => client
      .from('dk_sales')
      .upsert(
        {
          'owner_id': _ownerId,
          'client_id': sale.id,
          'product_name': sale.productName,
          'cost': sale.cost,
          'price': sale.price,
          'quantity': sale.quantity,
          'sold_at': sale.date.toUtc().toIso8601String(),
          'product_emoji': sale.productEmoji,
        },
        onConflict: 'owner_id,client_id',
        ignoreDuplicates: true,
      );

  Future<void> saveExpense(Expense expense) => client
      .from('dk_expenses')
      .upsert(
        {
          'owner_id': _ownerId,
          'client_id': expense.id,
          'amount': expense.amount,
          'note': expense.note,
          'expense_date': _date(expense.date),
        },
        onConflict: 'owner_id,client_id',
        ignoreDuplicates: true,
      );

  Future<void> savePayment(Payment payment) => client
      .from('dk_payments')
      .upsert(
        {
          'owner_id': _ownerId,
          'client_id': payment.id,
          'amount': payment.amount,
          'method': payment.method.name,
          'paid_on': _date(payment.date),
          'note': payment.note,
        },
        onConflict: 'owner_id,client_id',
        ignoreDuplicates: true,
      );

  Future<void> delete(String table, String clientId) async {
    await client
        .from(table)
        .delete()
        .eq('owner_id', _ownerId)
        .eq('client_id', clientId);
  }

  /// Import pre-cloud records once. Upserts make a failed import safe to retry.
  Future<void> importLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'cloud_imported_$_ownerId';
    if (prefs.getBool(key) == true) return;
    final local = await LocalStore.load();
    for (final product in local.products) {
      await saveProduct(product);
    }
    for (final sale in local.sales) {
      await saveSale(sale);
    }
    for (final expense in local.expenses) {
      await saveExpense(expense);
    }
    for (final payment in local.payments) {
      await savePayment(payment);
    }
    await prefs.setBool(key, true);
    await prefs.remove('products');
    await prefs.remove('sales');
    await prefs.remove('expenses');
    await prefs.remove('payments');
  }
}
