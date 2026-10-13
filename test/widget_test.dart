import 'package:dk_mobiles_profit/data.dart';
import 'package:dk_mobiles_profit/main.dart';
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

  testWidgets('first product and sale appear in profit overview', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DkMobilesApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add first product'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Matte skin');
    await tester.enterText(find.byType(TextFormField).at(1), '40');
    await tester.enterText(find.byType(TextFormField).at(2), '100');
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add sale'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '100');
    await tester.enterText(find.byType(TextFormField).at(1), '2');
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
