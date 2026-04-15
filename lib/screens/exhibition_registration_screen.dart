import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExhibitionRegistrationTab extends StatefulWidget {
  final VoidCallback onPaymentRequired;
  
  const ExhibitionRegistrationTab({
    super.key,
    required this.onPaymentRequired,
  });

  @override
  State<ExhibitionRegistrationTab> createState() => _ExhibitionRegistrationTabState();
}

class _ExhibitionRegistrationTabState extends State<ExhibitionRegistrationTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Состояние формы
  String? _selectedExhibitionId;
  Exhibition? _selectedExhibition;
  DateTime? _selectedDate;
  Place? _selectedPlace;
  ProductCategory? _selectedCategory;
  bool _isPreviousParticipant = false;
  Place? _previousPlace;
  bool _wantsSamePlace = true;
  
  // Состояние для новой категории (без контроллеров)
  String? _selectedProductType;
  String? _selectedPriceCategory;
  String? _selectedPlaceSize;
  final TextEditingController _commentController = TextEditingController();
  
  // Данные из Firebase
  List<Exhibition> _exhibitions = [];
  List<ProductCategory> _userCategories = [];
  List<Place> _availablePlaces = [];
  List<Place> _suggestedPlaces = [];
  List<String> _productTypes = [];
  
  // Этапы процесса
  int _currentStep = 0;
  final List<Step> _steps = [];
  
  // Флаги загрузки
  bool _isLoading = true;
  bool _isLoadingProductTypes = false;
  bool _isSubmitting = false;
  bool _isPlacesBusy = false;
  List<String> _temporarilyLockedPlaceIds = [];
  static const String _selectionLockDocId = 'current_selection';

  @override
  void initState() {
    super.initState();
    _initializeSteps();
    _loadData();
  }

  @override
  void dispose() {
    _releaseTemporaryLocks();
    _commentController.dispose();
    super.dispose();
  }

  void _initializeSteps() {
    _steps.clear();
    
    _steps.addAll([
      Step(
        title: const Text('Категория товара'),
        content: _buildCategoryStep(),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Выбор выставки'),
        content: _buildExhibitionStep(),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Выбор места'),
        content: _buildPlaceStep(),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Дата выставки'),
        content: _buildDateStep(),
        isActive: _currentStep >= 3,
        state: _currentStep > 3 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Подтверждение'),
        content: _buildConfirmationStep(),
        isActive: _currentStep >= 4,
        state: _currentStep > 4 ? StepState.complete : StepState.indexed,
      ),
    ]);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
        await _loadProductTypes();  // Загружаем типы товаров
        await _loadExhibitions();
        await _checkUserHistory();
        await _loadUserCategories();
    } catch (e) {
        print('Ошибка загрузки данных: $e');
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
    } finally {
        setState(() => _isLoading = false);
    }
    }

  Future<void> _loadProductTypes() async {
    setState(() => _isLoadingProductTypes = true);
    
    List<String> newProductTypes = [];
    
    try {
      final typesSnapshot = await _firestore
          .collection('categories')
          .orderBy('name')
          .get();
      
      
      if (typesSnapshot.docs.isNotEmpty) {
        for (var doc in typesSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name']?.toString();
          
          if (name != null && name.isNotEmpty) {
            newProductTypes.add(name);
          }
        }
        
        newProductTypes.sort();
        
      } 
    } catch (e) {
      print('❌ Ошибка загрузки типов товаров: $e');
    }
    
    // ОДИН setState в конце
    if (mounted) {
      setState(() {
        _productTypes = newProductTypes;
        _isLoadingProductTypes = false;
        print('📋 Установлены типы товаров: $_productTypes');
        _initializeSteps();
      });
    }
  }


  Future<void> _loadExhibitions() async {
    try {
      final now = DateTime.now(); 
      final exhibitionsSnapshot = await _firestore
          .collection('exhibitions')
          .where('startDate', isGreaterThan: now)
          .get();
      
      _exhibitions = exhibitionsSnapshot.docs
          .map((doc) => Exhibition.fromFirestore(doc))
          .toList();
      
      print('Загружено выставок: ${_exhibitions.length}');
    } catch (e) {
      print('Ошибка загрузки выставок: $e');
    }
  }

  Future<void> _checkUserHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      final historySnapshot = await _firestore
          .collection('registrations')
          .where('userId', isEqualTo: user.uid)
          .get();
      
      if (historySnapshot.docs.isNotEmpty) {
        var completedRegistrations = historySnapshot.docs
            .where((doc) {
              final data = doc.data();
              final status = data['status'] as String?;
              return status == 'completed' || status == 'paid';
            })
            .toList();
        
        completedRegistrations.sort((a, b) {
          final aDate = a['createdAt'] as Timestamp?;
          final bDate = b['createdAt'] as Timestamp?;
          if (aDate == null || bDate == null) return 0;
          return bDate.compareTo(aDate);
        });
        
        if (completedRegistrations.isNotEmpty) {
          final previousRegistration = completedRegistrations.first;
          final placeId = previousRegistration['placeId'] as String?;
          final exhibitionId = previousRegistration['exhibitionId'] as String?;
          
          if (placeId != null && exhibitionId != null) {
            final placeDoc = await _firestore
                .collection('exhibitions')
                .doc(exhibitionId)
                .collection('places')
                .doc(placeId)
                .get();
            
            if (placeDoc.exists) {
              setState(() {
                _isPreviousParticipant = true;
                _previousPlace = Place.fromFirestore(placeDoc);
              });
              print('Пользователь был предыдущим участником');
            }
          }
        }
      }
    } catch (e) {
      print('Ошибка проверки истории: $e');
    }
  }

  Future<void> _loadUserCategories() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      final categoriesSnapshot = await _firestore
          .collection('categories')
          .where('assignedUsers', arrayContains: user.uid)
          .get();
      
      _userCategories = categoriesSnapshot.docs
          .map((doc) => ProductCategory.fromFirestore(doc))
          .toList();
      
      print('Загружено категорий пользователя: ${_userCategories.length}');
    } catch (e) {
      print('Ошибка загрузки категорий: $e');
    }
  }

  Future<void> _loadAvailablePlaces() async {
    if (_selectedExhibitionId == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isPlacesBusy = false);

    try {
      await _acquireSelectionLock(user.uid);

      final placesSnapshot = await _firestore
          .collection('exhibitions')
          .doc(_selectedExhibitionId!)
          .collection('places')
          .get();

      _availablePlaces = [];
      _suggestedPlaces = [];

      for (final doc in placesSnapshot.docs) {
        try {
          final data = doc.data();
          final isBooked = data['status'] != 'free';
          final tempLockedBy = data['tempLockedBy'] as String?;
          final tempLockExpiresAt = (data['tempLockExpiresAt'] as Timestamp?)?.toDate();
          final isExpired = tempLockExpiresAt == null || tempLockExpiresAt.isBefore(DateTime.now());

          if (isBooked != 'free') {
            continue;
          }

          if (tempLockedBy != null && tempLockedBy.isNotEmpty && tempLockedBy != user.uid && !isExpired) {
            continue;
          }

          final place = Place.fromFirestore(doc);
          _availablePlaces.add(place);
        } catch (_) {}
      }

      _suggestedPlaces = _getSuggestedPlaces();
      await _lockSuggestedPlaces(user.uid, _suggestedPlaces.map((e) => e.id).toList());

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (e is StateError && e.message.contains('busy_selection')) {
        setState(() {
          _isPlacesBusy = true;
          _availablePlaces = [];
          _suggestedPlaces = [];
        });
        return;
      }

      _availablePlaces = [];
      _suggestedPlaces = [];

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _acquireSelectionLock(String userId) async {
    final lockRef = _firestore
        .collection('exhibitions')
        .doc(_selectedExhibitionId!)
        .collection('selection_locks')
        .doc(_selectionLockDocId);

    await _firestore.runTransaction((transaction) async {
      final lockSnapshot = await transaction.get(lockRef);
      final now = DateTime.now();

      if (lockSnapshot.exists) {
        final data = lockSnapshot.data() as Map<String, dynamic>;
        final lockUserId = data['userId'] as String?;
        final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
        final isActiveLock = expiresAt != null && expiresAt.isAfter(now);
        if (isActiveLock && lockUserId != null && lockUserId != userId) {
          throw StateError('busy_selection');
        }
      }

      transaction.set(lockRef, {
        'userId': userId,
        'expiresAt': Timestamp.fromDate(now.add(const Duration(minutes: 10))),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _lockSuggestedPlaces(String userId, List<String> placeIds) async {
    if (_selectedExhibitionId == null) return;

    final placesRef = _firestore
        .collection('exhibitions')
        .doc(_selectedExhibitionId!)
        .collection('places');

    final batch = _firestore.batch();

    for (final previousId in _temporarilyLockedPlaceIds) {
      if (placeIds.contains(previousId)) continue;
      batch.update(placesRef.doc(previousId), {
        'tempLockedBy': FieldValue.delete(),
        'tempLockExpiresAt': FieldValue.delete(),
      });
    }

    final expiresAt = Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 10)));
    for (final placeId in placeIds) {
      batch.update(placesRef.doc(placeId), {
        'tempLockedBy': userId,
        'tempLockExpiresAt': expiresAt,
      });
    }

    await batch.commit();
    _temporarilyLockedPlaceIds = List<String>.from(placeIds);
  }

  Future<void> _releaseTemporaryLocks({String? keepPlaceId}) async {
    if (_selectedExhibitionId == null || _temporarilyLockedPlaceIds.isEmpty) return;

    final placesRef = _firestore
        .collection('exhibitions')
        .doc(_selectedExhibitionId!)
        .collection('places');
    final batch = _firestore.batch();

    for (final placeId in _temporarilyLockedPlaceIds) {
      if (keepPlaceId != null && keepPlaceId == placeId) continue;
      batch.update(placesRef.doc(placeId), {
        'tempLockedBy': FieldValue.delete(),
        'tempLockExpiresAt': FieldValue.delete(),
      });
    }

    await batch.commit();
    if (keepPlaceId == null) {
      _temporarilyLockedPlaceIds = [];
    } else {
      _temporarilyLockedPlaceIds = [keepPlaceId];
    }
  }

  List<Place> _getSuggestedPlaces() {
    if (_availablePlaces.isEmpty) return [];

    final categoryIds = _userCategories.map((e) => e.categoryId).where((e) => e.isNotEmpty).toSet();
    if (categoryIds.isEmpty) {
      return _availablePlaces.take(4).toList();
    }

    try {
      List<Place> filteredPlaces = _availablePlaces
          .where(
            (place) => categoryIds.every((categoryId) => place.preferredCategoryIds.contains(categoryId)),
          )
          .toList();

      if (filteredPlaces.length < 3) {
        final otherPlaces = _availablePlaces
            .where((place) => !filteredPlaces.any((suitable) => suitable.id == place.id))
            .toList();
        filteredPlaces.addAll(otherPlaces.take(4 - filteredPlaces.length));
      }
      return filteredPlaces.take(4).toList();
    } catch (_) {
      return _availablePlaces.take(4).toList();
    }
  }

  Widget _buildCategoryStep() {
    print('_isLoadingProductTypes: $_isLoadingProductTypes');
    print('_productTypes длина: ${_productTypes.length}');
    print('_productTypes: $_productTypes');
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Категория товара',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            
            if (_isLoadingProductTypes)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              // Выбор существующей категории
              if (_userCategories.isNotEmpty) ...[
                const Text(
                  'Выберите существующую категорию:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ProductCategory>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  isExpanded: true,
                  value: _selectedCategory,
                  items: _userCategories.map((category) {
                    return DropdownMenuItem<ProductCategory>(
                      value: category,
                      child: Text(
                        category.type,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                      _selectedProductType = value?.type;
                    });
                  },
                  hint: const Text('Выберите категорию'),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'или',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Создание новой категории
              const Text(
              'Создать новую категорию:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),

              // Выпадающий список для типа товара
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  labelText: 'Тип товара',
                ),
                isExpanded: true,
                value: _selectedProductType,
                items: _productTypes.isEmpty 
                    ? [DropdownMenuItem<String>(
                        value: null,
                        child: Text('Загрузка типов товаров...'),
                      )]
                    : _productTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(
                            type,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                onChanged: (value) {
                  print('Selected: $value');
                  if (value != null && value.isNotEmpty) {
                    setState(() {
                      _selectedProductType = value;
                      _selectedCategory = null;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, выберите тип товара';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  labelText: 'Ценовая категория *',
                ),
                isExpanded: true,
                value: _selectedPriceCategory,
                items: const [
                  DropdownMenuItem(
                    value: 'Эконом',
                    child: Text('Эконом'),
                  ),
                  DropdownMenuItem(
                    value: 'Стандарт',
                    child: Text('Стандарт'),
                  ),
                  DropdownMenuItem(
                    value: 'Премиум',
                    child: Text('Премиум'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedPriceCategory = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Выберите ценовую категорию';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Предпочтительный размер места
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  labelText: 'Предпочтительный размер места *',
                ),
                isExpanded: true,
                value: _selectedPlaceSize,
                items: const [
                  DropdownMenuItem(
                    value: 'Малое (до 5м²)',
                    child: Text('Малое (до 5м²)'),
                  ),
                  DropdownMenuItem(
                    value: 'Среднее (5-10м²)',
                    child: Text('Среднее (5-10м²)'),
                  ),
                  DropdownMenuItem(
                    value: 'Большое (10+м²)',
                    child: Text('Большое (10+м²)'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedPlaceSize = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Выберите размер места';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Комментарий
              TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  labelText: 'Комментарий',
                  hintText: 'Дополнительная информация о товаре',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: 3,
              ),

              // Кнопка сохранения новой категории
              if (_selectedProductType != null ||
                  _selectedPriceCategory != null ||
                  _selectedPlaceSize != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _saveNewCategory,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Сохранить категорию'),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveNewCategory() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите в систему')),
      );
      return;
    }
    
    if (_selectedProductType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите тип товара')),
      );
      return;
    }
    
    if (_selectedPriceCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите ценовую категорию')),
      );
      return;
    }
    
    if (_selectedPlaceSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите предпочтительный размер места')),
      );
      return;
    }
    
    try {
      final newCategory = ProductCategory(
        id: '',
        type: _selectedProductType!,
        priceCategory: _selectedPriceCategory!,
        preferredSize: _selectedPlaceSize!,
        comment: _commentController.text.isEmpty ? null : _commentController.text,
        userId: user.uid,
        categoryId: '',
      );
      
      final docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('product_categories')
          .add(newCategory.toFirestore());
      
      newCategory.id = docRef.id;
      
      setState(() {
        _selectedCategory = newCategory;
        _userCategories.insert(0, newCategory);
        
        // Очищаем поля
        _selectedProductType = null;
        _selectedPriceCategory = null;
        _selectedPlaceSize = null;
        _commentController.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Категория успешно сохранена'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Ошибка сохранения категории: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка сохранения: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildExhibitionStep() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Выбор выставки',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(14.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_exhibitions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: Text(
                    'Нет доступных выставок',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  labelText: 'Выставка *',
                ),
                isExpanded: true,
                value: _selectedExhibitionId,
                items: _exhibitions.map((exhibition) {
                  return DropdownMenuItem<String>(
                    value: exhibition.id,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exhibition.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                        if (exhibition.startDate != null && exhibition.endDate != null)
                          Text(
                            '${_formatDate(exhibition.startDate!)} - ${_formatDate(exhibition.endDate!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) async {
                  setState(() {
                    _selectedExhibitionId = value;
                    _selectedExhibition = _exhibitions
                        .firstWhere((e) => e.id == value);
                    _availablePlaces.clear();
                    _suggestedPlaces.clear();
                    _selectedPlace = null;
                    _selectedDate = null;
                  });
                  
                  await _loadAvailablePlaces();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Выберите выставку';
                  }
                  return null;
                },
              ),
            
            if (_selectedExhibition != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Информация о записи:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isPreviousParticipant && _wantsSamePlace
                          ? '✅ Для вас запись открыта за 2 месяца до выставки'
                          : '📅 Запись открыта за 1 месяц до выставки',
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (_isPreviousParticipant) ...[
                      const SizedBox(height: 8),
                      Text(
                        '🎉 Вы участвовали в предыдущей выставке',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceStep() {
    if (_selectedExhibitionId == null) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_outlined, size: 50, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Сначала выберите выставку',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _currentStep = 1);
                  },
                  child: const Text('Выбрать выставку'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isPlacesBusy) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const Icon(Icons.lock_clock, size: 44, color: Colors.orange),
              const SizedBox(height: 12),
              const Text(
                'Попробуйте позже, сейчас идет подбор мест.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadAvailablePlaces,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_isPreviousParticipant && _wantsSamePlace && _previousPlace != null) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ваше предыдущее место',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 2,
                color: Colors.green[50],
                child: ListTile(
                  leading: const Icon(Icons.place, color: Colors.green),
                  title: Text('Место ${_previousPlace!.number}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Категории: ${_previousPlace!.categoriesAsString}'),
                      const SizedBox(height: 2),
                      Text('Размер: ${_previousPlace!.size}'),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedPlace = _previousPlace;
                      });
                    },
                    child: const Text('Выбрать'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                title: const Text('Хочу другое место'),
                value: !_wantsSamePlace,
                onChanged: (value) {
                  setState(() {
                    _wantsSamePlace = !value!;
                    _selectedPlace = null;
                  });
                },
                secondary: const Icon(Icons.change_circle_outlined),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_availablePlaces.isEmpty) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 50, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'Нет доступных мест',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Для выставки "${_selectedExhibition?.name ?? ''}" нет свободных мест.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () {
                    _loadAvailablePlaces();
                  },
                  child: const Text('Обновить список мест'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Выберите место',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            
            if (_selectedCategory != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Зарезервированные для вас места (3-4 варианта):',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            
            ..._suggestedPlaces.map((place) {
              final isSelected = _selectedPlace?.id == place.id;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: isSelected ? Colors.blue[50] : null,
                elevation: 2,
                child: ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.place,
                    color: isSelected ? Colors.blue : Colors.grey,
                  ),
                  title: Text(
                    'Место ${place.number}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.blue : Colors.black,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Категории: ${place.categoriesAsString}'),
                      const SizedBox(height: 2),
                      Text('Размер: ${place.size}'),
                      if (place.price != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Цена: ${place.price} руб./день',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Radio<Place>(
                    value: place,
                    groupValue: _selectedPlace,
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() {
                        _selectedPlace = value;
                      });
                      await _releaseTemporaryLocks(keepPlaceId: value.id);
                    },
                  ),
                  onTap: () async {
                    setState(() {
                      _selectedPlace = place;
                    });
                    await _releaseTemporaryLocks(keepPlaceId: place.id);
                  },
                ),
              );
            }).toList(),
            
            if (_availablePlaces.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showAllPlacesDialog();
                    },
                    icon: const Icon(Icons.list, size: 18),
                    label: const Text('Показать все доступные места'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAllPlacesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Все доступные места'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availablePlaces.length,
            itemBuilder: (context, index) {
              final place = _availablePlaces[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.place, color: Colors.blue),
                  title: Text('Место ${place.number}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text('Категории: ${place.categoriesAsString}'),
                      const SizedBox(height: 2),
                      Text('Размер: ${place.size}'),
                      if (place.price != null) ...[
                        const SizedBox(height: 2),
                        Text('Цена: ${place.price} руб./день'),
                      ],
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      setState(() {
                        _selectedPlace = place;
                      });
                      Navigator.pop(context);
                      await _releaseTemporaryLocks(keepPlaceId: place.id);
                    },
                    child: const Text('Выбрать'),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateStep() {
    if (_selectedExhibition == null) {
      return Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 50, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Сначала выберите выставку',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _currentStep = 1);
                  },
                  child: const Text('Выбрать выставку'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    final now = DateTime.now();
    DateTime? earliestDate;
    DateTime? latestDate;
    
    if (_selectedExhibition?.startDate != null) {
      final exhibitionStart = _selectedExhibition!.startDate!;
      
      if (_isPreviousParticipant && _wantsSamePlace && _previousPlace != null) {
        earliestDate = exhibitionStart.subtract(const Duration(days: 60));
      } else {
        earliestDate = exhibitionStart.subtract(const Duration(days: 30));
      }
      
      if (earliestDate.isBefore(now)) {
        earliestDate = now;
      }
      
      latestDate = _selectedExhibition!.endDate ?? now.add(const Duration(days: 90));
    }
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Дата выставки',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedExhibition != null
                        ? 'Выбранная выставка: ${_selectedExhibition!.name}'
                        : 'Выставка не выбрана',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (_selectedExhibition?.startDate != null && _selectedExhibition?.endDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Период проведения: ${_formatDate(_selectedExhibition!.startDate!)} - ${_formatDate(_selectedExhibition!.endDate!)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            GestureDetector(
              onTap: () async {
                print('=== НАЧАЛО ВЫБОРА ДАТЫ ===');
                
                try {
                  // Убедимся, что выставка выбрана
                  if (_selectedExhibition == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Сначала выберите выставку')),
                    );
                    return;
                  }
                  
                  final now = DateTime.now();
                  DateTime firstDate = now;
                  DateTime lastDate = now.add(const Duration(days: 365));
                  
                  // Если у выставки есть даты, используем их
                  if (_selectedExhibition!.startDate != null && 
                      _selectedExhibition!.endDate != null) {
                    firstDate = _selectedExhibition!.startDate!;
                    lastDate = _selectedExhibition!.endDate!;
                    
                    // Проверяем, что firstDate не в прошлом
                    if (firstDate.isBefore(now)) {
                      firstDate = now;
                    }
                  }
                  
                  print('firstDate: $firstDate');
                  print('lastDate: $lastDate');
                  
                  // Проверяем, что firstDate не позже lastDate
                  if (firstDate.isAfter(lastDate)) {
                    print('⚠️  firstDate позже lastDate, меняем местами');
                    final temp = firstDate;
                    firstDate = lastDate;
                    lastDate = temp;
                  }
                  
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? now,
                    firstDate: firstDate,
                    lastDate: lastDate,
                    cancelText: 'Отмена',
                    confirmText: 'Выбрать',
                    helpText: 'Выберите дату посещения',
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: Colors.blue,
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: Colors.black,
                          ),
                          dialogBackgroundColor: Colors.white,
                        ),
                        child: child!,
                      );
                    },
                  );
                  
                  print('Выбрана дата: $date');
                  
                  if (date != null && mounted) {
                    setState(() {
                      _selectedDate = date;
                    });
                  }
                } catch (e, stackTrace) {
                  print('❌ Ошибка при выборе даты: $e');
                  print('StackTrace: $stackTrace');
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка выбора даты: $e')),
                  );
                }
              },
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Дата посещения *',
                    suffixIcon: const Icon(Icons.calendar_today),
                    helperText: 'Нажмите, чтобы выбрать дату',
                    filled: true,
                    fillColor: _selectedDate != null ? Colors.blue[50] : Colors.grey[100],
                  ),
                  controller: TextEditingController(
                    text: _selectedDate != null
                        ? _getWeekday(_selectedDate!)
                        : '',
                  ),
                  style: TextStyle(
                    color: _selectedDate != null ? Colors.blue[900] : Colors.grey,
                    fontWeight: _selectedDate != null ? FontWeight.bold : FontWeight.normal,
                  ),
                  readOnly: true, // Поле только для чтения
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            if (_selectedDate != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Выбранный день:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getWeekday(_selectedDate!),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedPlace?.price != null)
                      Text(
                        'Стоимость за день: ${_selectedPlace!.price} руб.',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
           '${date.month.toString().padLeft(2, '0')}.'
           '${date.year}';
  }

  String _getWeekday(DateTime date) {
    final weekdays = [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье',
    ];
    return '${weekdays[date.weekday - 1]}, ${_formatDate(date)}';
  }

  Widget _buildConfirmationStep() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Подтверждение записи',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            
            if (_selectedCategory != null) ...[
              _buildInfoRow('Категория товара:', _selectedCategory!.type),
              _buildInfoRow('Ценовая категория:', _selectedCategory!.priceCategory),
              _buildInfoRow('Размер места:', _selectedCategory!.preferredSize),
              if (_selectedCategory!.comment != null && _selectedCategory!.comment!.isNotEmpty)
                _buildInfoRow('Комментарий:', _selectedCategory!.comment!),
            ],
            
            if (_selectedExhibition != null)
              _buildInfoRow('Выставка:', _selectedExhibition!.name),
            
            if (_selectedPlace != null)
              _buildInfoRow('Место:', '${_selectedPlace!.number} (${_selectedPlace!.size}) - ${_selectedPlace!.categoriesAsString}'),
            
            if (_selectedDate != null)
              _buildInfoRow('Дата посещения:', _getWeekday(_selectedDate!)),
            
            if (_selectedPlace?.price != null)
              _buildInfoRow('Стоимость за день:', '${_selectedPlace!.price} руб.'),
            
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[100]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'После подтверждения вам будет предложено оплатить бронирование места',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            _buildInfoRow('Статус:', 'Требуется оплата'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(value)),
        ],
      )
    );
  }

  Future<void> _confirmRegistration() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите в систему')),
      );
      return;
    }
    
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите категорию товара')),
      );
      return;
    }
    
    if (_selectedExhibitionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите выставку')),
      );
      return;
    }
    
    if (_selectedPlace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите место')),
      );
      return;
    }
    
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите дату выставки')),
      );
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      final registrationRef = _firestore.collection('registrations').doc();
      
      final registrationData = {
        'id': registrationRef.id,
        'userId': user.uid,
        'exhibitionId': _selectedExhibitionId,
        'placeId': _selectedPlace!.id,
        'productCategoryId': _selectedCategory!.id,
        'date': Timestamp.fromDate(_selectedDate!),
        'status': 'pending_payment',
        'createdAt': Timestamp.now(),
        'totalAmount': _selectedPlace?.price ?? 0,
        'wantsSamePlace': _wantsSamePlace,
        'isPreviousParticipant': _isPreviousParticipant,
      };
      
      await _firestore.runTransaction((transaction) async {
        transaction.set(registrationRef, registrationData);
        
        final placeRef = _firestore
            .collection('exhibitions')
            .doc(_selectedExhibitionId)
            .collection('places')
            .doc(_selectedPlace!.id);
        
        transaction.update(placeRef, {
          'isBooked': true,
          'bookedDate': Timestamp.fromDate(_selectedDate!),
          'currentRegistrationId': registrationRef.id,
          'tempLockedBy': user.uid,
          'tempLockExpiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 2))),
        });

        final lockRef = _firestore
            .collection('exhibitions')
            .doc(_selectedExhibitionId!)
            .collection('selection_locks')
            .doc(_selectionLockDocId);
        transaction.delete(lockRef);
      });

      await _releaseTemporaryLocks(keepPlaceId: _selectedPlace!.id);
      await _sendPlaceBookedNotification(registrationRef.id);
      
      widget.onPaymentRequired();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Место забронировано. Переход к оплате...'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      print('Ошибка бронирования: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка бронирования: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendPlaceBookedNotification(String registrationId) async {
    await _firestore.collection('notifications').add({
      'type': 'place_booked',
      'title': 'Место забронировано',
      'message': 'Ваше место ${_selectedPlace!.number} успешно забронировано.',
      'registrationId': registrationId,
      'exhibitionId': _selectedExhibitionId,
      'placeNumber': _selectedPlace!.number,
      'date': Timestamp.fromDate(_selectedDate!),
      'userId': _auth.currentUser?.uid,
      'userEmail': _auth.currentUser?.email,
      'timestamp': Timestamp.now(),
      'status': 'unread',
    });
  }

  void _nextStep() {
    bool canContinue = true;
    
    switch (_currentStep) {
      case 0:
        // Шаг категории товара
        if (_selectedCategory == null && 
            (_selectedProductType == null || 
             _selectedPriceCategory == null || 
             _selectedPlaceSize == null)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Заполните информацию о категории товара')),
          );
          canContinue = false;
        }
        break;
      case 1:
        // Шаг выставки
        if (_selectedExhibitionId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Выберите выставку')),
          );
          canContinue = false;
        }
        break;
      case 2:
        // Шаг места
        if (_selectedPlace == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Выберите место')),
          );
          canContinue = false;
        }
        break;
      case 3:
        // Шаг даты
        if (_selectedDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Выберите дату выставки')),
          );
          canContinue = false;
        }
        break;
    }
    
    if (canContinue && _currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _initializeSteps();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _initializeSteps();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
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
          const SizedBox(height: 8),
          Text(
            _isPreviousParticipant
                ? 'Для вас действуют привилегии постоянного участника'
                : 'Выберите выставку и дату для записи',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          
          Stepper(
            currentStep: _currentStep,
            onStepContinue: _nextStep,
            onStepCancel: _previousStep,
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      OutlinedButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Назад'),
                      ),
                    const SizedBox(width: 10),
                    if (_currentStep < _steps.length - 1)
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        child: const Text('Далее'),
                      ),
                    if (_currentStep == _steps.length - 1)
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _confirmRegistration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, size: 18),
                                  SizedBox(width: 8),
                                  Text('Забронировать и оплатить'),
                                ],
                              ),
                      ),
                  ],
                ),
              );
            },
            steps: _steps,
          ),
        ],
      ),
    );
  }
}

