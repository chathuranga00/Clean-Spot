class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String district;
  final String role; // 'citizen' | 'phi' | 'admin'
  final int totalPoints;
  final int verifiedReportsCount;
  final List<String> badges;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.district,
    this.role = 'citizen',
    this.totalPoints = 0,
    this.verifiedReportsCount = 0,
    this.badges = const [],
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Citizen',
      photoUrl: map['photoUrl'] as String?,
      district: map['district'] as String? ?? 'Colombo',
      role: map['role'] as String? ?? 'citizen',
      totalPoints: (map['totalPoints'] as num?)?.toInt() ?? 0,
      verifiedReportsCount: (map['verifiedReportsCount'] as num?)?.toInt() ?? 0,
      badges: (map['badges'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'district': district,
      'role': role,
      'totalPoints': totalPoints,
      'verifiedReportsCount': verifiedReportsCount,
      'badges': badges,
    };
  }
}
