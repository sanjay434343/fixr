class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String doornum;
  final String landmark;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.doornum,
    required this.landmark,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      doornum: map['doornum']?.toString() ?? '',
      landmark: map['landmark']?.toString() ?? '',
      createdAt: map['createdAt'] is int 
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt']) 
          : map['createdAt'] is String 
              ? DateTime.fromMillisecondsSinceEpoch(int.parse(map['createdAt']))
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'doornum': doornum,
      'landmark': landmark,
      'createdAt': createdAt.millisecondsSinceEpoch.toString(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'doornum': doornum,
      'landmark': landmark,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      name: json['name'] ?? 'Guest User',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      doornum: json['doornum'] ?? '',
      landmark: json['landmark'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
