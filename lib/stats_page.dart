import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'models.dart';

class StatsPage extends StatefulWidget {
  final List<Transaction> transactions;

  const StatsPage({super.key, required this.transactions});

  @override
  _StatsPageState createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  DateTime _selectedMonth = DateTime.now();
  Map<ExpenseCategory, double> _categoryTotals = {};

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  void _calculateStats() {
    final filteredTransactions = widget.transactions.where((t) =>
    t.type == 'expense' &&
        t.date.month == _selectedMonth.month &&
        t.date.year == _selectedMonth.year);

    final grouped = groupBy(filteredTransactions, (t) => t.category);

    _categoryTotals = {
      for (var category in ExpenseCategory.values)
        category: grouped[category]?.fold(
            0.0,
                (sum, t) =>
            sum! + (t.currency == 'USD' ? t.amount * 3.0 : t.amount)) ??
            0.0
    };

    _categoryTotals.removeWhere((key, value) => value == 0);
  }

  void _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.day,
      helpText: 'Выберите месяц',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
      fieldLabelText: 'Месяц',
      fieldHintText: 'Месяц/Год',
    );

    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = picked;
        _calculateStats();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalExpenses = _categoryTotals.values.fold(0.0, (sum, value) => sum + value);
    final usdTotal = totalExpenses / 3.0;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('Статистика расходов'),
        backgroundColor: const Color(0xFF2A2A2A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: const Color(0xFF2A2A2A),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Ваша статистика расходов за:',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _selectMonth(context),
                      child: Text(
                        DateFormat('MMMM yyyy').format(_selectedMonth),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFF2A2A2A),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'За ${DateFormat('MMMM').format(_selectedMonth)} ваши траты составили:',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${totalExpenses.toStringAsFixed(2)} BYN',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '≈ ${usdTotal.toStringAsFixed(2)} USD',
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                color: const Color(0xFF2A2A2A),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _categoryTotals.isEmpty
                      ? const Center(
                    child: Text('Нет данных за выбранный месяц'),
                  )
                      : Column(
                    children: [
                      const Text(
                        'Распределение расходов',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sections: _getSections(),
                            centerSpaceRadius: 40,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          children: _buildCategoryList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _getSections() {
    final totalExpenses = _categoryTotals.values.fold(0.0, (sum, value) => sum + value);
    if (totalExpenses == 0) return [];

    return _categoryTotals.entries.map((entry) {
      final percentage = (entry.value / totalExpenses * 100).round();

      return PieChartSectionData(
        color: _getCategoryColor(entry.key),
        value: percentage.toDouble(),
        title: '$percentage%',
        radius: 40,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  List<Widget> _buildCategoryList() {
    final totalExpenses = _categoryTotals.values.fold(0.0, (sum, value) => sum + value);

    return _categoryTotals.entries.map((entry) {
      final percentage = (entry.value / totalExpenses * 100).round();

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(entry.key.icon, color: _getCategoryColor(entry.key)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(entry.key.name),
            ),
            Text(
              '${entry.value.toStringAsFixed(2)} BYN',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text(
              '$percentage%',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Color _getCategoryColor(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.entertainment:
        return Colors.purple;
      case ExpenseCategory.shopping:
        return Colors.blue;
      case ExpenseCategory.clothes:
        return Colors.green;
      case ExpenseCategory.sports:
        return Colors.orange;
      case ExpenseCategory.education:
        return Colors.red;
    }
  }
}