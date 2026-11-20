import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'data.dart';
import 'settings.dart';
import 'theme.dart';
import 'ui.dart';

/// Shared layout for every bottom-sheet form: title, subtitle, fields and a
/// primary button, padded above the keyboard.
class _SheetForm extends StatelessWidget {
  const _SheetForm({
    required this.formKey,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppText.sheetTitle),
            const SizedBox(height: 4),
            Text(subtitle, style: AppText.label.copyWith(fontSize: 14)),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class ProductForm extends StatefulWidget {
  const ProductForm({super.key, this.product});
  final Product? product;

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  static const _emojis = ['📱', '🎨', '✨', '🖤', '🛡️', '💎', '🔥', '🌈'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _cost;
  late final TextEditingController _price;
  late final TextEditingController _emoji;
  late final TextEditingController _incentive;

  @override
  void initState() {
    super.initState();
    _incentive = TextEditingController(
      text: _plain(widget.product?.incentive ?? defaultStaffIncentive),
    );
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
    _incentive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SheetForm(
    formKey: _formKey,
    title: widget.product == null ? 'Add product' : 'Edit product',
    subtitle: 'Set the usual prices for this skin or wrap.',
    children: [
      TextFormField(
        controller: _emoji,
        maxLength: 1,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Emoji',
          helperText: 'Pick one below or type any emoji',
          counterText: '',
        ),
        validator: (value) =>
            value == null ||
                value.trim().isEmpty ||
                value.characters.length != 1
            ? 'Choose one emoji'
            : null,
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final emoji in _emojis)
            _EmojiChoice(
              emoji: emoji,
              selected: _emoji.text == emoji,
              onTap: () => setState(() => _emoji.text = emoji),
            ),
        ],
      ),
      const SizedBox(height: 20),
      TextFormField(
        controller: _name,
        maxLength: 100,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Product name',
          hintText: 'e.g. Matte black skin',
          counterText: '',
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Enter a product name'
            : null,
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: priceField(_cost, 'Buying price')),
          const SizedBox(width: 12),
          Expanded(child: priceField(_price, 'Standard price')),
        ],
      ),
      const SizedBox(height: 16),
      priceField(_incentive, 'Staff incentive per item'),
      const SizedBox(height: 6),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'Fixed amount staff get for each item they sell, even at a discount. '
          'They also get ⅓ of anything sold above the standard price.',
          style: AppText.caption,
        ),
      ),
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
              incentive: double.parse(_incentive.text),
            ),
          );
        },
        child: const Text('Save product'),
      ),
    ],
  );
}