class Exhibition {
  final String id;
  final String name;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<int>? workingDays;
  final String status;

  Exhibition({
    required this.id,
    required this.name,
    this.description,
    this.startDate,
    this.endDate,
    this.workingDays,
    required this.status,
  });

  factory Exhibition.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Exhibition(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : null,
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      workingDays: data['workingDays'] != null
          ? List<int>.from(data['workingDays'])
          : null,
      status: data['status'] ?? 'upcoming',
    );
  }
}

class ProductCategory {
  String id;
  final String type;
  final String priceCategory;
  final String preferredSize;
  final String? comment;
  final String userId;
  final String categoryId;

  ProductCategory({
    required this.id,
    required this.type,
    required this.priceCategory,
    required this.preferredSize,
    this.comment,
    required this.userId,
    required this.categoryId,
  });

  factory ProductCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductCategory(
      id: doc.id,
      type: data['name'] ?? data['type'] ?? '',
      priceCategory: data['priceCategory'] ?? '',
      preferredSize: (data['size'] ?? data['preferredSize'] ?? '').toString(),
      comment: data['comment'],
      userId: '',
      categoryId: doc.id,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'priceCategory': priceCategory,
      'preferredSize': preferredSize,
      if (comment != null && comment!.isNotEmpty) 'comment': comment,
      'userId': userId,
      'createdAt': Timestamp.now(),
    };
  }
}

