import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'data.dart';

DateTime salesDay(DateTime date) => DateTime(date.year, date.month, date.day);

class DailySales {
  int transactions = 0;
  int units = 0;
  double revenue = 0;
  double profit = 0;

  void add(Sale sale) {
    transactions++;
    units += sale.quantity;
    revenue += sale.revenue;
    profit += sale.profit;
  }
}

Map<DateTime, DailySales> summarizeSalesByDay(Iterable<Sale> sales) {
  final days = <DateTime, DailySales>{};
  for (final sale in sales) {
    days.putIfAbsent(salesDay(sale.date), DailySales.new).add(sale);
  }
  return days;
}

class SalesHeatmap extends StatelessWidget {
  const SalesHeatmap({
    super.key,
    required this.sales,
    required this.selectedDay,
    required this.onDaySelected,
    this.today,
  });

  final List<Sale> sales;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final DateTime? today;

  static const _colors = [
    Color(0xFFE9EEF3),
    Color(0xFFDCE9A1),
    Color(0xFFB6D957),
    Color(0xFF85B719),
    Color(0xFF527700),
  ];

  @override
  Widget build(BuildContext context) {
    final currentDay = salesDay(today ?? DateTime.now());
    final thisMonday = currentDay.subtract(
      Duration(days: currentDay.weekday - 1),
    );
    final firstMonday = thisMonday.subtract(const Duration(days: 12 * 7));
    final daily = summarizeSalesByDay(sales);
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Last 13 weeks · Tap a day to see its sales',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 22),
                    for (final label in ['M', '', 'W', '', 'F', '', ''])
                      SizedBox(
                        width: 20,
                        height: 21,
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                  ],
                ),
                for (var week = 0; week < 13; week++)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 17,
                          height: 22,
                          child: Text(
                            () {
                              final monday = firstMonday.add(
                                Duration(days: week * 7),
                              );
                              return week == 0 || monday.day <= 7
                                  ? DateFormat('MMM').format(monday)
                                  : '';
                            }(),
                            softWrap: false,
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        for (var weekday = 0; weekday < 7; weekday++)
                          _dayCell(
                            firstMonday.add(Duration(days: week * 7 + weekday)),
                            currentDay,
                            daily,
                            money,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'Less',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 6),
              for (final color in _colors)
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              const SizedBox(width: 3),
              const Text(
                'More',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(
    DateTime day,
    DateTime currentDay,
    Map<DateTime, DailySales> daily,
    NumberFormat money,
  ) {
    final isFuture = day.isAfter(currentDay);
    final total = daily[day];
    final count = total?.transactions ?? 0;
    final selected = selectedDay != null && salesDay(selectedDay!) == day;
    final color = isFuture ? Colors.transparent : _colors[count.clamp(0, 4)];
    final label = isFuture
        ? DateFormat('d MMM yyyy').format(day)
        : '${DateFormat('d MMM yyyy').format(day)} · $count sale${count == 1 ? '' : 's'} · ${money.format(total?.revenue ?? 0)}';

    return SizedBox(
      width: 17,
      height: 21,
      child: isFuture
          ? const SizedBox.shrink()
          : Tooltip(
              message: label,
              child: Semantics(
                label: label,
                button: true,
                child: InkWell(
                  key: ValueKey('sales-day-${day.toIso8601String()}'),
                  onTap: () => onDaySelected(day),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      border: selected
                          ? Border.all(color: const Color(0xFF0F172A), width: 2)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
