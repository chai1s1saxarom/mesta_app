import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'welcome_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Ключ для управления формой
  final _formKey = GlobalKey<FormState>();
  
  // Контроллеры для полей ввода
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _passportSeriesNumberController = TextEditingController();
  final TextEditingController _passportIssuedByController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Маска для серии и номера паспорта (формат: 1234 567890)
  final MaskTextInputFormatter _passportMaskFormatter = MaskTextInputFormatter(
    mask: '#### ######',
    filter: {"#": RegExp(r'[0-9]')},
  );

  // Трансформатор для автоматического перевода в верхний регистр
  final TextInputFormatter _upperCaseFormatter = TextInputFormatter.withFunction(
    (oldValue, newValue) {
      return newValue.copyWith(text: newValue.text.toUpperCase());
    },
  );

  // Переменная для отслеживания состояния загрузки
  bool _isLoading = false;

  // Функция для сохранения данных в Firebase
  Future<void> _registerUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Получаем экземпляр Firestore
        final FirebaseFirestore firestore = FirebaseFirestore.instance;

        // Создаем объект с данными пользователя
        Map<String, dynamic> userData = {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'middleName': _middleNameController.text.trim(),
          'passportSeriesNumber': _passportSeriesNumberController.text.trim(),
          'passportIssuedBy': _passportIssuedByController.text.trim(),
          'email': _emailController.text.trim().toLowerCase(),
          'password': _passwordController.text, // В реальном приложении пароль нужно хэшировать!
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Сохраняем данные в коллекции 'users'
        await firestore.collection('users').add(userData);

        // Показываем сообщение об успехе
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Регистрация завершена успешно!'),
            backgroundColor: Colors.green,
          ),
        );

        // Переходим на экран приветствия
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );

      } catch (e) {
        // Обрабатываем ошибки
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка регистрации: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      // Есть ошибки валидации
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, заполните все поля корректно'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passportSeriesNumberController.dispose();
    _passportIssuedByController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Регистрация'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Поле имени
                TextFormField(
                  controller: _firstNameController,
                  validator: (value) {
                    if (value!.isEmpty) return 'Поле обязательно';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: 'Имя',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Поле фамилия
                TextFormField(
                  controller: _lastNameController,
                  validator: (value) {
                    if (value!.isEmpty) return 'Поле обязательно';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: 'Фамилия',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Поле отчество
                TextFormField(
                  controller: _middleNameController,
                  decoration: InputDecoration(
                    labelText: 'Отчество (необязательно)',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Поле серия и номер паспорта с маской
                TextFormField(
                  controller: _passportSeriesNumberController,
                  inputFormatters: [_passportMaskFormatter],
                  validator: (value) {
                    if (value!.isEmpty) return 'Введите серию и номер паспорта';
                    if (value.length != 11 || !value.contains(' ')) {
                      return 'Формат: 1234 567890';
                    }
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: 'Серия и номер паспорта',
                    hintText: '1234 567890',
                    prefixIcon: const Icon(Icons.credit_card),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),

                // Поле "Кем выдан" с автоматическим верхним регистром
                TextFormField(
                  controller: _passportIssuedByController,
                  inputFormatters: [_upperCaseFormatter],
                  validator: (value) {
                    if (value!.isEmpty) return 'Введите кем выдан паспорт';
                    if (value.length < 5) return 'Введите полное название организации';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Кем выдан паспорт',
                    hintText: 'ОУФМС РОССИИ ПО ГОРОДУ МОСКВЕ',
                    prefixIcon: const Icon(Icons.assignment),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignLabelWithHint: true,
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 20),

                // Поле email
                TextFormField(
                  controller: _emailController,
                  validator: (value) {
                    if (value!.isEmpty) return 'Поле обязательно';
                    if (!value.contains('@')) return 'Введите корректный email';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                
                // Поле пароля
                TextFormField(
                  controller: _passwordController,
                  validator: (value) {
                    if (value!.isEmpty) return 'Поле обязательно';
                    if (value.length < 6) return 'Пароль должен быть не менее 6 символов';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Подтверждение пароля
                TextFormField(
                  controller: _confirmPasswordController,
                  validator: (value) {
                    if (value!.isEmpty) return 'Поле обязательно';
                    if (value != _passwordController.text) {
                      return 'Пароли не совпадают';
                    }
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Подтвердите пароль',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                
                // Кнопка регистрации
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Зарегистрироваться',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Условия использования
                const Text(
                  'Нажимая "Зарегистрироваться", вы принимаете условия использования',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}