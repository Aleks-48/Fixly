class UserModel {
  final String id;
  final String firstName; // Разделили Имя
  final String lastName;  // и Фамилию
  final String email;
  final String phone;
  final String? avatarUrl;
  final String bin; 
  final String role; // 'master' (ИП/ТОО) или 'osi' (Председатель)
  final String? orgName; // Название компании или ЖК

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.avatarUrl,
    required this.bin,
    required this.role,
    this.orgName,
  });

  // Геттер для удобного отображения полного имени
  String get fullName => '$firstName $lastName';

  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? bin,
    String? avatarUrl,
    String? role,
    String? orgName,
  }) {
    return UserModel(
      id: id,
      email: email,
      phone: phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      bin: bin ?? this.bin,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      orgName: orgName ?? this.orgName,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      avatarUrl: json['avatar_url'],
      bin: json['bin']?.toString() ?? '',
      role: json['role'] ?? 'osi', // По умолчанию ОСИ, если не указано
      orgName: json['org_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'bin': bin,
      'role': role,
      'org_name': orgName,
    };
  }
}