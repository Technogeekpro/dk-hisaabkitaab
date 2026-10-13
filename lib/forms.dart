import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'data.dart';
import 'main.dart';

class ProductForm extends StatefulWidget {
  const ProductForm({super.key, this.product});
  final Product? product;

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _cost;
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.product?.name ?? '');
    _cost = TextEditingController(text: widget.product?.cost.toString() ?? '');
    _price = TextEditingController(
      text: widget.product?.price.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      22,
      24,
      22,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.product == null ? 'Add product' : 'Edit product',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            const Text(
              'Set the usual prices for this skin or wrap.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Product name',
                hintText: 'e.g. Matte black skin',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a product name'
                  : null,
            ),
            const SizedBox(height: 14),
            priceField(_cost, 'Buying price (₹)'),
            const SizedBox(height: 14),
            priceField(_price, 'Usual selling price (₹)'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  Product(
                    id:
                        widget.product?.id ??
                        DateTime.now().microsecondsSinceEpoch.toString(),
                    name: _name.text.trim(),
                    cost: double.parse(_cost.text),
                    price: double.parse(_price.text),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: brandInk,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Save product'),
            ),
          ],
        ),
      ),
    ),
  );
}

class SaleForm extends StatefulWidget {
  const SaleForm({super.key, required this.products});
  final List<Product> products;

  @override
  State<SaleForm> createState() => _SaleFormState();
}

class _SaleFormState extends State<SaleForm> {
  final _formKey = GlobalKey<FormState>();
  late Product _selected;
  late final TextEditingController _price;
  late final TextEditingController _quantity;

  @override
  void initState() {
    super.initState();
    _selected = widget.products.first;
    _price = TextEditingController(text: _selected.price.toString());
    _quantity = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _price.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quantity = int.tryParse(_quantity.text) ?? 0;
    final price = double.tryParse(_price.text) ?? 0;
    final profit = (price - _selected.cost) * quantity;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        24,
        22,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add a sale',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              const Text(
                'Choose the product and enter what you sold it for.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: _selected.id,
                decoration: const InputDecoration(labelText: 'Product'),
                items: widget.products
                    .map(
                      (product) => DropdownMenuItem(
                        value: product.id,
                        child: Text(
                          product.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  setState(() {
                    _selected = widget.products.firstWhere(
                      (item) => item.id == id,
                    );
                    _price.text = _selected.price.toString();
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Buying price: ${money(_selected.cost)} each',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
              const SizedBox(height: 16),
              priceField(
                _price,
                'Selling price per item (₹)',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Quantity'),
                onChanged: (_) => setState(() {}),
                validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                    ? 'Enter a quantity of at least 1'
                    : null,
              ),
              const SizedBox(height: 18),
              surface(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Profit from this sale',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      money(profit),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: profit < 0 ? const Color(0xFFC94444) : brandInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    Sale(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      productName: _selected.name,
                      cost: _selected.cost,
                      price: double.parse(_price.text),
                      quantity: int.parse(_quantity.text),
                      date: DateTime.now(),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: brandInk,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save sale'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExpenseForm extends StatefulWidget {
  const ExpenseForm({super.key});

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      22,
      24,
      22,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add expense',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            const Text(
              'Expenses reduce the profit before the 50/50 split.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            priceField(_amount, 'Expense amount (₹)', allowZero: false),
            const SizedBox(height: 14),
            TextFormField(
              controller: _note,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Short note',
                hintText: 'e.g. Lamination material',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a short note'
                  : null,
            ),
            DatePickerRow(
              date: _date,
              onChanged: (date) => setState(() => _date = date),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  Expense(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    amount: double.parse(_amount.text),
                    note: _note.text.trim(),
                    date: _date,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: brandInk,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Save expense'),
            ),
          ],
        ),
      ),
    ),
  );
}

class PaymentForm extends StatefulWidget {
  const PaymentForm({super.key});

  @override
  State<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      22,
      24,
      22,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Record payment',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            const Text(
              'Enter the actual amount your brother paid you, including rounded amounts.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            priceField(_amount, 'Amount received (₹)', allowZero: false),
            const SizedBox(height: 14),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: PaymentMethod.values
                  .map(
                    (method) => DropdownMenuItem(
                      value: method,
                      child: Text(method.label),
                    ),
                  )
                  .toList(),
              onChanged: (method) {
                if (method != null) setState(() => _method = method);
              },
            ),
            const SizedBox(height: 14),
            DatePickerRow(
              date: _date,
              onChanged: (date) => setState(() => _date = date),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _note,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. Weekly settlement',
              ),
            ),
            FilledButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  Payment(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    amount: double.parse(_amount.text),
                    method: _method,
                    date: _date,
                    note: _note.text.trim(),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: brandInk,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Save payment'),
            ),
          ],
        ),
      ),
    ),
  );
}

class DatePickerRow extends StatelessWidget {
  const DatePickerRow({super.key, required this.date, required this.onChanged});

  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (picked != null) onChanged(picked);
    },
    icon: const Icon(Icons.calendar_month_outlined),
    label: Text('Date: ${DateFormat('d MMM yyyy').format(date)}'),
    style: OutlinedButton.styleFrom(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}

Widget priceField(
  TextEditingController controller,
  String label, {
  ValueChanged<String>? onChanged,
  bool allowZero = true,
}) => TextFormField(
  controller: controller,
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  inputFormatters: [
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
  ],
  decoration: InputDecoration(labelText: label),
  onChanged: onChanged,
  validator: (value) {
    final amount = double.tryParse(value ?? '');
    if (amount == null || amount < 0 || (!allowZero && amount == 0)) {
      return 'Enter an amount greater than zero';
    }
    return null;
  },
);