class _EmojiChoice extends StatelessWidget {
  const _EmojiChoice({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Emoji $emoji',
    child: Material(
      color: selected ? AppColors.fill : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.text : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
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
  final _otherName = TextEditingController();
  final _otherCost = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();

  /// True when selling something that is not in the product list.
  bool _other = false;

  /// Employee who made the sale; empty when no employee.
  String _seller = staffMembers.contains(appSettings.lastSeller)
      ? appSettings.lastSeller
      : '';

  @override
  void initState() {
    super.initState();
    _selected = widget.products.first;
    _price = TextEditingController(text: _plain(_selected.price));
    _quantity = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _price.dispose();
    _quantity.dispose();
    _otherName.dispose();
    _otherCost.dispose();
    _note.dispose();
    super.dispose();
  }

  void _setOther(bool other) {
    if (other == _other) return;
    setState(() {
      _other = other;
      _price.text = other ? '' : _plain(_selected.price);
    });
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
      _price.text = _plain(product.price);
    });
  }

  void _stepQuantity(int delta) {
    final next = ((int.tryParse(_quantity.text) ?? 1) + delta).clamp(1, 999);
    setState(() => _quantity.text = '$next');
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft(
      price: double.tryParse(_price.text) ?? 0,
      quantity: int.tryParse(_quantity.text) ?? 0,
    );
    final mine = draft.myShare;
    return _SheetForm(
      formKey: _formKey,
      title: 'Add a sale',
      subtitle: 'Pick a product, or add an item that isn’t on your list.',
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('From products'),
                icon: Icon(Icons.inventory_2_outlined, size: 18),
              ),
              ButtonSegment(
                value: true,
                label: Text('Other item'),
                icon: Icon(Icons.edit_outlined, size: 18),
              ),
            ],
            selected: {_other},
            onSelectionChanged: (selection) => _setOther(selection.first),
          ),
        ),
        const SizedBox(height: 16),
        if (!_other)
          _FieldButton(
            onPressed: _chooseProduct,
            leading: Text(
              _selected.emoji,
              style: const TextStyle(fontSize: 22),
            ),
            label: _selected.name,
            caption:
                'Buys at ${money(_selected.cost)} · Standard ${money(_selected.price)}',
            trailing: const Icon(
              Icons.unfold_more_rounded,
              color: AppColors.textMuted,
            ),
          )
        else ...[
          TextFormField(
            controller: _otherName,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Item name',
              hintText: 'e.g. Charging cable',
              counterText: '',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter what you sold'
                : null,
          ),
          const SizedBox(height: 16),
          priceField(
            _otherCost,
            'Buying cost per item',
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: priceField(
                _price,
                'Selling price',
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Qty',
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  prefixIconConstraints: const BoxConstraints(minWidth: 40),
                  suffixIconConstraints: const BoxConstraints(minWidth: 40),
                  prefixIcon: IconButton(
                    tooltip: 'Decrease quantity',
                    onPressed: () => _stepQuantity(-1),
                    icon: const Icon(Icons.remove_rounded, size: 18),
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Increase quantity',
                    onPressed: () => _stepQuantity(1),
                    icon: const Icon(Icons.add_rounded, size: 18),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) =>
                    (int.tryParse(value ?? '') ?? 0) < 1 ? 'At least 1' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Sold by', style: AppText.label),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            segments: [
              const ButtonSegment(value: '', label: Text('No one')),
              for (final name in staffMembers)
                ButtonSegment(value: name, label: Text(name)),
            ],
            selected: {_seller},
            onSelectionChanged: (selection) =>
                setState(() => _seller = selection.first),
          ),
        ),
        const SizedBox(height: 16),
        DatePickerRow(
          date: _date,
          label: 'Sale date',
          onChanged: (date) => setState(() => _date = date),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _note,
          maxLength: 200,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            hintText: 'e.g. Customer name or phone model',
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _previewRow('Profit from this sale', money(draft.profit)),
              if (draft.seller != null)
                _previewRow(
                  '${draft.seller} gets',
                  '−${money(draft.staffIncentive)}',
                  caption: _incentiveBreakdown(draft),
                ),
              const Divider(height: 12),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'My profit (50%)',
                      style: AppText.rowTitle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    money(mine),
                    style: AppText.metric.copyWith(
                      fontSize: 20,
                      color: mine < 0 ? AppColors.negative : AppColors.positive,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            appSettings.update(lastSeller: _seller);
            Navigator.pop(
              context,
              _draft(
                price: double.parse(_price.text),
                quantity: int.parse(_quantity.text),
              ),
            );
          },
          child: const Text('Save sale'),
        ),
      ],
    );
  }

  Sale _draft({required double price, required int quantity}) {
    final seller = _seller.isEmpty ? null : _seller;
    final note = _note.text.trim();
    if (_other) {
      final name = _otherName.text.trim();
      return Sale(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        productName: name.isEmpty ? 'Other item' : name,
        productEmoji: '🏷️',
        cost: double.tryParse(_otherCost.text) ?? 0,
        price: price,
        quantity: quantity,
        date: _date,
        seller: seller,
        // No standard price for one-off items: staff get only the fixed amount.
        standardPrice: price,
        incentivePerItem: defaultStaffIncentive,
        note: note,
      );
    }
    return Sale(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      productName: _selected.name,
      productEmoji: _selected.emoji,
      cost: _selected.cost,
      price: price,
      quantity: quantity,
      date: _date,
      seller: seller,
      standardPrice: _selected.price,
      incentivePerItem: _selected.incentive,
      note: note,
    );
  }

  String _incentiveBreakdown(Sale sale) {
    final fixed =
        '${money(sale.incentivePerItem)} fixed${sale.quantity > 1 ? ' × ${sale.quantity}' : ''}';
    if (sale.extraPerItem <= 0) return fixed;
    final extra = sale.extraPerItem * sale.quantity;
    return '$fixed + ⅓ of ${money(extra)} extra (${money(sale.extraIncentive)})';
  }

  Widget _previewRow(String label, String value, {String? caption}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.label.copyWith(fontSize: 14)),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(caption, style: AppText.caption),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(value, style: AppText.amount),
      ],
    ),
  );
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Find a product', style: AppText.sheetTitle),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search products',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: matches.isEmpty
                ? const Center(
                    child: Text('No matching products', style: AppText.label),
                  )
                : ListView.separated(
                    itemCount: matches.length,
                    separatorBuilder: (_, _) => const Divider(indent: 52),
                    itemBuilder: (context, index) {
                      final product = matches[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: LeadingBadge(emoji: product.emoji),
                        title: Text(product.name),
                        subtitle: Text(
                          'Buy ${money(product.cost)} · Sell ${money(product.price)}',
                        ),
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
  Widget build(BuildContext context) => _SheetForm(
    formKey: _formKey,
    title: 'Add expense',
    subtitle: 'Expenses reduce the profit before the 50/50 split.',
    children: [
      priceField(_amount, 'Amount', allowZero: false),
      const SizedBox(height: 16),
      TextFormField(
        controller: _note,
        maxLength: 100,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Short note',
          hintText: 'e.g. Lamination material',
          counterText: '',
        ),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Enter a short note' : null,
      ),
      const SizedBox(height: 16),
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
        child: const Text('Save expense'),
      ),
    ],
  );
}

