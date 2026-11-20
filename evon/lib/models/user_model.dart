class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'user', 'station_admin', 'super_admin'
  final String phone;
  final String vehicleType;
  final double batteryCapacity;
  final String? assignedStation;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.vehicleType = 'Electric Car',
    this.batteryCapacity = 60.0,
    this.assignedStation,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      phone: json['phone'] ?? '',
      vehicleType: json['vehicleType'] ?? 'Electric Car',
      batteryCapacity: (json['batteryCapacity'] as num?)?.toDouble() ?? 60.0,
      assignedStation: json['assignedStation'] is Map
          ? json['assignedStation']['_id']
          : json['assignedStation']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'vehicleType': vehicleType,
      'batteryCapacity': batteryCapacity,
      'assignedStation': assignedStation,
    };
  }

  bool get isSuperAdmin => role == 'super_admin';
  bool get isStationAdmin => role == 'station_admin';
  bool get isDriver => role == 'user';
}
