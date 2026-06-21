class User {
  final String userId;
  final String username;
  final String fullName;
  final String? email;
  final String role;
  final bool isActive;

  const User({
    required this.userId,
    required this.username,
    required this.fullName,
    this.email,
    required this.role,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId']?.toString() ?? '',
      username: json['username'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'],
      role: json['role'] ?? '',
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'fullName': fullName,
        'email': email,
        'role': role,
        'isActive': isActive,
      };
}
