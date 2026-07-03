// lib/models/task_model.dart
class TaskModel {
  final String  id;
  final String  title;
  final String  description;
  final String  status;      // new | in_progress | completed | cancelled
  final String  priority;    // low | medium | high
  final String  userId;      // кто создал (житель)
  final String? masterId;    // кто взял в работу
  final String? category;    // specialty
  final String? address;
  final String? apartment;
  final String? imageUrl;
  final double  price;
  final double? finalPrice;
  final String  residentPhone; // телефон жильца, оставившего заявку
  final DateTime createdAt;

  const TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.priority = 'medium',
    required this.userId,
    this.masterId,
    this.category,
    this.address,
    this.apartment,
    this.imageUrl,
    this.price = 0.0,
    this.finalPrice,
    this.residentPhone = '',
    required this.createdAt,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id         : map['id']?.toString()          ?? '',
      title      : map['title']?.toString()        ?? '',
      description: map['description']?.toString()  ?? '',
      status     : map['status']?.toString()        ?? 'new',
      priority   : map['priority']?.toString()      ?? 'medium',
      userId     : (map['user_id'] ?? map['client_id'])?.toString() ?? '',
      masterId   : (map['master_id'] ?? map['assignee_id'])?.toString(),
      category   : map['category']?.toString(),
      address    : map['address']?.toString(),
      apartment  : map['apartment']?.toString(),
      imageUrl   : (map['image_url'] ?? map['image'])?.toString(),
      price      : (map['price'] as num?)?.toDouble()       ?? 0.0,
      finalPrice : (map['final_price'] as num?)?.toDouble(),
      residentPhone: (map['resident_phone'] ?? map['customer_phone'])?.toString() ?? '',
      createdAt  : map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Раньше это была пустая заглушка (`static Object? fromJson(...) {}`),
  /// которая всегда возвращала null. Из-за этого в home_page.dart список
  /// задач после `.whereType<TaskModel>()` всегда оказывался пустым, а
  /// статистика "Новые/В работе/Готово" всегда показывала 0/0/0.
  /// Теперь это просто алиас на fromMap.
  factory TaskModel.fromJson(Map<String, dynamic> d) => TaskModel.fromMap(d);

  Map<String, dynamic> toMap() => {
    'title'      : title,
    'description': description,
    'status'     : status,
    'priority'   : priority,
    'user_id'    : userId,
    'price'      : price,
    if (masterId   != null) 'master_id'  : masterId,
    if (category   != null) 'category'   : category,
    if (address    != null) 'address'    : address,
    if (apartment  != null) 'apartment'  : apartment,
    if (imageUrl   != null) 'image_url'  : imageUrl,
    if (finalPrice != null) 'final_price': finalPrice,
    if (residentPhone.isNotEmpty) 'resident_phone': residentPhone,
  };

  TaskModel copyWith({String? status, String? masterId, double? finalPrice}) =>
      TaskModel(
        id        : id,        title      : title,
        description: description, status  : status ?? this.status,
        priority  : priority,  userId     : userId,
        masterId  : masterId   ?? this.masterId,
        category  : category,  address    : address,
        apartment : apartment, imageUrl   : imageUrl,
        price     : price,     finalPrice : finalPrice ?? this.finalPrice,
        residentPhone: residentPhone,
        createdAt : createdAt,
      );

  bool get isNew        => status == 'new';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted  => status == 'completed';
  bool get isCancelled  => status == 'cancelled';
}