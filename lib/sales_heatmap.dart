import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'data.dart';
import 'settings.dart';
import 'theme.dart';
import 'ui.dart';

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

bool dayInRange(DateTime date, DateTimeRange range) {
  final day = salesDay(date);
  return !day.isBefore(salesDay(range.start)) &&
      !day.isAfter(salesDay(range.end));
}

/// Totals for an inclusive range of days.
class RangeSummary {
  RangeSummary(Iterable<Sale> sales, Iterable<Expense> expenses) {
    for (final sale in sales) {
      transactions++;
      units += sale.quantity;
      revenue += sale.revenue;
      buyingCost += sale.totalCost;
      staffIncentives += sale.staffIncentive;
    }
    for (final expense in expenses) {
      otherExpenses += expense.amount;
    }
  }

  int transactions = 0;
  int units = 0;
  double revenue = 0;
  double buyingCost = 0;
  double staffIncentives = 0;
  double otherExpenses = 0;

  double get costs => buyingCost + staffIncentives + otherExpenses;
  double get netProfit => revenue - costs;
  double get myShare => netProfit / 2;
}

RangeSummary summarizeRange(
  Iterable<Sale> sales,
  Iterable<Expense> expenses,
  DateTimeRange range,
) => RangeSummary(
  sales.where((sale) => dayInRange(sale.date, range)),
  expenses.where((expense) => dayInRange(expense.date, range)),
);

/// Month calendar heatmap. Tap a day to filter by it; long-press and drag
/// across days to select a range and see its profit and your 50% share.
class SalesHeatmap extends StatefulWidget {
  const SalesHeatmap({
    super.key,
    required this.sales,
    required this.selectedRange,
    required this.onDaySelected,
    this.onRangeSelected,
    this.expenses = const [],
    this.today,
  });

  final List<Sale> sales;
  final List<Expense> expenses;
  final DateTimeRange? selectedRange;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTimeRange?>? onRangeSelected;
  final DateTime? today;

  @override
  State<SalesHeatmap> createState() => _SalesHeatmapState();
}

class _SalesHeatmapState extends State<SalesHeatmap> {
  static const _levels = [
    AppColors.fill,
    Color(0xFFD7F0DF),
    Color(0xFFA3DDB5),
    Color(0xFF52B57A),
    Color(0xFF1E7A45),
  ];
  static const _gap = 6.0;

  late DateTime _month;
  DateTime? _dragStart;
  DateTime? _dragEnd;

  DateTime get _today => salesDay(widget.today ?? DateTime.now());

  DateTime get _firstMonth {
    var earliest = _today;
    for (final sale in widget.sales) {
      if (sale.date.isBefore(earliest)) earliest = sale.date;
    }
    return DateTime(earliest.year, earliest.month);
  }

  DateTime get _lastMonth => DateTime(_today.year, _today.month);

  @override
  void initState() {
    super.initState();
    final focus = widget.selectedRange?.end ?? _today;
    _month = DateTime(focus.year, focus.month);
  }

  @override
  void didUpdateWidget(SalesHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final range = widget.selectedRange;
    if (range != null && range != oldWidget.selectedRange) {
      _month = DateTime(range.end.year, range.end.month);
    }
  }

  void _haptic() {
    if (appSettings.haptics) HapticFeedback.selectionClick();
  }

