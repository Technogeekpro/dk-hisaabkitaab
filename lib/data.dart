import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.cost,
    required this.price,
    this.emoji = '📱',
  });

  final String id;
  final String name;
  final double cost;
  final double price;
  final String emoji;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    name: json['name'] as String,
    cost: (json['cost'] as num).toDouble(),
    price: (json['price'] as num).toDouble(),
    emoji: json['emoji'] as String? ?? '📱',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cost': cost,
    'price': price,
    'emoji': emoji,
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
  });

  final String id;
  final String productName;
  final double cost;
  final double price;
  final int quantity;
  final DateTime date;
  final String productEmoji;

  double get revenue => price * quantity;
  double get totalCost => cost * quantity;
  double get profit => revenue - totalCost;

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
    id: json['id'] as String,
    productName: json['productName'] as String,
    cost: (json['cost'] as num).toDouble(),
    price: (json['price'] as num).toDouble(),
    quantity: json['quantity'] as int,
    date: DateTime.parse(json['date'] as String),
    productEmoji: json['productEmoji'] as String? ?? '📱',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'productName': productName,
    'cost': cost,
    'price': price,
    'quantity': quantity,
    'date': date.toIso8601String(),
    'productEmoji': productEmoji,
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
  double get otherExpenses =>
      expenses.fold(0, (sum, expense) => sum + expense.amount);
  double get netProfit => revenue - buyingCost - otherExpenses;
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
    sales.sort((a, b) => b.date.compareTo(a.date));
    expenses.sort((a, b) => b.date.compareTo(a.date));
    payments.sort((a, b) => b.date.compareTo(a.date));
    return (
      products: products,
      sales: sales,
      expenses: expenses,
      payments: payments,
    );
  }

  static Future<void> save(
    List<Product> products,
    List<Sale> sales,
    List<Expense> expenses,
    List<Payment> payments,
  ) async {
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
  }
}
