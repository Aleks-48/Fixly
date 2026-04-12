// lib/models/order_model.dart
// Единая модель заказа для всего приложения.
// ВАЖНО: таблица в Supabase называется 'tasks' (не 'orders').

class OrderModel {
  final String  id;
  final String  title;
  final String  description;
  final double  price;
  final double? finalPrice;    // итоговая сумма после завершения
  final String  status;        // new | in_progress | completed | cancelled
  final String  priority;      // low | medium | high
  final String  clientId;      // user_id жителя
  final String? masterId;      // master_id (null пока не взяли)
  final String? category;      // специализация: plumber / electrician / ...
  final String? address;
  final String? customerName;
  final String? customerPhone;
  final String? residentPhone;
  final String? apartment;
  final String? imageUrl;
  final DateTime createdAt;

  const OrderModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.finalPrice,
    required this.status,
    this.priority = 'medium',
    required this.clientId,
    this.masterId,
    this.category,
    this.address,
    this.customerName,
    this.customerPhone,
    this.residentPhone,
    this.apartment,
    this.imageUrl,
    required this.createdAt,
  });

  // ── ИЗ SUPABASE ────────────────────────────────────────────
  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id           : map['id']?.toString()     ?? '',
      title        : map['title']?.toString()  ?? '',
      description  : map['description']?.toString() ?? '',
      price        : (map['price'] as num?)?.toDouble()       ?? 0.0,
      finalPrice   : (map['final_price'] as num?)?.toDouble(),
      status       : map['status']?.toString() ?? 'new',
      priority     : map['priority']?.toString() ?? 'medium',
      clientId     : (map['client_id'] ?? map['user_id'])?.toString() ?? '',
      masterId     : (map['master_id'] ?? map['assignee_id'])?.toString(),
      category     : map['category']?.toString(),
      address      : map['address']?.toString(),
      customerName : (map['customer_name'] ?? map['full_name'])?.toString(),
      customerPhone: map['customer_phone']?.toString(),
      residentPhone: map['resident_phone']?.toString(),
      apartment    : map['apartment']?.toString(),
      imageUrl     : (map['image_url'] ?? map['image'] ?? map['photo_url'])?.toString(),
      createdAt    : map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // ── В SUPABASE ─────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'title'          : title,
      'description'    : description,
      'price'          : price,
      if (finalPrice != null) 'final_price': finalPrice,
      'status'         : status,
      'priority'       : priority,
      'client_id'      : clientId,
      if (masterId != null)      'master_id'     : masterId,
      if (category != null)      'category'      : category,
      if (address != null)       'address'        : address,
      if (customerName != null)  'customer_name'  : customerName,
      if (customerPhone != null) 'customer_phone' : customerPhone,
      if (residentPhone != null) 'resident_phone' : residentPhone,
      if (apartment != null)     'apartment'      : apartment,
      if (imageUrl != null)      'image_url'      : imageUrl,
    };
  }

  // ── КОПИРОВАНИЕ С ИЗМЕНЕНИЯМИ ──────────────────────────────
  OrderModel copyWith({
    String?  status,
    String?  masterId,
    double?  finalPrice,
    String?  priority,
  }) {
    return OrderModel(
      id            : id,
      title         : title,
      description   : description,
      price         : price,
      finalPrice    : finalPrice ?? this.finalPrice,
      status        : status    ?? this.status,
      priority      : priority  ?? this.priority,
      clientId      : clientId,
      masterId      : masterId  ?? this.masterId,
      category      : category,
      address       : address,
      customerName  : customerName,
      customerPhone : customerPhone,
      residentPhone : residentPhone,
      apartment     : apartment,
      imageUrl      : imageUrl,
      createdAt     : createdAt,
    );
  }

  // ── ХЕЛПЕРЫ ────────────────────────────────────────────────
  bool get isNew        => status == 'new';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted  => status == 'completed';
  bool get isCancelled  => status == 'cancelled';

  String get displayPrice {
    if (finalPrice != null && finalPrice! > 0) return '${finalPrice!.toInt()} ₸';
    return '${price.toInt()} ₸';
  }
}