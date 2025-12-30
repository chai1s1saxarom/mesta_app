import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'welcome_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passportSeriesNumberController = TextEditingController();
  final _passportIssuedByController = TextEditingController();
  final _emailController = TextEditingController();
  final _telephoneController = TextEditingController();

  final _passportMaskFormatter = MaskTextInputFormatter(
    mask: '#### ######', filter: {"#": RegExp(r'[0-9]')});
  
  final _telephoneMaskFormatter = MaskTextInputFormatter(
    mask: '+7 ### ### ## ##', filter: {"#": RegExp(r'[0-9]')});

  final _upperCaseFormatter = TextInputFormatter.withFunction(
    (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()));

  bool _isLoading = false;

  Future<void> _registerUser() async {
  if (!_formKey.currentState!.validate()) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Пожалуйста, заполните все поля корректно'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }


    setState(() => _isLoading = true);

    try {
    
    // 1. Создаем пользователя в Firebase Auth
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    final user = userCredential.user!;

    // 2. Сохраняем в Firestore
    final userData = {
      'userId': user.uid,
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'middleName': _middleNameController.text.trim(),
      'passportSeriesNumber': _passportSeriesNumberController.text.trim(),
      'passportIssuedBy': _passportIssuedByController.text.trim(),
      'telephone': _telephoneController.text.trim(),
      'email': _emailController.text.trim().toLowerCase(),
      'emailVerified': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'role': 'user',
    };
    
    await _firestore.collection('users').doc(user.uid).set(userData);
    _showSuccessDialog();

  } on FirebaseAuthException catch (e) {
    _showErrorDialog(e);
  } on FirebaseException catch (e) {
    _showErrorDialog(e);
  } catch (e, stack) {
    _showErrorDialog(Exception('Ошибка: $e'));
  } finally {
    setState(() => _isLoading = false);
  }
}

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Регистрация успешна!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                (route) => false,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(dynamic error) {
    String errorMessage = 'Произошла ошибка при регистрации';
    
    if (error is FirebaseAuthException) {
      errorMessage = switch (error.code) {
        'email-already-in-use' => 'Этот email уже используется',
        'invalid-email' => 'Некорректный формат email',
        'operation-not-allowed' => 'Регистрация временно отключена',
        'weak-password' => 'Пароль слишком слабый (минимум 6 символов)',
        'network-request-failed' => 'Проблема с интернет-соединением',
        _ => 'Ошибка: ${error.message}',
      };
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ошибка регистрации'),
        content: Text(errorMessage),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    List<TextInputFormatter>? formatters,
    bool obscureText = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      inputFormatters: formatters,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
    _telephoneController.dispose();
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
                _buildTextField(
                  controller: _firstNameController,
                  label: 'Имя',
                  icon: Icons.person,
                  validator: (v) => v?.isEmpty ?? true ? 'Поле обязательно' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _lastNameController,
                  label: 'Фамилия',
                  icon: Icons.person,
                  validator: (v) => v?.isEmpty ?? true ? 'Поле обязательно' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _middleNameController,
                  label: 'Отчество (при наличии)',
                  icon: Icons.person,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _telephoneController,
                  label: 'Номер телефона',
                  icon: Icons.phone,
                  formatters: [_telephoneMaskFormatter],
                  keyboardType: TextInputType.phone,
                  hint: '+7 999 123 45 67',
                  validator: (v) => v?.length != 16 ? 'Введите корректный номер' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _passportSeriesNumberController,
                  label: 'Серия и номер паспорта',
                  icon: Icons.credit_card,
                  formatters: [_passportMaskFormatter],
                  keyboardType: TextInputType.number,
                  hint: '1234 567890',
                  validator: (v) => v?.length != 11 ? 'Формат: 1234 567890' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _passportIssuedByController,
                  label: 'Кем выдан паспорт',
                  icon: Icons.assignment,
                  formatters: [_upperCaseFormatter],
                  maxLines: 2,
                  hint: 'ОУФМС РОССИИ ПО ГОРОДУ МОСКВЕ',
                  validator: (v) => v != null && v.length < 5 ? 'Введите полное название' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v ?? '') 
                      ? 'Введите корректный email' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _passwordController,
                  label: 'Пароль',
                  icon: Icons.lock,
                  obscureText: true,
                  validator: (v) => v != null && v.length < 6 ? 'Не менее 6 символов' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _confirmPasswordController,
                  label: 'Подтвердите пароль',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  validator: (v) => v != _passwordController.text ? 'Пароли не совпадают' : null,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Зарегистрироваться', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Нажимая "Зарегистрироваться", вы принимаете условия использования',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}