class TaskModel {
  final String id;
  final String title;
  final String description;
  final String status;
  final String apartment;
  final String residentPhone;
  final DateTime createdAt;
  final String? imageUrl; // Поле для ссылки на фото из Supabase
  final String? masterId; // Поле для ID мастера (кто взял в работу)

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.apartment,
    required this.residentPhone,
    required this.createdAt,
    this.imageUrl,
    this.masterId,
  });

  // Превращаем данные из Supabase (JSON) в объект Dart
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'new',
      apartment: json['apartment']?.toString() ?? '',
      residentPhone: json['resident_phone'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      imageUrl: json['image_url'], // Считываем колонку с фото
      masterId: json['master_id'],
    );
  }

  // Превращаем объект Dart в JSON (пригодится для вставки данных)
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'status': status,
      'apartment': apartment,
      'resident_phone': residentPhone,
      'image_url': imageUrl,
      'master_id': masterId,
    };
  }

  // Метод для удобного копирования объекта с изменениями
  TaskModel copyWith({
    String? status,
    String? masterId,
    String? imageUrl,
  }) {
    return TaskModel(
      id: id,
      title: title,
      description: description,
      status: status ?? this.status,
      apartment: apartment,
      residentPhone: residentPhone,
      createdAt: createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      masterId: masterId ?? this.masterId,
    );
  }
}