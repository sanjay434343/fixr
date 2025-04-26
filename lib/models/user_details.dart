class UserDetails {
  final String? uid;
  final String? email;
  final String? displayName;

  UserDetails({
    this.uid,
    this.email,
    this.displayName,
  });

  factory UserDetails.fromMap(Map<String, dynamic> map) {
    return UserDetails(
      uid: map['uid'] as String?,
      email: map['email'] as String?,
      displayName: map['displayName'] as String?,
    );
  }
}
