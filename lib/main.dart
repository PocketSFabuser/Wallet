import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'stats_page.dart';
import 'models.dart';
import 'converter_page.dart';

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
      initialRoute: '/',
      routes: {
        '/': (context) => const WalletListPage(),
        '/converter': (context) => const ConverterPage(),
      },
    );
  }
}

class Wallet {
  final String id;
  final String name;
  double balance;
  double usdBalance;
  List<Transaction> transactions;
  List<PiggyBank> piggyBanks;
  DateTime createdAt;

  Wallet({
    required this.id,
    required this.name,
    this.balance = 0,
    this.usdBalance = 0,
    this.transactions = const [],
    this.piggyBanks = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'balance': balance,
    'usdBalance': usdBalance,
    'transactions': transactions.map((t) => t.toJson()).toList(),
    'piggyBanks': piggyBanks.map((b) => b.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
    id: json['id'],
    name: json['name'],
    balance: json['balance'],
    usdBalance: json['usdBalance'],
    transactions: (json['transactions'] as List)
        .map((t) => Transaction.fromJson(t))
        .toList(),
    piggyBanks: (json['piggyBanks'] as List)
        .map((b) => PiggyBank.fromJson(b))
        .toList(),
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class WalletListPage extends StatefulWidget {
  const WalletListPage({super.key});

  @override
  State<WalletListPage> createState() => _WalletListPageState();
}

class _WalletListPageState extends State<WalletListPage> {
  final TextEditingController _walletNameController = TextEditingController();
  List<Wallet> _wallets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final walletsJson = prefs.getStringList('wallets') ?? [];

    setState(() {
      _wallets = walletsJson
          .map((json) => Wallet.fromJson(jsonDecode(json)))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final walletsJson = _wallets
        .map((w) => jsonEncode(w.toJson()))
        .toList();
    await prefs.setStringList('wallets', walletsJson);
  }

  void _showAddWalletDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый кошелек'),
        content: TextField(
          controller: _walletNameController,
          decoration: const InputDecoration(
            labelText: 'Название кошелька',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              if (_walletNameController.text.isNotEmpty) {
                _addWallet(_walletNameController.text);
                Navigator.pop(ctx);
                _walletNameController.clear();
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _addWallet(String name) {
    final newWallet = Wallet(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    );

    setState(() {
      _wallets.add(newWallet);
      _saveData();
    });
  }

  Future<void> _deleteWallet(Wallet wallet) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить кошелек?'),
        content: Text('Вы уверены, что хотите удалить кошелек "${wallet.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _wallets.removeWhere((w) => w.id == wallet.id);
        _saveData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои кошельки'),
        actions: [
          IconButton(
            icon: const Icon(Icons.currency_exchange),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConverterPage()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wallets.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Нет кошельков'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showAddWalletDialog,
              child: const Text('Создать кошелек'),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _wallets.length,
        itemBuilder: (context, index) {
          final wallet = _wallets[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF2A2A2A),
            child: ListTile(
              title: Text(
                  wallet.name,
                  style: const TextStyle(fontSize: 18)),
              subtitle: Text(
                '${wallet.balance.toStringAsFixed(2)} BYN | '
                    '${wallet.usdBalance.toStringAsFixed(2)} USD',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteWallet(wallet),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WalletPage(wallet: wallet),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWalletDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class WalletPage extends StatefulWidget {
  final Wallet wallet;

  const WalletPage({super.key, required this.wallet});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> with TickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _bankTargetController = TextEditingController();

  String? _selectedBank;
  String? _selectedCurrency;
  ExpenseCategory? _selectedCategory;
  late final AnimationController _progressController;
  final Map<String, Animation<double>> _bankAnimations = {};
  final double _exchangeRate = 3.0;
  DateTime? _loadTime;
  final Map<String, AnimationController> _bankAppearControllers = {};
  final Map<String, Animation<double>> _bankAppearAnimations = {};
  final Map<String, AnimationController> _transactionAppearControllers = {};
  final Map<String, Animation<double>> _transactionAppearAnimations = {};
  final Map<String, AnimationController> _bankRemoveControllers = {};
  final Map<String, Animation<double>> _bankRemoveAnimations = {};
  final Map<String, AnimationController> _transactionRemoveControllers = {};
  final Map<String, Animation<double>> _transactionRemoveAnimations = {};

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _initAnimations();
  }

  void _initAnimations() {
    for (var bank in widget.wallet.piggyBanks) {
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
    _progressController.forward().then((_) {
      if (mounted) {
        setState(() {
          _loadTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    for (var controller in _bankAppearControllers.values) {
      controller.dispose();
    }
    for (var controller in _transactionAppearControllers.values) {
      controller.dispose();
    }
    for (var controller in _bankRemoveControllers.values) {
      controller.dispose();
    }
    for (var controller in _transactionRemoveControllers.values) {
      controller.dispose();
    }
    _amountController.dispose();
    _descController.dispose();
    _bankNameController.dispose();
    _bankTargetController.dispose();
    super.dispose();
  }

  Future<void> _saveData() async {
    final walletListState = context.findAncestorStateOfType<_WalletListPageState>();
    if (walletListState != null) {
      await walletListState._saveData();
    }
  }

  void _calculateBalance() {
    double bynTotal = 0;
    double usdTotal = 0;

    for (var t in widget.wallet.transactions) {
      if (t.target == null) {
        if (t.currency == 'USD') {
          usdTotal += t.type == 'income' ? t.amount : -t.amount;
        } else {
          bynTotal += t.type == 'income' ? t.amount : -t.amount;
        }
      }
    }

    if (mounted) {
      setState(() {
        widget.wallet.balance = bynTotal + _convertToBYN(usdTotal, 'USD');
        widget.wallet.usdBalance = usdTotal;
      });
    }
  }

  double _convertToBYN(double amount, String currency) {
    return currency == 'USD' ? amount * _exchangeRate : amount;
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

  void _showTransactionDialog({
    String? type,
    bool forBank = false,
    PiggyBank? bankToDelete,
  }) {
    _selectedCategory = null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(forBank
            ? (bankToDelete != null
            ? 'Удалить копилку?'
            : 'Пополнить копилку')
            : 'Добавить ${type == 'income' ? 'доход' : 'расход'}'),
        content: bankToDelete != null
            ? Text('Вы уверены, что хотите удалить копилку "${bankToDelete.name}"?')
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!forBank || widget.wallet.piggyBanks.isNotEmpty) ...[
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
            if (forBank && widget.wallet.piggyBanks.isNotEmpty && bankToDelete == null)
              DropdownButton<String>(
                value: _selectedBank,
                hint: const Text('Выберите копилку'),
                items: widget.wallet.piggyBanks.map((bank) {
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
                  final bank = widget.wallet.piggyBanks.firstWhere((b) => b.name == _selectedBank);
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
      builder: (ctx) => AlertDialog(
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
      description: description.isNotEmpty
          ? description
          : (type == 'expense' && _selectedCategory != null
          ? _selectedCategory!.name
          : 'Без описания'),
      currency: currency,
      category: type == 'expense' ? _selectedCategory : null,
    );

    setState(() {
      widget.wallet.transactions.add(newTransaction);

      final transactionKey = '${newTransaction.date.millisecondsSinceEpoch}_${newTransaction.description}';
      final appearController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      final appearAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: appearController, curve: Curves.easeInOut),
      );

      _transactionAppearControllers[transactionKey] = appearController;
      _transactionAppearAnimations[transactionKey] = appearAnimation;
      appearController.forward();

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

    final bankIndex = widget.wallet.piggyBanks.indexWhere((b) => b.name == bankName);
    if (bankIndex == -1) return;

    final convertedAmount = currency == 'USD' ? amount * _exchangeRate : amount;
    final oldProgress = widget.wallet.piggyBanks[bankIndex].progress;
    final newProgress = (widget.wallet.piggyBanks[bankIndex].currentAmount + convertedAmount) /
        widget.wallet.piggyBanks[bankIndex].targetAmount;

    final newTransaction = Transaction(
      type: 'bank',
      amount: amount,
      date: DateTime.now(),
      description: description,
      target: bankName,
      currency: currency,
    );

    setState(() {
      widget.wallet.transactions.add(newTransaction);
      widget.wallet.piggyBanks[bankIndex] = PiggyBank(
        name: widget.wallet.piggyBanks[bankIndex].name,
        currentAmount: widget.wallet.piggyBanks[bankIndex].currentAmount + convertedAmount,
        targetAmount: widget.wallet.piggyBanks[bankIndex].targetAmount,
        color: widget.wallet.piggyBanks[bankIndex].color,
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

      final transactionKey = '${newTransaction.date.millisecondsSinceEpoch}_${newTransaction.description}';
      final appearController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      final appearAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: appearController, curve: Curves.easeInOut),
      );

      _transactionAppearControllers[transactionKey] = appearController;
      _transactionAppearAnimations[transactionKey] = appearAnimation;
      appearController.forward();

      _progressController.reset();
      _progressController.forward();

      _calculateBalance();
      _saveData();
      _amountController.clear();
      _descController.clear();
      _selectedBank = null;
      _selectedCurrency = null;
    });
  }

  void _addPiggyBank({required String name, required double targetAmount}) {
    final newBank = PiggyBank(
      name: name,
      currentAmount: 0,
      targetAmount: targetAmount,
      color: Colors.primaries[widget.wallet.piggyBanks.length % Colors.primaries.length],
    );

    final appearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    final appearAnimation = CurvedAnimation(
      parent: appearController,
      curve: Curves.easeOutBack,
    );

    setState(() {
      widget.wallet.piggyBanks.add(newBank);
      _bankAppearControllers[name] = appearController;
      _bankAppearAnimations[name] = appearAnimation;

      _bankAnimations[name] = Tween<double>(
        begin: 0,
        end: 0,
      ).animate(
        CurvedAnimation(
          parent: _progressController,
          curve: Curves.easeInOut,
        ),
      );

      appearController.forward();
      _saveData();
    });
  }

  Future<void> _deletePiggyBank(PiggyBank bank) async {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    final animation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );

    setState(() {
      _bankRemoveControllers[bank.name] = controller;
      _bankRemoveAnimations[bank.name] = animation;
    });

    await controller.forward();

    if (mounted) {
      setState(() {
        widget.wallet.piggyBanks.removeWhere((b) => b.name == bank.name);
        _bankAnimations.remove(bank.name);
        _bankAppearControllers.remove(bank.name)?.dispose();
        _bankAppearAnimations.remove(bank.name);
        _bankRemoveControllers.remove(bank.name)?.dispose();
        _bankRemoveAnimations.remove(bank.name);

        widget.wallet.transactions.removeWhere((t) => t.target == bank.name);
        _calculateBalance();
        _saveData();
      });
    }
  }

  Future<void> _deleteTransaction(int index) async {
    final transaction = widget.wallet.transactions[index];
    final transactionKey = '${transaction.date.millisecondsSinceEpoch}_${transaction.description}';

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    final animation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );

    setState(() {
      _transactionRemoveControllers[transactionKey] = controller;
      _transactionRemoveAnimations[transactionKey] = animation;
    });

    await controller.forward();

    if (mounted) {
      setState(() {
        if (transaction.target != null) {
          final bankIndex = widget.wallet.piggyBanks.indexWhere((b) => b.name == transaction.target);
          if (bankIndex != -1) {
            final convertedAmount = transaction.currency == 'USD'
                ? transaction.amount * _exchangeRate
                : transaction.amount;

            final oldProgress = widget.wallet.piggyBanks[bankIndex].progress;
            final newProgress = (widget.wallet.piggyBanks[bankIndex].currentAmount - convertedAmount) /
                widget.wallet.piggyBanks[bankIndex].targetAmount;

            widget.wallet.piggyBanks[bankIndex] = PiggyBank(
              name: widget.wallet.piggyBanks[bankIndex].name,
              currentAmount: widget.wallet.piggyBanks[bankIndex].currentAmount - convertedAmount,
              targetAmount: widget.wallet.piggyBanks[bankIndex].targetAmount,
              color: widget.wallet.piggyBanks[bankIndex].color,
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

        widget.wallet.transactions.removeAt(index);
        _transactionAppearControllers.remove(transactionKey)?.dispose();
        _transactionAppearAnimations.remove(transactionKey);
        _transactionRemoveControllers.remove(transactionKey)?.dispose();
        _transactionRemoveAnimations.remove(transactionKey);
        _calculateBalance();
        _saveData();
      });
    }
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

  Widget _buildPiggyBank(PiggyBank bank) {
    final appearAnimation = _bankAppearAnimations[bank.name];
    final removeAnimation = _bankRemoveAnimations[bank.name];

    if (removeAnimation != null) {
      return AnimatedBuilder(
        animation: removeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: removeAnimation.value,
            child: Transform.scale(
              scale: removeAnimation.value,
              child: _buildPiggyBankContent(bank),
            ),
          );
        },
      );
    }

    if (appearAnimation != null) {
      return AnimatedBuilder(
        animation: appearAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: appearAnimation.value,
            child: Opacity(
              opacity: appearAnimation.value,
              child: _buildPiggyBankContent(bank),
            ),
          );
        },
      );
    }

    return _buildPiggyBankContent(bank);
  }

  Widget _buildPiggyBankContent(PiggyBank bank) {
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
                    final animation = _bankAnimations[bank.name] ?? AlwaysStoppedAnimation(0.0);
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
    final index = widget.wallet.transactions.indexOf(t);
    final transactionKey = '${t.date.millisecondsSinceEpoch}_${t.description}';

    final appearAnimation = _transactionAppearAnimations[transactionKey];
    final removeAnimation = _transactionRemoveAnimations[transactionKey];

    if (removeAnimation != null) {
      return AnimatedBuilder(
        animation: removeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: removeAnimation.value,
            child: Transform.translate(
              offset: Offset((1 - removeAnimation.value) * 100, 0),
              child: _buildTransactionItemContent(t, index),
            ),
          );
        },
      );
    }

    if (appearAnimation != null) {
      return AnimatedBuilder(
        animation: appearAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: appearAnimation.value,
            child: Transform.translate(
              offset: Offset(0, (1 - appearAnimation.value) * 20),
              child: _buildTransactionItemContent(t, index),
            ),
          );
        },
      );
    }

    return _buildTransactionItemContent(t, index);
  }

  Widget _buildTransactionItemContent(Transaction t, int index) {
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
      child: GestureDetector(
        onTap: () => _editTransaction(index),
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
            subtitle: Text(
                '${t.date.day}.${t.date.month}.${t.date.year} - $typeText${t.category != null ? ' (${t.category!.name})' : ''}'),
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
      ),
    );
  }

  void _editTransaction(int index) {
    final transaction = widget.wallet.transactions[index];
    _amountController.text = transaction.amount.toString();
    _descController.text = transaction.description;
    _selectedCurrency = transaction.currency;
    _selectedCategory = transaction.category;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать транзакцию'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              decoration: const InputDecoration(
                labelText: 'Описание',
              ),
            ),
            if (transaction.type == 'expense') ...[
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(_amountController.text);
              final description = _descController.text.trim();
              final currency = _selectedCurrency ?? 'BYN';

              if (amount == null || amount <= 0) {
                _showError('Введите корректную сумму');
                return;
              }

              setState(() {
                widget.wallet.transactions[index] = Transaction(
                  type: transaction.type,
                  amount: amount,
                  date: transaction.date,
                  description: description.isNotEmpty ? description : 'Без описания',
                  currency: currency,
                  category: transaction.type == 'expense' ? _selectedCategory : null,
                  target: transaction.target,
                );
                _calculateBalance();
                _saveData();
                _amountController.clear();
                _descController.clear();
                _selectedCurrency = null;
                _selectedCategory = null;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTransactionDialog(int index) {
    final transaction = widget.wallet.transactions[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.wallet.name),
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: statusBarHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: const Color(0xFF2A2A2A),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
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
                                      '${widget.wallet.balance.toStringAsFixed(2)} BYN',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
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
                                      '${widget.wallet.usdBalance.toStringAsFixed(2)} \$',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _showNewBankDialog,
                            child: const Text('Новая копилка'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (widget.wallet.piggyBanks.isNotEmpty)
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
                          itemCount: widget.wallet.piggyBanks.length,
                          itemBuilder: (ctx, index) {
                            final bank = widget.wallet.piggyBanks[index];
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
                      ...widget.wallet.transactions.reversed.map((t) => _buildTransactionItem(t)),
                      const SizedBox(height: 80),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StatsPage(transactions: widget.wallet.transactions),
                  ),
                );
              },
              child: const Text('Статистика расходов'),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 50),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
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
      ),
    );
  }
}