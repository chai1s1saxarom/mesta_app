import 'package:flutter/material.dart';
import 'welcome_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'edit_profile_screen.dart';

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
    return SingleChildScrollView(  // ДОБАВЛЕНО
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
          const SizedBox(height: 20),  // Добавлен отступ внизу для скролла
        ],
      ),
    );
  }

// Вкладка личного кабинета
Widget _buildPersonalCabinetTab() {
  final userId = FirebaseAuth.instance.currentUser?.uid;

  if (userId == null) {
    return const Center(child: Text('Пользователь не авторизован'));
  }

  final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId);
  
  return StreamBuilder<DocumentSnapshot>(
    stream: userDocRef.snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      if (snapshot.hasError) {
        return Center(child: Text('Ошибка: ${snapshot.error}'));
      }

      if (!snapshot.hasData || !snapshot.data!.exists) {
        return const Center(child: Text('Данные пользователя не найдены'));
      }

      final userData = snapshot.data!.data() as Map<String, dynamic>;
      
      // Форматирование даты
      String formatTimestamp(dynamic timestamp) {
        if (timestamp == null) return 'Дата не указана';
        try {
          if (timestamp is Timestamp) {
            return DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate());
          }
          return timestamp.toString();
        } catch (e) {
          return 'Ошибка формата даты';
        }
      }

      // Получаем все данные
      final userEmail = userData['email'] ?? 'Не указан';
      final userPhone = userData['telephone'] ?? 'Не указан';
      final firstName = userData['firstName'] ?? 'Не указано';
      final lastName = userData['lastName'] ?? 'Не указано';
      final middleName = userData['middleName'] ?? 'Не указано';
      final passportSeries = userData['passportSeriesNumber'] ?? 'Не указаны';
      final passportIssuedBy = userData['passportIssuedBy'] ?? 'Не указано';
      final regDate = formatTimestamp(userData['createdAt']);
      final updatedDate = formatTimestamp(userData['updatedAt']);

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок и аватар
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '$lastName $firstName ${middleName.isNotEmpty ? middleName : ''}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    userEmail,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            // Основная информация
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Контактная информация',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildInfoRow(Icons.phone, 'Телефон', userPhone),
                    _buildInfoRow(Icons.email, 'Email', userEmail),
                    _buildInfoRow(Icons.person, 'ФИО', 
                        '$lastName $firstName ${middleName.isNotEmpty ? middleName : ''}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Паспортные данные
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Паспортные данные',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildInfoRow(Icons.credit_card, 'Серия и номер', passportSeries),
                    _buildInfoRow(Icons.account_balance, 'Кем выдан', passportIssuedBy),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Системная информация
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Системная информация',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildInfoRow(Icons.calendar_today, 'Дата регистрации', regDate),
                    _buildInfoRow(Icons.update, 'Последнее обновление', updatedDate),
                    _buildInfoRow(Icons.verified_user, 'Роль', userData['role'] ?? 'user'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Кнопки действий
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(userData: userData),
                        ),
                      ).then((updated) {
                        if (updated == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Профиль успешно обновлен')),
                          );
                        }
                      });
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Редактировать профиль'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Выход из системы
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                        (Route<dynamic> route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Выйти из аккаунта'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      );
    },
  );
}

// Вспомогательный метод для отображения строки информации
Widget _buildInfoRow(IconData icon, String title, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blueGrey, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  // Вкладка записи на выставку
  Widget _buildExhibitionTab() {
    return SingleChildScrollView(  
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
          const SizedBox(height: 20),  // Добавлен отступ внизу для скролла
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