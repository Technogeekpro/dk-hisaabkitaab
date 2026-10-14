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
  late final TextEditingController _emoji;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.product?.name ?? '');
    _cost = TextEditingController(text: widget.product?.cost.toString() ?? '');
    _price = TextEditingController(
      text: widget.product?.price.toString() ?? '',
    );
    _emoji = TextEditingController(text: widget.product?.emoji ?? '📱');
  }

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    _price.dispose();
    _emoji.dispose();
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
              controller: _emoji,
              maxLength: 1,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: const InputDecoration(
                labelText: 'Product emoji',
                helperText: 'Choose below or type any emoji',
              ),
              validator: (value) =>
                  value == null ||
                      value.trim().isEmpty ||
                      value.characters.length != 1
                  ? 'Choose one emoji'
                  : null,
            ),
            Wrap(
              spacing: 8,
              children: ['📱', '🎨', '✨', '🖤', '🛡️', '💎', '🔥', '🌈']
                  .map(
                    (emoji) => ActionChip(
                      label: Text(emoji, style: const TextStyle(fontSize: 20)),
                      onPressed: () => setState(() => _emoji.text = emoji),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
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
                    emoji: _emoji.text,
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
  DateTime _date = DateTime.now();

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

  Future<void> _chooseProduct() async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final availableHeight =
            MediaQuery.sizeOf(sheetContext).height -
            MediaQuery.viewInsetsOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SizedBox(
            height: availableHeight * 0.72,
            child: ProductSearchSheet(products: widget.products),
          ),
        );
      },
    );
    if (product == null || !mounted) return;
    setState(() {
      _selected = product;
      _price.text = product.price.toString();
    });
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
              OutlinedButton(
                onPressed: _chooseProduct,
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(16),
                ),
                child: Row(
                  children: [
                    Text(_selected.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_selected.name)),
                    const Icon(Icons.search),
                  ],
                ),
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
              const SizedBox(height: 14),
              DatePickerRow(
                date: _date,
                label: 'Sale date',
                onChanged: (date) => setState(() => _date = date),
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
                      productEmoji: _selected.emoji,
                      cost: _selected.cost,
                      price: double.parse(_price.text),
                      quantity: int.parse(_quantity.text),
                      date: _date,
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

class ProductSearchSheet extends StatefulWidget {
  const ProductSearchSheet({super.key, required this.products});

  final List<Product> products;

  @override
  State<ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<ProductSearchSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final matches = widget.products
        .where((product) => product.name.toLowerCase().contains(query))
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Find a product',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search products',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: matches.isEmpty
                ? const Center(child: Text('No matching products'))
                : ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final product = matches[index];
                      return ListTile(
                        leading: Text(
                          product.emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                        title: Text(product.name),
                        subtitle: Text('Sell ${money(product.price)}'),
                        onTap: () => Navigator.pop(context, product),
                      );
                    },
                  ),
          ),
        ],
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
  const DatePickerRow({
    super.key,
    required this.date,
    required this.onChanged,
    this.label = 'Date',
  });

  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final String label;

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
    label: Text('$label: ${DateFormat('d MMM yyyy').format(date)}'),
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
