import 'package:dk_mobiles_profit/data.dart';
import 'package:dk_mobiles_profit/forms.dart';
import 'package:dk_mobiles_profit/main.dart';
import 'package:dk_mobiles_profit/sales_heatmap.dart';
import 'package:dk_mobiles_profit/settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appSettings.lastSeller = '';
  });

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

  group('staff incentive', () {
    Sale padSkin({
      required double price,
      int quantity = 1,
      String? seller = 'Zahir',
    }) => Sale(
      id: 'pad-$price-$quantity-$seller',
      productName: 'PAD skin',
      cost: 25,
      price: price,
      quantity: quantity,
      date: DateTime(2026, 11, 20),
      seller: seller,
      standardPrice: 150,
      incentivePerItem: 15,
    );

    test('standard price pays only the fixed ₹15', () {
      final sale = padSkin(price: 150);
      expect(sale.profit, 125);
      expect(sale.staffIncentive, 15);
      expect(sale.myShare, 55);
    });

    test('extra above standard is split three ways', () {
      final sale = padSkin(price: 200);
      expect(sale.profit, 175);
      expect(sale.extraIncentive, closeTo(16.6667, 0.0001));
      expect(sale.staffIncentive, closeTo(31.6667, 0.0001));
      expect(sale.myShare, closeTo(71.6667, 0.0001));
      // Employee + me + brother adds up to the whole profit.
      expect(sale.staffIncentive + sale.myShare * 2, closeTo(175, 0.0001));

      final big = padSkin(price: 300);
      expect(big.staffIncentive, 65);
      expect(big.myShare, 105);
    });

    test('discounts still pay the fixed ₹15', () {
      final sale = padSkin(price: 120);
      expect(sale.staffIncentive, 15);
      expect(sale.myShare, 40);
    });

    test('incentive is per item', () {
      expect(
        padSkin(price: 200, quantity: 3).staffIncentive,
        closeTo(95, 0.0001),
      );
    });

    test('sales without an employee pay nothing', () {
      final sale = padSkin(price: 200, seller: null);
      expect(sale.staffIncentive, 0);
      expect(sale.myShare, 87.5);
    });

    test('totals and staff balances include incentives', () {
      final sales = [padSkin(price: 150), padSkin(price: 300)];
      final summary = ProfitSummary(
        sales: sales,
        expenses: const [],
        payments: const [],
      );
      expect(summary.staffIncentives, 80);
      expect(summary.netProfit, 400 - 80);
      expect(summary.partnerShare, 160);

      final zahir = StaffSummary('Zahir', sales, [
        StaffPayout(
          id: 'p',
          employee: 'Zahir',
          amount: 50,
          method: PaymentMethod.cash,
          date: DateTime(2026, 11, 21),
        ),
      ]);
      expect(zahir.fixed, 30);
      expect(zahir.extra, 50);
      expect(zahir.owed, 30);
      expect(StaffSummary('Ayan', sales, const []).earned, 0);
    });

    test('old JSON without staff fields still loads', () {
      final sale = Sale.fromJson({
        'id': 'old',
        'productName': 'Skin',
        'cost': 25,
        'price': 200,
        'quantity': 1,
        'date': '2026-10-10T00:00:00.000',
      });
      expect(sale.seller, isNull);
      expect(sale.staffIncentive, 0);
      expect(
        Product.fromJson({
          'id': 'p',
          'name': 'P',
          'cost': 1,
          'price': 2,
        }).incentive,
        15,
      );
    });
  });

  testWidgets('sale form records who sold it and shows their incentive', (
    tester,
  ) async {
    Sale? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                saved = await showModalBottomSheet<Sale>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const SaleForm(
                    products: [
                      Product(id: 'p', name: 'PAD skin', cost: 25, price: 150),
                    ],
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '200');
    await tester.ensureVisible(find.text('Ayan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ayan'));
    await tester.pumpAndSettle();
    expect(find.text('Ayan gets'), findsOneWidget);
    expect(find.text('−₹31.67'), findsOneWidget);
    expect(find.text('₹71.67'), findsOneWidget);
    await tester.ensureVisible(find.text('Save sale'));
    await tester.tap(find.text('Save sale'));
    await tester.pumpAndSettle();
    expect(saved?.seller, 'Ayan');
    expect(saved?.standardPrice, 150);
    expect(saved?.incentivePerItem, 15);
  });

  testWidgets('sale form records an item that is not in the product list', (
    tester,
  ) async {
    Sale? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                saved = await showModalBottomSheet<Sale>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const SaleForm(
                    products: [
                      Product(id: 'p', name: 'PAD skin', cost: 25, price: 150),
                    ],
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other item'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Charging cable');
    await tester.enterText(fields.at(1), '30');
    await tester.enterText(fields.at(2), '100');
    await tester.enterText(fields.at(4), 'Customer: Ravi');
    await tester.ensureVisible(find.text('Zahir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zahir'));
    await tester.pumpAndSettle();
    expect(find.text('Zahir gets'), findsOneWidget);
    await tester.ensureVisible(find.text('Save sale'));
    await tester.tap(find.text('Save sale'));
    await tester.pumpAndSettle();
    expect(saved?.productName, 'Charging cable');
    expect(saved?.cost, 30);
    expect(saved?.price, 100);
    expect(saved?.note, 'Customer: Ravi');
    expect(saved?.staffIncentive, 15);
    expect(saved?.myShare, 27.5);
    expect(Sale.fromJson(saved!.toJson()).note, 'Customer: Ravi');
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
            selectedRange: null,
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

  test('range summary halves net profit for my share', () {
    final sales = [
      Sale(
        id: 'a',
        productName: 'Wrap',
        cost: 40,
        price: 100,
        quantity: 2,
        date: DateTime(2026, 11, 3, 15),
      ),
      Sale(
        id: 'b',
        productName: 'Skin',
        cost: 20,
        price: 60,
        quantity: 1,
        date: DateTime(2026, 11, 5, 9),
      ),
      Sale(
        id: 'outside',
        productName: 'Skin',
        cost: 20,
        price: 60,
        quantity: 1,
        date: DateTime(2026, 11, 6),
      ),
    ];
    final expenses = [
      Expense(id: 'e', amount: 10, note: 'Tape', date: DateTime(2026, 11, 4)),
    ];
    final summary = summarizeRange(
      sales,
      expenses,
      DateTimeRange(start: DateTime(2026, 11, 3), end: DateTime(2026, 11, 5)),
    );
    expect(summary.transactions, 2);
    expect(summary.revenue, 260);
    expect(summary.netProfit, 150);
    expect(summary.myShare, 75);
  });

  testWidgets('long-press drag on the heatmap totals my share', (tester) async {
    DateTimeRange? selected;
    final sales = [
      for (var d = 2; d <= 4; d++)
        Sale(
          id: 's$d',
          productName: 'Wrap',
          cost: 40,
          price: 100,
          quantity: 1,
          date: DateTime(2026, 11, d),
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SalesHeatmap(
              today: DateTime(2026, 11, 20),
              sales: sales,
              selectedRange: null,
              onDaySelected: (_) {},
              onRangeSelected: (range) => selected = range,
            ),
          ),
        ),
      ),
    );
    final start = tester.getCenter(
      find.byKey(
        ValueKey('sales-day-${DateTime(2026, 11, 2).toIso8601String()}'),
      ),
    );
    final end = tester.getCenter(
      find.byKey(
        ValueKey('sales-day-${DateTime(2026, 11, 4).toIso8601String()}'),
      ),
    );
    final gesture = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(end);
    await tester.pump();
    expect(find.text('My 50% profit'), findsOneWidget);
    expect(find.text('₹90.00'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(selected?.start, DateTime(2026, 11, 2));
    expect(selected?.end, DateTime(2026, 11, 4));
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

    await tester.tap(find.byTooltip('Add sale'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '100');
    await tester.enterText(find.byType(TextFormField).at(1), '2');
    await tester.ensureVisible(find.text('Save sale'));
    await tester.tap(find.text('Save sale'));
    await tester.pumpAndSettle();

    Text textOf(String key) => tester.widget<Text>(
      find
          .descendant(of: find.byKey(Key(key)), matching: find.byType(Text))
          .last,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('my-profit-amount'))).data,
      '₹60.00',
    );
    expect(textOf('net-profit-amount').data, '₹120.00');

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
    // Move the button above the docked Add sale button.
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '20');
    await tester.enterText(find.byType(TextFormField).at(1), 'Packing');
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(find.text('Packing'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dashboard_outlined));
    await tester.pumpAndSettle();
    expect(textOf('net-profit-amount').data, '₹100.00');
    expect(
      tester.widget<Text>(find.byKey(const Key('my-profit-amount'))).data,
      '₹50.00',
    );

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
