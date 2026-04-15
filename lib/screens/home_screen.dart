import 'package:flutter/material.dart';
import 'welcome_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'edit_profile_screen.dart';
import 'exhibition_registration_screen.dart'; // Добавлен импорт

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Метод для отображения диалога оплаты
  void _showPaymentDialog(String paymentMethod) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Реквизиты для оплаты: $paymentMethod'),
          content: const Text(
            'Банк: ТОЧКА ПАО БАНКА "ФК ОТКРЫТИЕ"\n'
            'БИК: 044525999\n'
            'Счет: 40702810801500011720\n'
            'ИНН: 7728168971\n'
            'КПП: 770543001\n'
            'Получатель: ООО "ЯРМАРКА"',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
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
            Tab(
              icon: Icon(Icons.notifications),
              text: 'Уведомления',
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
          _buildNotificationsTab(),
        ],
      ),
    );
  }

  // Вкладка оплаты
  Widget _buildPaymentTab() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Пользователь не авторизован'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('registrations')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }

        final registrations = snapshot.data?.docs ?? [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Система оплаты', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              elevation: 3,
              child: ListTile(
                leading: const Icon(Icons.account_balance, color: Colors.orange),
                title: const Text('Банковский перевод'),
                subtitle: const Text('После оплаты прикрепите чек'),
                trailing: TextButton(
                  onPressed: () => _showPaymentDialog('Банковский перевод'),
                  child: const Text('Реквизиты'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...registrations.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = (data['status'] ?? '').toString();
              final canUpload = status == 'pending_payment' || status == 'receipt_rejected';
              return Card(
                child: ListTile(
                  title: Text('Заявка ${doc.id.substring(0, 8)}'),
                  subtitle: Text('Статус: $status\nСумма: ${data['totalAmount'] ?? 0} руб.'),
                  isThreeLine: true,
                  trailing: canUpload
                      ? ElevatedButton(
                          onPressed: () => _uploadReceipt(doc.id),
                          child: const Text('Загрузить чек'),
                        )
                      : Icon(
                          status == 'payment_confirmed' ? Icons.check_circle : Icons.hourglass_bottom,
                          color: status == 'payment_confirmed' ? Colors.green : Colors.blue,
                        ),
                ),
              );
            }),
            if (registrations.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: Text('Нет заявок для оплаты')),
              ),
          ],
        );
      },
    );
  }

  Future<void> _uploadReceipt(String registrationId) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );
      if (picked == null || picked.files.single.bytes == null) return;

      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final file = picked.files.single;
      final extension = (file.extension ?? 'bin').toLowerCase();
      final ref = FirebaseStorage.instance
          .ref()
          .child('receipts')
          .child('${registrationId}_${DateTime.now().millisecondsSinceEpoch}.$extension');

      await ref.putData(file.bytes!);
      final url = await ref.getDownloadURL();

      await _firestore.collection('registrations').doc(registrationId).update({
        'status': 'receipt_uploaded',
        'receiptUrl': url,
        'receiptUploadedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('notifications').add({
        'userId': userId,
        'registrationId': registrationId,
        'type': 'receipt_uploaded',
        'title': 'Чек загружен',
        'message': 'Чек отправлен на проверку модератору.',
        'status': 'unread',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Чек загружен и отправлен на проверку')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки чека: $e')),
        );
      }
    }
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
    return ExhibitionRegistrationTab(
      onPaymentRequired: () {
        // Переключение на вкладку оплаты
        _tabController.animateTo(0);
      },
    );
  }

  Widget _buildNotificationsTab() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Пользователь не авторизован'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('Уведомлений пока нет'));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final date = timestamp != null ? DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate()) : '';
            return ListTile(
              leading: const Icon(Icons.notifications_active),
              title: Text((data['title'] ?? 'Уведомление').toString()),
              subtitle: Text('${data['message'] ?? ''}\n$date'),
              isThreeLine: true,
              onTap: () => docs[index].reference.update({'status': 'read'}),
            );
          },
        );
      },
    );
  }
}