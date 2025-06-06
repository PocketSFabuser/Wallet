import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  _ConverterPageState createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  final Map<String, TextEditingController> _controllers = {
    'USD': TextEditingController(),
    'BYN': TextEditingController(),
    'RUB': TextEditingController(),
  };

  final Map<String, double> _exchangeRates = {
    'USD': 0,
    'BYN': 0,
    'RUB': 1,
  };

  bool _isLoading = true;
  String _lastEdited = 'RUB';

  @override
  void initState() {
    super.initState();
    _fetchExchangeRates();
  }

  Future<void> _fetchExchangeRates() async {
    try {
      final response = await http
          .get(Uri.parse('https://www.cbr-xml-daily.ru/daily_json.js'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          // Получаем курс USD (за 1 USD в RUB)
          _exchangeRates['USD'] = data['Valute']['USD']['Value']?.toDouble() ?? 0;

          // Получаем курс BYN (за 1 BYN в RUB)
          _exchangeRates['BYN'] = data['Valute']['BYN']['Value']?.toDouble() ?? 0;

          _isLoading = false;
          _updateAllValues(_controllers['RUB']!.text);
        });
      } else {
        _showError('Ошибка загрузки курсов: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Ошибка подключения: $e');
    }
  }

  void _updateAllValues(String value) {
    if (value.isEmpty) {
      _controllers['USD']!.text = '';
      _controllers['BYN']!.text = '';
      _controllers['RUB']!.text = '';
      return;
    }

    final double rubValue = double.tryParse(value) ?? 0;

    setState(() {
      _controllers['RUB']!.text = rubValue.toStringAsFixed(2);
      _controllers['USD']!.text = (rubValue / _exchangeRates['USD']!).toStringAsFixed(2);
      _controllers['BYN']!.text = (rubValue / _exchangeRates['BYN']!).toStringAsFixed(2);
    });
  }

  void _onValueChanged(String currency, String value) {
    if (_isLoading) return;

    _lastEdited = currency;

    if (value.isEmpty) {
      for (var controller in _controllers.values) {
        controller.text = '';
      }
      return;
    }

    final double? inputValue = double.tryParse(value);
    if (inputValue == null) return;

    double rubValue = 0;

    if (currency == 'RUB') {
      rubValue = inputValue;
    } else {
      rubValue = inputValue * _exchangeRates[currency]!;
    }

    _updateAllValues(rubValue.toString());
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );

    setState(() {
      _isLoading = false;
    });
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
            _buildCurrencyField('RUB', '₽'),
            _buildCurrencyField('USD', '\$'),
            _buildCurrencyField('BYN', 'Br'),
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

  Widget _buildCurrencyField(String currency, String symbol) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextField(
        controller: _controllers[currency],
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: currency,
          suffixText: symbol,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
        ),
        style: const TextStyle(fontSize: 18),
        onChanged: (value) => _onValueChanged(currency, value),
      ),
    );
  }
}