class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String district;
  final String role; // 'citizen' | 'phi' | 'admin'
  final int totalPoints;
  final int verifiedReportsCount;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.district,
    this.role = 'citizen',
    this.totalPoints = 0,
    this.verifiedReportsCount = 0,
  });
}
