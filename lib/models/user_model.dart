// lib/models/user_model.dart
class UserModel {
  final String  id;
  final String  fullName;
  final String  role;        // resident | master | chairman
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? buildingId;
  final String? specialty;       // только для мастеров
  final String? description;     // только для мастеров
  final double? priceFrom;
  final int?    experienceYears;
  final double  rating;
  final int     reviewsCount;
  final bool    isVerified;
  final bool    isAvailable;     // онлайн/офлайн (для мастеров)
  final int?    apartmentNumber; // только для жителей

  const UserModel({
    required this.id,
    required this.fullName,
    required this.role,
    this.email,
    this.phone,
    this.avatarUrl,
    this.buildingId,
    this.specialty,
    this.description,
    this.priceFrom,
    this.experienceYears,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.isVerified = false,
    this.isAvailable = true,
    this.apartmentNumber, required firstName, required lastName, required String bin,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id              : map['id']?.toString()          ?? '',
      fullName        : (map['full_name'] ?? map['name'])?.toString() ?? '',
      role            : map['role']?.toString()         ?? 'resident',
      email           : map['email']?.toString(),
      phone           : map['phone']?.toString(),
      avatarUrl       : map['avatar_url']?.toString(),
      buildingId      : map['building_id']?.toString(),
      specialty       : map['specialty']?.toString(),
      description     : (map['description'] ?? map['bio'])?.toString(),
      priceFrom       : (map['price_from'] as num?)?.toDouble(),
      experienceYears : map['experience_years'] as int?,
      rating          : (map['rating'] as num?)?.toDouble()       ?? 0.0,
      reviewsCount    : (map['reviews_count'] as int?)            ?? 0,
      isVerified      : map['is_verified'] as bool?               ?? false,
      isAvailable     : map['is_available'] as bool?              ?? true,
      apartmentNumber : map['apartment_number'] as int?, firstName: null, lastName: null, bin: '',
    );
  }

  Map<String, dynamic> toMap() => {
    'full_name'        : fullName,
    'role'             : role,
    if (email           != null) 'email'           : email,
    if (phone           != null) 'phone'           : phone,
    if (avatarUrl       != null) 'avatar_url'      : avatarUrl,
    if (buildingId      != null) 'building_id'     : buildingId,
    if (specialty       != null) 'specialty'       : specialty,
    if (description     != null) 'description'     : description,
    if (priceFrom       != null) 'price_from'      : priceFrom,
    if (experienceYears != null) 'experience_years': experienceYears,
    'is_available'     : isAvailable,
    if (apartmentNumber != null) 'apartment_number': apartmentNumber,
  };

  bool get isResident  => role == 'resident';
  bool get isMaster    => role == 'master';
  bool get isChairman  => role == 'chairman';

  // Инициалы для аватара
  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (fullName.isNotEmpty) return fullName[0].toUpperCase();
    return '?';
  }

  get firstName => null;

  get lastName => null;
}