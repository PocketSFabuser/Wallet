import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle; // Добавлен импорт для работы с активами

class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  _ConverterPageState createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, double> _exchangeRates = {'RUB': 1.0};
  List<String> _availableCurrencies = ['RUB'];
  List<String> _selectedCurrencies = ['RUB', 'USD', 'BYN'];
  bool _isLoading = true;
  int _attemptCount = 0;
  final int _maxAttempts = 10;

  @override
  void initState() {
    super.initState();
    // Инициализация контроллеров для начальных валют
    for (var currency in _selectedCurrencies) {
      _controllers[currency] = TextEditingController();
    }
    _fetchExchangeRates();
  }

  Future<void> _fetchExchangeRates() async {
    try {
      final response = await http
          .get(Uri.parse('http://www.cbr-xml-daily.ru/daily_json.js'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _processExchangeData(data);
      } else {
        _handleFetchError('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      _handleFetchError('Ошибка подключения: $e');
    }
  }

  // Общий метод обработки данных JSON
  void _processExchangeData(Map<String, dynamic> data) {
    setState(() {
      // Обрабатываем все валюты из JSON
      Map<String, dynamic> valutes = data['Valute'];
      valutes.forEach((key, value) {
        double nominal = value['Nominal']?.toDouble() ?? 1.0;
        double val = value['Value']?.toDouble() ?? 0.0;
        _exchangeRates[key] = val / nominal;
      });

      // Обновляем список доступных валют
      _availableCurrencies = ['RUB']..addAll(_exchangeRates.keys);
      _availableCurrencies = _availableCurrencies.toSet().toList();

      // Убедимся, что выбранные валюты существуют
      for (int i = 0; i < _selectedCurrencies.length; i++) {
        if (!_exchangeRates.containsKey(_selectedCurrencies[i])) {
          _selectedCurrencies[i] = 'RUB';
        }
      }

      // Инициализируем недостающие контроллеры
      for (var currency in _selectedCurrencies) {
        _controllers.putIfAbsent(
            currency, () => TextEditingController());
      }

      _isLoading = false;
      _updateAllValues();
    });
  }

  // Загрузка данных из локального файла
  Future<void> _loadLocalExchangeRates() async {
    try {
      final String dataString = await rootBundle.loadString('assets/daily_json_fallback.js');
      final data = json.decode(dataString);
      _processExchangeData(data);
    } catch (e) {
      _showError('Ошибка загрузки локальных данных: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleFetchError(String message) {
    _attemptCount++;

    if (_attemptCount >= _maxAttempts) {
      _showError('$message\nНе удалось загрузить данные с сервера.\nИспользуются локальные данные.');
      _loadLocalExchangeRates(); // Загружаем локальные данные
      return;
    }

    _showError('$message\nПопытка $_attemptCount/$_maxAttempts');
    // Повторяем запрос через 2 секунды
    Future.delayed(const Duration(seconds: 2), _fetchExchangeRates);
  }

  void _updateAllValues([String? baseCurrency]) {
    // Если не указана базовая валюта, используем RUB по умолчанию
    baseCurrency ??= 'RUB';
    double? baseValue;

    // Пытаемся получить значение базовой валюты
    if (_controllers[baseCurrency]!.text.isNotEmpty) {
      baseValue = double.tryParse(_controllers[baseCurrency]!.text);
    }

    // Если значение невалидно, сбрасываем все поля
    if (baseValue == null) {
      for (var currency in _selectedCurrencies) {
        _controllers[currency]!.text = '';
      }
      return;
    }

    // Конвертируем значение во все валюты
    for (var currency in _selectedCurrencies) {
      if (currency == baseCurrency) continue;

      double baseRate = _exchangeRates[baseCurrency] ?? 1.0;
      double targetRate = _exchangeRates[currency] ?? 1.0;
      double convertedValue = baseValue! * (baseRate / targetRate);

      _controllers[currency]!.text = convertedValue.toStringAsFixed(2);
    }
  }

  void _onValueChanged(String currency, String value) {
    if (_isLoading) return;

    // Запускаем конвертацию
    _updateAllValues(currency);
  }

  void _onCurrencyChanged(int index, String? newCurrency) {
    if (newCurrency == null || newCurrency == _selectedCurrencies[index]) return;

    setState(() {
      // Удаляем старый контроллер если валюта больше не используется
      String oldCurrency = _selectedCurrencies[index];
      _selectedCurrencies[index] = newCurrency;

      bool isCurrencyStillUsed = _selectedCurrencies.contains(oldCurrency);
      if (!isCurrencyStillUsed) {
        _controllers[oldCurrency]?.dispose();
        _controllers.remove(oldCurrency);
      }

      // Создаем новый контроллер при необходимости
      _controllers.putIfAbsent(
          newCurrency, () => TextEditingController());

      // Обновляем значения
      _updateAllValues();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Конвертер валют'),
        backgroundColor: const Color(0xFF2A2A2A),
      ),
      backgroundColor: const Color(0xFF1E1E1E),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            for (int i = 0; i < _selectedCurrencies.length; i++)
              _buildCurrencyRow(i),
            const SizedBox(height: 20),
            Text(
              'Актуальный курс валют по данным ЦБ РФ',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyRow(int index) {
    final currency = _selectedCurrencies[index];
    final symbol = _getCurrencySymbol(currency);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButton<String>(
              value: currency,
              dropdownColor: const Color(0xFF2A2A2A),
              items: _availableCurrencies
                  .map((curr) => DropdownMenuItem(
                value: curr,
                child: Text(
                  curr,
                  style: const TextStyle(color: Colors.white),
                ),
              ))
                  .toList(),
              onChanged: (newValue) => _onCurrencyChanged(index, newValue),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _controllers[currency],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: symbol,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
              ),
              style: const TextStyle(fontSize: 18, color: Colors.white),
              onChanged: (value) => _onValueChanged(currency, value),
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'BYN':
        return 'Br';
      case 'RUB':
        return '₽';
      case 'EUR':
        return '€';
      case 'CNY':
        return '¥';
      default:
        return '';
    }
  }
}
