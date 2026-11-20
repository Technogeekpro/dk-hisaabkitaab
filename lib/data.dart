import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.cost,
    required this.price,
    this.emoji = '📱',
    this.incentive = defaultStaffIncentive,
  });

  final String id;
  final String name;
  final double cost;

  /// Standard selling price. Staff share anything sold above it.
  final double price;
  final String emoji;

  /// Fixed amount paid to the employee for each item they sell.
  final double incentive;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    name: json['name'] as String,
    cost: (json['cost'] as num).toDouble(),
    price: (json['price'] as num).toDouble(),
    emoji: json['emoji'] as String? ?? '📱',
    incentive: (json['incentive'] as num?)?.toDouble() ?? defaultStaffIncentive,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cost': cost,
    'price': price,
    'emoji': emoji,
    'incentive': incentive,
  };
}

class Sale {
  const Sale({
    required this.id,
    required this.productName,
    required this.cost,
    required this.price,
    required this.quantity,
    required this.date,
    this.productEmoji = '📱',
    this.seller,
    this.standardPrice,
    this.incentivePerItem = 0,
    this.note = '',
  });

  final String id;
  final String productName;
  final double cost;

  /// Actual selling price per item.
  final double price;
  final int quantity;
  final DateTime date;
  final String productEmoji;

  /// Employee who made the sale, or null when no employee was involved.
  final String? seller;

  /// The product's standard price and fixed incentive when the sale was made.
  final double? standardPrice;
  final double incentivePerItem;

  /// Optional free-text note, e.g. customer or device.
  final String note;

  double get revenue => price * quantity;
  double get totalCost => cost * quantity;

  /// Profit before staff incentives.
  double get profit => revenue - totalCost;

  /// Amount sold above the standard price, per item. Never negative:
  /// discounts still pay the full fixed incentive.
  double get extraPerItem =>
      standardPrice == null ? 0 : math.max(0, price - standardPrice!);

  /// Fixed part of the employee incentive for this sale.
  double get fixedIncentive => seller == null ? 0 : incentivePerItem * quantity;

  /// Employee's third of the amount sold above the standard price.
  double get extraIncentive => seller == null ? 0 : extraPerItem * quantity / 3;

  double get staffIncentive => fixedIncentive + extraIncentive;

  /// Profit left for the two partners after paying the employee.
  double get shopProfit => profit - staffIncentive;

  /// My 50% of the shop profit.
  double get myShare => shopProfit / 2;

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
    id: json['id'] as String,
    productName: json['productName'] as String,
    cost: (json['cost'] as num).toDouble(),
    price: (json['price'] as num).toDouble(),
    quantity: json['quantity'] as int,
    date: DateTime.parse(json['date'] as String),
    productEmoji: json['productEmoji'] as String? ?? '📱',
    seller: json['seller'] as String?,
    standardPrice: (json['standardPrice'] as num?)?.toDouble(),
    incentivePerItem: (json['incentivePerItem'] as num?)?.toDouble() ?? 0,
    note: json['note'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'productName': productName,
    'cost': cost,
    'price': price,
    'quantity': quantity,
    'date': date.toIso8601String(),
    'productEmoji': productEmoji,
    'seller': seller,
    'standardPrice': standardPrice,
    'incentivePerItem': incentivePerItem,
    'note': note,
  };
}

class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.note,
    required this.date,
  });

  final String id;
  final double amount;
  final String note;
  final DateTime date;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String,
    amount: (json['amount'] as num).toDouble(),
    note: json['note'] as String,
    date: DateTime.parse(json['date'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'note': note,
    'date': date.toIso8601String(),
  };
}

enum PaymentMethod { cash, upi }

extension PaymentMethodLabel on PaymentMethod {
  String get label => this == PaymentMethod.cash ? 'Cash' : 'UPI';
}

class Payment {
  const Payment({
    required this.id,
    required this.amount,
    required this.method,
    required this.date,
    this.note = '',
  });

  final String id;
  final double amount;
  final PaymentMethod method;
  final DateTime date;
  final String note;

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'] as String,
    amount: (json['amount'] as num).toDouble(),
    method: PaymentMethod.values.byName(json['method'] as String),
    date: DateTime.parse(json['date'] as String),
    note: json['note'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'method': method.name,
    'date': date.toIso8601String(),
    'note': note,
  };
}

const defaultStaffIncentive = 15.0;

/// Employees who earn incentives on the sales they make.
const staffMembers = ['Zahir', 'Ayan', 'Huzaifa'];

/// Money paid to an employee against the incentives they earned.
class StaffPayout {
  const StaffPayout({
    required this.id,
    required this.employee,
    required this.amount,
    required this.method,
    required this.date,
    this.note = '',
  });

  final String id;
  final String employee;
  final double amount;
  final PaymentMethod method;
  final DateTime date;
  final String note;

