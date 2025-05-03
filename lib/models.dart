import 'package:flutter/material.dart';

// Enum для категорий расходов с иконками
enum ExpenseCategory {
  entertainment('Развлечения', Icons.movie),
  shopping('Еда', Icons.shopping_cart),
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