  void _changeMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isBefore(_firstMonth) || next.isAfter(_lastMonth)) return;
    _haptic();
    setState(() => _month = next);
  }

  DateTimeRange? get _activeRange {
    if (_dragStart != null && _dragEnd != null) {
      return _dragStart!.isAfter(_dragEnd!)
          ? DateTimeRange(start: _dragEnd!, end: _dragStart!)
          : DateTimeRange(start: _dragStart!, end: _dragEnd!);
    }
    return widget.selectedRange;
  }

  int get _leadingBlanks => _month.weekday - 1; // Monday first.
  int get _daysInMonth => DateUtils.getDaysInMonth(_month.year, _month.month);
  int get _rows => ((_leadingBlanks + _daysInMonth) / 7).ceil();

  DateTime _dayAt(Offset position, double cellWidth, double cellHeight) {
    final col = (position.dx / (cellWidth + _gap)).floor().clamp(0, 6);
    final row = (position.dy / (cellHeight + _gap)).floor().clamp(0, _rows - 1);
    final dayNumber = (row * 7 + col - _leadingBlanks + 1).clamp(
      1,
      _daysInMonth,
    );
    final day = DateTime(_month.year, _month.month, dayNumber);
    return day.isAfter(_today) ? _today : day;
  }

  void _dragTo(DateTime day) {
    if (day == _dragEnd) return;
    _haptic();
    setState(() => _dragEnd = day);
  }

  @override
  Widget build(BuildContext context) {
    final daily = summarizeSalesByDay(widget.sales);
    final monthDays = [
      for (var d = 1; d <= _daysInMonth; d++)
        DateTime(_month.year, _month.month, d),
    ];
    final maxRevenue = monthDays.fold<double>(
      0,
      (best, day) => math.max(best, daily[day]?.revenue ?? 0),
    );
    final monthSummary = summarizeRange(
      widget.sales,
      widget.expenses,
      DateTimeRange(start: monthDays.first, end: monthDays.last),
    );
    final range = _activeRange;
    final canGoBack = _month.isAfter(_firstMonth);
    final canGoForward = _month.isBefore(_lastMonth);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Sales activity', style: AppText.sectionTitle),
          const SizedBox(height: 2),
          const Text(
            'Tap a day for its sales. Long-press and drag to total a range.',
            style: AppText.caption,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: canGoBack ? () => _changeMonth(-1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_month),
                      style: AppText.rowTitle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${money(monthSummary.revenue)} sales · Mine ${money(monthSummary.myShare)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: canGoForward ? () => _changeMonth(1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (index, label) in const [
                'M',
                'T',
                'W',
                'T',
                'F',
                'S',
                'S',
              ].indexed) ...[
                if (index > 0) const SizedBox(width: _gap),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textFaint,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth = (constraints.maxWidth - _gap * 6) / 7;
              final cellHeight = math.min(cellWidth, 44.0);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (details) {
                  final day = _dayAt(
                    details.localPosition,
                    cellWidth,
                    cellHeight,
                  );
                  if (appSettings.haptics) HapticFeedback.mediumImpact();
                  setState(() {
                    _dragStart = day;
                    _dragEnd = day;
                  });
                },
                onLongPressMoveUpdate: (details) => _dragTo(
                  _dayAt(details.localPosition, cellWidth, cellHeight),
                ),
                onLongPressEnd: (_) {
                  final selected = _activeRange;
                  setState(() {
                    _dragStart = null;
                    _dragEnd = null;
                  });
                  if (selected != null) widget.onRangeSelected?.call(selected);
                },
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity.abs() < 250) return;
                  _changeMonth(velocity < 0 ? 1 : -1);
                },
                child: Column(
                  children: [
                    for (var row = 0; row < _rows; row++) ...[
                      if (row > 0) const SizedBox(height: _gap),
                      Row(
                        children: [
                          for (var col = 0; col < 7; col++) ...[
                            if (col > 0) const SizedBox(width: _gap),
                            SizedBox(
                              width: cellWidth,
                              height: cellHeight,
                              child: _cell(
                                row * 7 + col - _leadingBlanks + 1,
                                daily,
                                maxRevenue,
                                range,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Less', style: AppText.caption),
              const SizedBox(width: 6),
              for (final color in _levels)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              const SizedBox(width: 3),
              const Text('More', style: AppText.caption),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: range == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _rangeSummary(range),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _cell(
    int dayNumber,
    Map<DateTime, DailySales> daily,
    double maxRevenue,
    DateTimeRange? range,
  ) {
    if (dayNumber < 1 || dayNumber > _daysInMonth) {
      return const SizedBox.shrink();
    }
    final day = DateTime(_month.year, _month.month, dayNumber);
    final isFuture = day.isAfter(_today);
    final total = daily[day];
    final revenue = total?.revenue ?? 0;
    final level = revenue <= 0 || maxRevenue <= 0
        ? 0
        : 1 + ((revenue / maxRevenue) * 3.999).floor();
    final inRange = range != null && dayInRange(day, range);
    final isToday = day == _today;
    final label = isFuture
        ? DateFormat('d MMM yyyy').format(day)
        : '${DateFormat('d MMM yyyy').format(day)} · ${total?.transactions ?? 0} sales · ${money(revenue)}';

    final cell = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isFuture
            ? Colors.transparent
            : inRange
            ? AppColors.text
            : _levels[level],
        borderRadius: BorderRadius.circular(10),
        border: isToday && !inRange
            ? Border.all(color: AppColors.text, width: 1.5)
            : null,
      ),
      child: Text(
        '$dayNumber',
        style: TextStyle(
          fontSize: 13,
          fontWeight: inRange || isToday ? FontWeight.w600 : FontWeight.w500,
          fontFeatures: tabularFigures,
          color: isFuture
              ? AppColors.textFaint
              : inRange || level >= 3
              ? Colors.white
              : AppColors.text,
        ),
      ),
    );

    if (isFuture) return cell;
    return Semantics(
      label: label,
      button: true,
      selected: inRange,
      child: GestureDetector(
        key: ValueKey('sales-day-${day.toIso8601String()}'),
        onTap: () {
          _haptic();
          widget.onDaySelected(day);
        },
        child: cell,
      ),
    );
  }

  Widget _rangeSummary(DateTimeRange range) {
    final summary = summarizeRange(widget.sales, widget.expenses, range);
    final days = range.end.difference(range.start).inDays + 1;
    final title = days == 1
        ? DateFormat('EEE, d MMM yyyy').format(range.start)
        : '${DateFormat('d MMM').format(range.start)} – ${DateFormat('d MMM yyyy').format(range.end)}';
    final dragging = _dragStart != null;
    final negative = summary.myShare < 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.rowTitle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$days day${days == 1 ? '' : 's'} · ${summary.transactions} sale${summary.transactions == 1 ? '' : 's'} · ${summary.units} item${summary.units == 1 ? '' : 's'}',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              if (!dragging && widget.onRangeSelected != null)
                IconButton(
                  tooltip: 'Clear selection',
                  onPressed: () => widget.onRangeSelected!(null),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(
                  child: MetricBlock(
                    label: 'Sales',
                    value: money(summary.revenue),
                  ),
                ),
                Expanded(
                  child: MetricBlock(
                    label: 'Costs',
                    value: money(summary.costs),
                  ),
                ),
                Expanded(
                  child: MetricBlock(
                    label: 'Net profit',
                    value: money(summary.netProfit),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: negative
                    ? AppColors.negativeSoft
                    : AppColors.positiveSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'My 50% profit',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: negative
                            ? AppColors.negative
                            : AppColors.positive,
                      ),
                    ),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        money(summary.myShare),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                          fontFeatures: tabularFigures,
                          color: negative
                              ? AppColors.negative
                              : AppColors.positive,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