  factory StaffPayout.fromJson(Map<String, dynamic> json) => StaffPayout(
    id: json['id'] as String,
    employee: json['employee'] as String,
    amount: (json['amount'] as num).toDouble(),
    method: PaymentMethod.values.byName(json['method'] as String),
    date: DateTime.parse(json['date'] as String),
    note: json['note'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'employee': employee,
    'amount': amount,
    'method': method.name,
    'date': date.toIso8601String(),
    'note': note,
  };
}

/// What one employee has earned and been paid.
class StaffSummary {
  StaffSummary(this.name, Iterable<Sale> sales, Iterable<StaffPayout> payouts) {
    for (final sale in sales) {
      if (sale.seller != name) continue;
      transactions++;
      units += sale.quantity;
      fixed += sale.fixedIncentive;
      extra += sale.extraIncentive;
    }
    for (final payout in payouts) {
      if (payout.employee == name) paid += payout.amount;
    }
  }

  final String name;
  int transactions = 0;
  int units = 0;
  double fixed = 0;
  double extra = 0;
  double paid = 0;

  double get earned => fixed + extra;
  double get owed => earned - paid;
}

class ProfitSummary {
  const ProfitSummary({
    required this.sales,
    required this.expenses,
    required this.payments,
  });

  final List<Sale> sales;
  final List<Expense> expenses;
  final List<Payment> payments;

  double get revenue => sales.fold(0, (sum, sale) => sum + sale.revenue);
  double get buyingCost => sales.fold(0, (sum, sale) => sum + sale.totalCost);
  double get staffIncentives =>
      sales.fold(0, (sum, sale) => sum + sale.staffIncentive);
  double get otherExpenses =>
      expenses.fold(0, (sum, expense) => sum + expense.amount);
  double get netProfit =>
      revenue - buyingCost - staffIncentives - otherExpenses;
  double get partnerShare => netProfit / 2;
  double get received =>
      payments.fold(0, (sum, payment) => sum + payment.amount);
  double get due => partnerShare - received;
}

enum ProfitPeriod { today, week, month, lifetime, average }

extension ProfitPeriodLabel on ProfitPeriod {
  String get label => switch (this) {
    ProfitPeriod.today => 'Today',
    ProfitPeriod.week => 'This week',
    ProfitPeriod.month => 'This month',
    ProfitPeriod.lifetime => 'Lifetime',
    ProfitPeriod.average => 'Average',
  };
}

class LocalStore {
  static Future<
    ({
      List<Product> products,
      List<Sale> sales,
      List<Expense> expenses,
      List<Payment> payments,
      List<StaffPayout> staffPayouts,
    })
  >
  load() async {
    final prefs = await SharedPreferences.getInstance();
    final productsJson =
        jsonDecode(prefs.getString('products') ?? '[]') as List<dynamic>;
    final salesJson =
        jsonDecode(prefs.getString('sales') ?? '[]') as List<dynamic>;
    final expensesJson =
        jsonDecode(prefs.getString('expenses') ?? '[]') as List<dynamic>;
    final paymentsJson =
        jsonDecode(prefs.getString('payments') ?? '[]') as List<dynamic>;
    final staffPayoutsJson =
        jsonDecode(prefs.getString('staff_payouts') ?? '[]') as List<dynamic>;
    final products = productsJson
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
    final sales = salesJson
        .map((item) => Sale.fromJson(item as Map<String, dynamic>))
        .toList();
    final expenses = expensesJson
        .map((item) => Expense.fromJson(item as Map<String, dynamic>))
        .toList();
    final payments = paymentsJson
        .map((item) => Payment.fromJson(item as Map<String, dynamic>))
        .toList();
    final staffPayouts = staffPayoutsJson
        .map((item) => StaffPayout.fromJson(item as Map<String, dynamic>))
        .toList();
    sales.sort((a, b) => b.date.compareTo(a.date));
    expenses.sort((a, b) => b.date.compareTo(a.date));
    payments.sort((a, b) => b.date.compareTo(a.date));
    staffPayouts.sort((a, b) => b.date.compareTo(a.date));
    return (
      products: products,
      sales: sales,
      expenses: expenses,
      payments: payments,
      staffPayouts: staffPayouts,
    );
  }

  static Future<void> save(
    List<Product> products,
    List<Sale> sales,
    List<Expense> expenses,
    List<Payment> payments, [
    List<StaffPayout> staffPayouts = const [],
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'products',
      jsonEncode(products.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      'sales',
      jsonEncode(sales.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      'expenses',
      jsonEncode(expenses.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      'payments',
      jsonEncode(payments.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(
      'staff_payouts',
      jsonEncode(staffPayouts.map((item) => item.toJson()).toList()),
    );
  }
}
