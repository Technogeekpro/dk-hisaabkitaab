import 'package:dk_mobiles_profit/data.dart';
import 'package:dk_mobiles_profit/forms.dart';
import 'package:dk_mobiles_profit/main.dart';
import 'package:dk_mobiles_profit/sales_heatmap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('profit includes quantity and keeps sale prices', () {
    final sale = Sale(
      id: '1',
      productName: 'Wrap',
      cost: 40,
      price: 100,
      quantity: 3,
      date: DateTime(2026, 10, 10),
    );
    expect(sale.revenue, 300);
    expect(sale.totalCost, 120);
    expect(sale.profit, 180);
    expect(Sale.fromJson(sale.toJson()).profit, 180);
  });

  test('expenses and rounded payments update the amount due', () {
    final summary = ProfitSummary(
      sales: [
        Sale(
          id: 's',
          productName: 'Skin',
          cost: 40,
          price: 100,
          quantity: 2,
          date: DateTime(2026, 10, 10),
        ),
      ],
      expenses: [
        Expense(
          id: 'e',
          amount: 15,
          note: 'Packing',
          date: DateTime(2026, 10, 10),
        ),
      ],
      payments: [
        Payment(
          id: 'p',
          amount: 50,
          method: PaymentMethod.upi,
          date: DateTime(2026, 10, 11),
        ),
      ],
    );
    expect(summary.netProfit, 105);
    expect(summary.partnerShare, 52.5);
    expect(summary.received, 50);
    expect(summary.due, 2.5);
  });

  test('emoji survives local serialization and sales keep their snapshot', () {
    const product = Product(
      id: 'p',
      name: 'Wrap',
      cost: 40,
      price: 100,
      emoji: '🛡️',
    );
    final sale = Sale(
      id: 's',
      productName: product.name,
      productEmoji: product.emoji,
      cost: product.cost,
      price: product.price,
      quantity: 2,
      date: DateTime(2026, 10, 10),
    );
    expect(Product.fromJson(product.toJson()).emoji, '🛡️');
    expect(Sale.fromJson(sale.toJson()).productEmoji, '🛡️');
    expect(
      Product.fromJson({
        'id': 'old',
        'name': 'Old',
        'cost': 1,
        'price': 2,
      }).emoji,
      '📱',
    );
    final day = summarizeSalesByDay([sale])[DateTime(2026, 10, 10)]!;
    expect(day.transactions, 1);
    expect(day.units, 2);
    expect(day.revenue, 200);
    expect(day.profit, 120);
  });

  testWidgets('the heatmap lets a user choose a sales day', (tester) async {
    DateTime? picked;
    final day = DateTime(2026, 10, 10);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SalesHeatmap(
            today: DateTime(2026, 10, 14),
            sales: [
              Sale(
                id: 'one',
                productName: 'Wrap',
                cost: 40,
                price: 100,
                quantity: 1,
                date: day,
              ),
            ],
            selectedDay: null,
            onDaySelected: (value) => picked = value,
          ),
        ),
      ),
    );
    await tester.tap(
      find.byKey(ValueKey('sales-day-${day.toIso8601String()}')),
    );
    expect(picked, day);
  });

  testWidgets('sale form searches products and accepts a past date', (
    tester,
  ) async {
    Sale? saved;
    final products = [
      const Product(id: 'a', name: 'Basic skin', cost: 20, price: 50),
      const Product(
        id: 'b',
        name: 'Premium wrap',
        cost: 40,
        price: 100,
        emoji: '✨',
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                saved = await showModalBottomSheet<Sale>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SaleForm(products: products),
                );
              },
              child: const Text('Open sale form'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sale form'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Basic skin'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'premium');
    await tester.pumpAndSettle();
    expect(find.text('Premium wrap'), findsOneWidget);
    await tester.tap(find.text('Premium wrap'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.textContaining('Sale date:'));
    await tester.tap(find.textContaining('Sale date:'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('10').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save sale'));
    await tester.tap(find.text('Save sale'));
    await tester.pumpAndSettle();

    expect(saved?.productName, 'Premium wrap');
    expect(saved?.productEmoji, '✨');
    expect(saved?.date.isBefore(DateTime.now()), isTrue);
  });

  testWidgets('first product and sale appear in profit overview', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DkMobilesApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add first product'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '🛡️');
    await tester.enterText(find.byType(TextFormField).at(1), 'Matte skin');
    await tester.enterText(find.byType(TextFormField).at(2), '40');
    await tester.enterText(find.byType(TextFormField).at(3), '100');
    await tester.ensureVisible(find.text('Save product'));
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add sale'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '100');
    await tester.enterText(find.byType(TextFormField).at(1), '2');
    await tester.ensureVisible(find.text('Save sale'));
    await tester.tap(find.text('Save sale'));
    await tester.pumpAndSettle();

    expect(find.text('₹120.00'), findsOneWidget);
    expect(find.text('₹60.00'), findsNWidgets(2));

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Today')).dy, lessThan(80));
    final heading = find.text('Profit overview');
    expect(
      heading.evaluate().isEmpty || tester.getBottomLeft(heading).dy <= 0,
      isTrue,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 650));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Sales activity'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Add expense'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '20');
    await tester.enterText(find.byType(TextFormField).at(1), 'Packing');
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(find.text('Packing'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dashboard_outlined));
    await tester.pumpAndSettle();
    expect(find.text('₹100.00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record cash or UPI payment'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '50');
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UPI').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();
    expect(find.text('₹0.00'), findsOneWidget);
    final saved = await LocalStore.load();
    expect(saved.expenses.single.note, 'Packing');
    expect(saved.payments.single.method, PaymentMethod.upi);
    expect(saved.payments.single.amount, 50);
  });
}
