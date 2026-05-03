import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String accountId;
  final String role;
  final String status;
  final String email;
  final String username;
  final DateTime createdAt;
  final bool isFirstLogin;

  AppUser({
    required this.uid,
    required this.accountId,
    required this.role,
    required this.status,
    required this.email,
    required this.username,
    required this.createdAt,
    this.isFirstLogin = false,
  });

  // Creates an AppUser from a Firestore document map and the user's uid
  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      accountId: map['accountId'] ?? '',
      role: map['role'] ?? 'user',
      status: map['status'] ?? 'active',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isFirstLogin: map['isFirstLogin'] ?? false,
    );
  }

  // Converts the AppUser to a map for storing in Firestore
  Map<String, dynamic> toMap() => {
    'accountId': accountId,
    'role': role,
    'status': status,
    'email': email,
    'username': username,
    'createdAt': Timestamp.fromDate(createdAt),
    'isFirstLogin': isFirstLogin,
  };
}