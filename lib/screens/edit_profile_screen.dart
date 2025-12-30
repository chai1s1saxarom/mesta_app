import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  const EditProfileScreen({Key? key, required this.userData}) : super(key: key);
  
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _passportSeriesNumberController = TextEditingController();
  final _passportIssuedByController = TextEditingController();
  final _telephoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Инициализируем контроллеры текущими значениями
    _firstNameController.text = widget.userData['firstName'] ?? '';
    _lastNameController.text = widget.userData['lastName'] ?? '';
    _middleNameController.text = widget.userData['middleName'] ?? '';
    _passportSeriesNumberController.text = widget.userData['passportSeriesNumber'] ?? '';
    _passportIssuedByController.text = widget.userData['passportIssuedBy'] ?? '';
    _telephoneController.text = widget.userData['telephone'] ?? '';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _passportSeriesNumberController.dispose();
    _passportIssuedByController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final userId = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'middleName': _middleNameController.text.trim(),
          'passportSeriesNumber': _passportSeriesNumberController.text.trim(),
          'passportIssuedBy': _passportIssuedByController.text.trim(),
          'telephone': _telephoneController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        Navigator.pop(context, true); // Возвращаемся с флагом успеха
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактирование профиля'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Поле Email (только для чтения)
            ListTile(
              leading: const Icon(Icons.email, color: Colors.grey),
              title: const Text('Email'),
              subtitle: Text(
                widget.userData['email'] ?? 'Не указан',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const Divider(),
            
            // Имя
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'Имя*',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите имя';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            
            // Фамилия
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Фамилия*',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите фамилию';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            
            // Отчество
            TextFormField(
              controller: _middleNameController,
              decoration: const InputDecoration(
                labelText: 'Отчество',
                prefixIcon: Icon(Icons.person_outlined),
              ),
            ),
            const SizedBox(height: 12),
            
            // Телефон
            TextFormField(
              controller: _telephoneController,
              decoration: const InputDecoration(
                labelText: 'Телефон*',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите номер телефона';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            
            const Text(
              'Паспортные данные',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // Серия и номер паспорта
            TextFormField(
              controller: _passportSeriesNumberController,
              decoration: const InputDecoration(
                labelText: 'Серия и номер паспорта',
                prefixIcon: Icon(Icons.credit_card),
              ),
            ),
            const SizedBox(height: 12),
            
            // Кем выдан паспорт
            TextFormField(
              controller: _passportIssuedByController,
              decoration: const InputDecoration(
                labelText: 'Кем выдан',
                prefixIcon: Icon(Icons.account_balance),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 30),
            
            // Кнопка сохранения
            ElevatedButton(
              onPressed: _isLoading ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Сохранить изменения'),
            ),
            
            // Кнопка отмены
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
          ],
        ),
      ),
    );
  }
}