class PaymentForm extends StatefulWidget {
  const PaymentForm({super.key, this.partnerName = 'your brother'});

  final String partnerName;

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
  Widget build(BuildContext context) => _SheetForm(
    formKey: _formKey,
    title: 'Record payment',
    subtitle:
        'Enter the actual amount ${widget.partnerName} paid you, including rounded amounts.',
    children: [
      priceField(_amount, 'Amount received', allowZero: false),
      const SizedBox(height: 16),
      SegmentedButton<PaymentMethod>(
        showSelectedIcon: false,
        segments: [
          for (final method in PaymentMethod.values)
            ButtonSegment(
              value: method,
              label: Text(method.label),
              icon: Icon(
                method == PaymentMethod.cash
                    ? Icons.payments_outlined
                    : Icons.account_balance_outlined,
                size: 18,
              ),
            ),
        ],
        selected: {_method},
        onSelectionChanged: (selection) =>
            setState(() => _method = selection.first),
      ),
      const SizedBox(height: 16),
      DatePickerRow(
        date: _date,
        onChanged: (date) => setState(() => _date = date),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _note,
        maxLength: 100,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Note (optional)',
          hintText: 'e.g. Weekly settlement',
          counterText: '',
        ),
      ),
      const SizedBox(height: 24),
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
        child: const Text('Save payment'),
      ),
    ],
  );
}

class StaffPayoutForm extends StatefulWidget {
  const StaffPayoutForm({
    super.key,
    required this.employee,
    this.suggestedAmount = 0,
  });

  final String employee;
  final double suggestedAmount;

  @override
  State<StaffPayoutForm> createState() => _StaffPayoutFormState();
}

class _StaffPayoutFormState extends State<StaffPayoutForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount = TextEditingController(
    text: widget.suggestedAmount > 0.005 ? _plain(widget.suggestedAmount) : '',
  );
  final _note = TextEditingController();
  late String _employee = widget.employee;
  PaymentMethod _method = PaymentMethod.cash;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SheetForm(
    formKey: _formKey,
    title: 'Pay staff',
    subtitle: 'Record money given to an employee for their incentives.',
    children: [
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final name in staffMembers)
              ButtonSegment(value: name, label: Text(name)),
          ],
          selected: {_employee},
          onSelectionChanged: (selection) =>
              setState(() => _employee = selection.first),
        ),
      ),
      const SizedBox(height: 16),
      priceField(_amount, 'Amount paid', allowZero: false),
      const SizedBox(height: 16),
      SegmentedButton<PaymentMethod>(
        showSelectedIcon: false,
        segments: [
          for (final method in PaymentMethod.values)
            ButtonSegment(value: method, label: Text(method.label)),
        ],
        selected: {_method},
        onSelectionChanged: (selection) =>
            setState(() => _method = selection.first),
      ),
      const SizedBox(height: 16),
      DatePickerRow(
        date: _date,
        onChanged: (date) => setState(() => _date = date),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _note,
        maxLength: 100,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Note (optional)',
          hintText: 'e.g. Weekly incentive',
          counterText: '',
        ),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            StaffPayout(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              employee: _employee,
              amount: double.parse(_amount.text),
              method: _method,
              date: _date,
              note: _note.text.trim(),
            ),
          );
        },
        child: const Text('Save payout'),
      ),
    ],
  );
}

/// Formats an amount for a text field: 15 → "15", 16.666 → "16.67".
String _plain(double value) {
  final rounded = (value * 100).round() / 100;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(2);
}

/// Input-styled button: white, bordered, left aligned.
class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.onPressed,
    required this.leading,
    required this.label,
    this.caption,
    this.trailing,
  });

  final VoidCallback onPressed;
  final Widget leading;
  final String label;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.rowTitle,
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 2),
                    Text(caption!, style: AppText.caption),
                  ],
                ],
              ),
            ),
            ?trailing,
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
  Widget build(BuildContext context) => _FieldButton(
    onPressed: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (picked != null) onChanged(picked);
    },
    leading: const Icon(Icons.calendar_today_outlined, size: 20),
    label: '$label: ${DateFormat('d MMM yyyy').format(date)}',
    trailing: const Icon(
      Icons.chevron_right_rounded,
      color: AppColors.textFaint,
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
  style: const TextStyle(fontFeatures: tabularFigures),
  decoration: InputDecoration(labelText: label, prefixText: '₹ '),
  onChanged: onChanged,
  validator: (value) {
    final amount = double.tryParse(value ?? '');
    if (amount == null || amount < 0 || (!allowZero && amount == 0)) {
      return 'Enter an amount above zero';
    }
    return null;
  },
);
