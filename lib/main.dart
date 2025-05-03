import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мой кошелёк',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      ),
      home: const MyHomePage(),
    );
  }
}

// Enum для категорий расходов с иконками
enum ExpenseCategory {
  entertainment('Развлечения', Icons.movie),
  shopping('Магазин', Icons.shopping_cart),
  clothes('Одежда', Icons.checkroom),
  sports('Спорт', Icons.sports_soccer),
  education('Образование', Icons.school);

  final String name;
  final IconData icon;

  const ExpenseCategory(this.name, this.icon);
}

class Transaction {
  final String type;
  final double amount;
  final DateTime date;
  final String description;
  final String? target;
  final String currency;
  final ExpenseCategory? category;

  Transaction({
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    required this.currency,
    this.target,
    this.category,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'amount': amount,
    'date': date.toIso8601String(),
    'description': description,
    'target': target,
    'currency': currency,
    'category': category?.name,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    type: json['type'],
    amount: json['amount'],
    date: DateTime.parse(json['date']),
    description: json['description'],
    target: json['target'],
    currency: json['currency'] ?? 'BYN',
    category: json['category'] != null
        ? ExpenseCategory.values.firstWhere(
            (e) => e.name == json['category'],
        orElse: () => ExpenseCategory.entertainment)
        : null,
  );
}

class PiggyBank {
  final String name;
  final double currentAmount;
  final double targetAmount;
  final Color color;

  PiggyBank({
    required this.name,
    required this.currentAmount,
    required this.targetAmount,
    this.color = Colors.blue,
  });

  double get progress => currentAmount / targetAmount;

  Map<String, dynamic> toJson() => {
    'name': name,
    'currentAmount': currentAmount,
    'targetAmount': targetAmount,
    'color': color.value,
  };

  factory PiggyBank.fromJson(Map<String, dynamic> json) => PiggyBank(
    name: json['name'],
    currentAmount: json['currentAmount'],
    targetAmount: json['targetAmount'],
    color: Color(json['color']),
  );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _bankTargetController = TextEditingController();

  List<Transaction> _transactions = [];
  List<PiggyBank> _piggyBanks = [];
  double _balance = 0;
  double _usdBalance = 0;
  String? _selectedBank;
  String? _selectedCurrency;
  ExpenseCategory? _selectedCategory;
  late final AnimationController _progressController;
  final Map<String, Animation<double>> _bankAnimations = {};
  final double _exchangeRate = 3.0;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _loadData();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _amountController.dispose();
    _descController.dispose();
    _bankNameController.dispose();
    _bankTargetController.dispose();
    super.dispose();
  }

  double _convertToBYN(double amount, String currency) {
    return currency == 'USD' ? amount * _exchangeRate : amount;
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final transactionsJson = prefs.getStringList('transactions') ?? [];
    setState(() {
      _transactions = transactionsJson
          .map((json) => Transaction.fromJson(jsonDecode(json)))
          .toList();
    });

    final banksJson = prefs.getStringList('piggyBanks') ?? [];
    setState(() {
      _piggyBanks = banksJson
          .map((json) => PiggyBank.fromJson(jsonDecode(json)))
          .toList();

      for (var bank in _piggyBanks) {
        _bankAnimations[bank.name] = Tween<double>(
          begin: 0,
          end: bank.progress,
        ).animate(
          CurvedAnimation(
            parent: _progressController,
            curve: Curves.easeInOut,
          ),
        );
      }
    });

    _calculateBalance();
    _progressController.forward();
  }

  void _calculateBalance() {
    double bynTotal = 0;
    double usdTotal = 0;

    for (var t in _transactions) {
      if (t.target == null) {
        if (t.currency == 'USD') {
          usdTotal += t.type == 'income' ? t.amount : -t.amount;
        } else {
          bynTotal += t.type == 'income' ? t.amount : -t.amount;
        }
      }
    }

    _balance = bynTotal + _convertToBYN(usdTotal, 'USD');
    _usdBalance = usdTotal;
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();

    final transactionsJson = _transactions
        .map((t) => jsonEncode(t.toJson()))
        .toList();
    await prefs.setStringList('transactions', transactionsJson);

    final banksJson = _piggyBanks
        .map((b) => jsonEncode(b.toJson()))
        .toList();
    await prefs.setStringList('piggyBanks', banksJson);
  }

