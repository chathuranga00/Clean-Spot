class AuthUser {
  final String uid;
  final String email;
  final String displayName;
  final bool isEmailVerified;
  final String? photoUrl;

  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.isEmailVerified = false,
    this.photoUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email &&
          isEmailVerified == other.isEmailVerified;

  @override
  int get hashCode => uid.hashCode ^ email.hashCode ^ isEmailVerified.hashCode;
}
