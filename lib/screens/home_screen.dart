import 'package:flutter/material.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Главная страница'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.payment),
              text: 'Оплата',
            ),
            Tab(
              icon: Icon(Icons.person),
              text: 'Личный кабинет',
            ),
            Tab(
              icon: Icon(Icons.event),
              text: 'Запись на выставку',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Вкладка 1: Система оплаты
          _buildPaymentTab(),
          
          // Вкладка 2: Личный кабинет
          _buildPersonalCabinetTab(),
          
          // Вкладка 3: Запись на выставку
          _buildExhibitionTab(),
        ],
      ),
    );
  }

  // Вкладка оплаты
  Widget _buildPaymentTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Система оплаты',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.credit_card, color: Colors.blue),
                    title: Text('Банковская карта'),
                    subtitle: Text('Оплата картой Visa/Mastercard'),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _showPaymentDialog('Банковская карта');
                      },
                      child: const Text('Оплатить картой'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.phone_android, color: Colors.green),
                    title: Text('Электронный кошелек'),
                    subtitle: Text('Qiwi, YooMoney, WebMoney'),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _showPaymentDialog('Электронный кошелек');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Оплатить электронно'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.account_balance, color: Colors.orange),
                    title: Text('Банковский перевод'),
                    subtitle: Text('Перевод по реквизитам'),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _showPaymentDialog('Банковский перевод');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      child: const Text('Получить реквизиты'),
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

  // Вкладка личного кабинета
  Widget _buildPersonalCabinetTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 20),
          const Text(
            'Личный кабинет',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Добро пожаловать в ваш кабинет!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          
          // Информация о пользователе
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.email),
                    title: Text('Email'),
                    subtitle: Text('user@example.com'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.phone),
                    title: Text('Телефон'),
                    subtitle: Text('+7 (999) 123-45-67'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.calendar_today),
                    title: Text('Дата регистрации'),
                    subtitle: Text('01 января 2024'),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Редактирование профиля
                      },
                      child: const Text('Редактировать профиль'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Кнопка выхода
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.logout),
                  SizedBox(width: 10),
                  Text(
                    'Выйти',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Вкладка записи на выставку
  Widget _buildExhibitionTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Запись на выставку',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Выберите выставку и дату для записи',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 30),
          
          // Выбор выставки
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Выберите выставку:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Выставка',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'art_expo',
                        child: Text('Выставка современного искусства'),
                      ),
                      DropdownMenuItem(
                        value: 'tech_expo',
                        child: Text('Технологическая выставка'),
                      ),
                      DropdownMenuItem(
                        value: 'book_fair',
                        child: Text('Книжная ярмарка'),
                      ),
                    ],
                    onChanged: (value) {
                      // TODO: Обработка выбора выставки
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Выбор даты
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Выберите дату:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Дата посещения',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () {
                      _selectDate(context);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Выбор времени
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Выберите время:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Время',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: '10:00',
                        child: Text('10:00 - 12:00'),
                      ),
                      DropdownMenuItem(
                        value: '12:00',
                        child: Text('12:00 - 14:00'),
                      ),
                      DropdownMenuItem(
                        value: '14:00',
                        child: Text('14:00 - 16:00'),
                      ),
                      DropdownMenuItem(
                        value: '16:00',
                        child: Text('16:00 - 18:00'),
                      ),
                    ],
                    onChanged: (value) {
                      // TODO: Обработка выбора времени
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          
          // Кнопка записи
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                _showRegistrationSuccess(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Записаться на выставку',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Диалог оплаты
  void _showPaymentDialog(String paymentMethod) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Оплата через $paymentMethod'),
          content: const Text('Здесь будет реализована система оплаты.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Оплата через $paymentMethod прошла успешно!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Оплатить'),
            ),
          ],
        );
      },
    );
  }

  // Выбор даты
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2025, 12, 31),
    );
    if (picked != null) {
      // TODO: Обработка выбранной даты
    }
  }

  // Успешная запись
  void _showRegistrationSuccess(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Успешная запись!'),
          content: const Text('Вы успешно записались на выставку. Ждем вас!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}