  Widget _buildCurrencyDropdown() {
    return DropdownButton<String>(
      value: _selectedCurrency ?? 'BYN',
      items: ['BYN', 'USD'].map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _selectedCurrency = value);
      },
    );
  }

  void _showTransactionDialog({String? type, bool forBank = false, PiggyBank? bankToDelete}) {
    _selectedCategory = null;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(forBank
            ? (bankToDelete != null ? 'Удалить копилку?' : 'Пополнить копилку')
            : 'Добавить ${type == 'income' ? 'доход' : 'расход'}'),
        content: bankToDelete != null
            ? Text('Вы уверены, что хотите удалить копилку "${bankToDelete.name}"?')
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!forBank || _piggyBanks.isNotEmpty) ...[
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Сумма',
                  suffix: _buildCurrencyDropdown(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: forBank
                      ? 'Комментарий'
                      : (type == 'income'
                      ? 'Комментарий'
                      : 'Комментарий (необязательно)'),
                ),
              ),
              if (type == 'expense') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<ExpenseCategory>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Категория',
                    border: OutlineInputBorder(),
                  ),
                  items: ExpenseCategory.values.map((category) {
                    return DropdownMenuItem<ExpenseCategory>(
                      value: category,
                      child: Row(
                        children: [
                          Icon(category.icon, size: 20),
                          const SizedBox(width: 8),
                          Text(category.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),
              ],
            ],
            if (forBank && _piggyBanks.isNotEmpty && bankToDelete == null)
              DropdownButton<String>(
                value: _selectedBank,
                hint: const Text('Выберите копилку'),
                items: _piggyBanks.map((bank) {
                  return DropdownMenuItem<String>(
                    value: bank.name,
                    child: Text(bank.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBank = value;
                  });
                },
              ),
          ],
        ),
        actions: [
          if (bankToDelete != null) ...[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                _deletePiggyBank(bankToDelete);
                Navigator.pop(ctx);
              },
              child: const Text('Удалить', style: TextStyle(color: Colors.red)),
            ),
          ] else ...[
            if (forBank && _selectedBank != null)
              TextButton(
                onPressed: () {
                  final bank = _piggyBanks.firstWhere((b) => b.name == _selectedBank);
                  _showTransactionDialog(forBank: true, bankToDelete: bank);
                },
                child: const Text('Удалить', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                if (forBank) {
                  _addToBank();
                } else if (type != null) {
                  _addTransaction(type);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Добавить'),
            ),
          ],
        ],
      ),
    );
  }

  void _showNewBankDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Новая копилка'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _bankNameController,
              decoration: const InputDecoration(
                labelText: 'Название копилки',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bankTargetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Целевая сумма',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final target = double.tryParse(_bankTargetController.text);
              if (_bankNameController.text.isNotEmpty && target != null && target > 0) {
                _addPiggyBank(
                  name: _bankNameController.text,
                  targetAmount: target,
                );
                Navigator.pop(ctx);
                _bankNameController.clear();
                _bankTargetController.clear();
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _addTransaction(String type) {
    final amount = double.tryParse(_amountController.text);
    final description = _descController.text.trim();
    final currency = _selectedCurrency ?? 'BYN';

    if (amount == null || amount <= 0) {
      _showError('Введите корректную сумму');
      return;
    }

    final newTransaction = Transaction(
      type: type,
      amount: amount,
      date: DateTime.now(),
      description: description.isNotEmpty ? description :
      (type == 'expense' && _selectedCategory != null
          ? _selectedCategory!.name
          : 'Без описания'),
      currency: currency,
      category: type == 'expense' ? _selectedCategory : null,
    );

    setState(() {
      _transactions.add(newTransaction);
      _calculateBalance();
      _saveData();
      _amountController.clear();
      _descController.clear();
      _selectedCurrency = null;
      _selectedCategory = null;
    });
  }

  void _addToBank() {
    final amount = double.tryParse(_amountController.text);
    final description = _descController.text.trim();
    final bankName = _selectedBank;
    final currency = _selectedCurrency ?? 'BYN';

    if (amount == null || amount <= 0) {
      _showError('Введите корректную сумму');
      return;
    }

    if (bankName == null) {
      _showError('Выберите копилку');
      return;
    }

    final bankIndex = _piggyBanks.indexWhere((b) => b.name == bankName);
    if (bankIndex == -1) return;

    final convertedAmount = currency == 'USD' ? amount * _exchangeRate : amount;
    final oldProgress = _piggyBanks[bankIndex].progress;
    final newProgress = (_piggyBanks[bankIndex].currentAmount + convertedAmount) /
        _piggyBanks[bankIndex].targetAmount;

    final newTransaction = Transaction(
      type: 'bank',
      amount: amount,
      date: DateTime.now(),
      description: description,
      target: bankName,
      currency: currency,
    );

    setState(() {
      _transactions.add(newTransaction);
      _piggyBanks[bankIndex] = PiggyBank(
        name: _piggyBanks[bankIndex].name,
        currentAmount: _piggyBanks[bankIndex].currentAmount + convertedAmount,
        targetAmount: _piggyBanks[bankIndex].targetAmount,
        color: _piggyBanks[bankIndex].color,
      );

      _bankAnimations[bankName] = Tween<double>(
        begin: oldProgress,
        end: newProgress,
      ).animate(
        CurvedAnimation(
          parent: _progressController,
          curve: Curves.easeInOut,
        ),
      );

      _progressController.reset();
      _progressController.forward();

      _saveData();
      _amountController.clear();
      _descController.clear();
      _selectedBank = null;
      _selectedCurrency = null;
    });
  }

  void _addPiggyBank({required String name, required double targetAmount}) {
    setState(() {
      _piggyBanks.add(PiggyBank(
        name: name,
        currentAmount: 0,
        targetAmount: targetAmount,
        color: Colors.primaries[_piggyBanks.length % Colors.primaries.length],
      ));

      _bankAnimations[name] = Tween<double>(
        begin: 0,
        end: 0,
      ).animate(
        CurvedAnimation(
          parent: _progressController,
          curve: Curves.easeInOut,
        ),
      );

      _saveData();
    });
  }

  void _deletePiggyBank(PiggyBank bank) {
    setState(() {
      _piggyBanks.removeWhere((b) => b.name == bank.name);
      _bankAnimations.remove(bank.name);

      _transactions.removeWhere((t) => t.target == bank.name);
      _calculateBalance();
      _saveData();
    });
  }

  void _deleteTransaction(int index) {
    final transaction = _transactions[index];

    if (transaction.target != null) {
      final bankIndex = _piggyBanks.indexWhere((b) => b.name == transaction.target);
      if (bankIndex != -1) {
        final convertedAmount = transaction.currency == 'USD'
            ? transaction.amount * _exchangeRate
            : transaction.amount;

        final oldProgress = _piggyBanks[bankIndex].progress;
        final newProgress = (_piggyBanks[bankIndex].currentAmount - convertedAmount) /
            _piggyBanks[bankIndex].targetAmount;

        _piggyBanks[bankIndex] = PiggyBank(
          name: _piggyBanks[bankIndex].name,
          currentAmount: _piggyBanks[bankIndex].currentAmount - convertedAmount,
          targetAmount: _piggyBanks[bankIndex].targetAmount,
          color: _piggyBanks[bankIndex].color,
        );

        _bankAnimations[transaction.target!] = Tween<double>(
          begin: oldProgress,
          end: newProgress,
        ).animate(
          CurvedAnimation(
            parent: _progressController,
            curve: Curves.easeInOut,
          ),
        );

        _progressController.reset();
        _progressController.forward();
      }
    }

    setState(() {
      _transactions.removeAt(index);
      _calculateBalance();
      _saveData();
    });
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTransactionDialog(int index) {
    final transaction = _transactions[index];
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Удалить транзакцию?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              transaction.description,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '${transaction.type == 'expense' ? '-' : '+'}${transaction.amount.toStringAsFixed(2)} ${transaction.currency}',
              style: TextStyle(
                color: transaction.type == 'income' ? Colors.green : Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (transaction.currency != 'BYN')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '≈ ${_convertToBYN(transaction.amount, transaction.currency).toStringAsFixed(2)} BYN',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (transaction.target != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Копилка: ${transaction.target}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            if (transaction.category != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(transaction.category!.icon, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      transaction.category!.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              _deleteTransaction(index);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Транзакция удалена'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPiggyBank(PiggyBank bank) {
    return GestureDetector(
      onTap: () {
        _selectedBank = bank.name;
        _showTransactionDialog(forBank: true);
      },
      child: Card(
        color: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    final animation = _bankAnimations[bank.name] ??
                        AlwaysStoppedAnimation(0.0);
                    return CircularProgressIndicator(
                      value: animation.value,
                      backgroundColor: Colors.grey[800],
                      color: bank.color,
                      strokeWidth: 12,
                    );
                  },
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    bank.name,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${bank.currentAmount.toStringAsFixed(2)} BYN',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'из ${bank.targetAmount.toStringAsFixed(2)} BYN',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Transaction t) {
    final index = _transactions.indexOf(t);
    Color? leadingColor;
    String typeText = '';
    String amountPrefix = '';

    if (t.type == 'income') {
      leadingColor = Colors.green;
      typeText = 'Доход';
      amountPrefix = '+';
    } else if (t.type == 'expense') {
      leadingColor = Colors.red;
      typeText = 'Расход';
      amountPrefix = '-';
    } else if (t.type == 'bank') {
      leadingColor = Colors.amber;
      typeText = 'Копилка: ${t.target}';
      amountPrefix = '+';
    }

    return Dismissible(
      key: Key(t.date.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        _showDeleteTransactionDialog(index);
        return false;
      },
      child: Card(
        color: const Color(0xFF2A2A2A),
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (t.category != null)
                Icon(t.category!.icon, color: leadingColor),
              if (t.category == null)
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: leadingColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
          title: Text(t.description),
          subtitle: Text('${t.date.day}.${t.date.month}.${t.date.year} - $typeText${t.category != null ? ' (${t.category!.name})' : ''}'),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$amountPrefix${t.amount.toStringAsFixed(2)} ${t.currency}',
                style: TextStyle(
                  color: leadingColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (t.currency != 'BYN')
                Text(
                  '≈ ${_convertToBYN(t.amount, t.currency).toStringAsFixed(2)} BYN',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.only(top: statusBarHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: const Color(0xFF2A2A2A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Всего денег:',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[400],
                                ),
                              ),
                              Text(
                                '${_balance.toStringAsFixed(2)} BYN',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'В них:',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[400],
                                ),
                              ),
                              Text(
                                '${_usdBalance.toStringAsFixed(2)} \$',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _showNewBankDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF616161),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 24),
                        ),
                        child: const Text('Новая копилка'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              if (_piggyBanks.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 0),
                      child: Text(
                        'Мои копилки',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: _piggyBanks.length,
                      itemBuilder: (ctx, index) {
                        final bank = _piggyBanks[index];
                        return _buildPiggyBank(bank);
                      },
                    ),
                  ],
                ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, top: 8, bottom: 4),
                    child: Text(
                      'История операций',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                  ..._transactions.reversed.map((t) => _buildTransactionItem(t)),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'income',
            onPressed: () => _showTransactionDialog(type: 'income'),
            backgroundColor: Colors.green,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'expense',
            onPressed: () => _showTransactionDialog(type: 'expense'),
            backgroundColor: Colors.red,
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}