class Place {
  final String id;
  final String number;
  final List<String> preferredCategories;
  final List<String> preferredCategoryIds;
  final String size;
  final bool isBooked;
  final double? price;

  Place({
    required this.id,
    required this.number,
    required this.preferredCategories,
    required this.preferredCategoryIds,
    required this.size,
    required this.isBooked,
    this.price,
  });

  factory Place.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Обработка обратной совместимости
    List<String> categories = [];
    List<String> categoryIds = [];
    
    if (data['preferredCategories'] != null) {
      // Если уже есть список категорий
      final dynamicList = data['preferredCategories'] as List;
      categories = dynamicList.map<String>((item) => item.toString()).toList();
    } else if (data['preferredCategory'] != null) {
      // Если есть старое поле preferredCategory
      categories = (data['preferredCategory'] as List).map((e) => e.toString()).toList();
    }

    if (data['preferredCategoryIds'] != null) {
      final dynamicList = data['preferredCategoryIds'] as List;
      categoryIds = dynamicList.map<String>((item) => item.toString()).toList();
    }
    
    return Place(
      id: doc.id,
      number: data['number'] ?? '',
      preferredCategories: categories,
      preferredCategoryIds: categoryIds,
      size: data['size'] ?? '',
      isBooked: data['isBooked'] ?? false,
      price: data['price']?.toDouble(),
    );
  }
  
  // Метод для проверки, подходит ли место для определенной категории товара
  bool isSuitableForCategory(String category) {
    return preferredCategories.contains(category);
  }
  
  // Метод для получения первой категории (для отображения в UI)
  String get firstCategory {
    return preferredCategories.isNotEmpty ? preferredCategories.first : '';
  }
  
  // Метод для отображения всех категорий через запятую
  String get categoriesAsString {
    return preferredCategories.join(', ');
  }
}