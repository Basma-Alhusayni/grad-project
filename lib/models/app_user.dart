import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String accountId;
  final String role; // 'user' | 'specialist' | 'admin'
  final String status; // 'active' | 'suspended' | 'pending'
  final String email;
  final String username;
  final String? profileImage;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.accountId,
    required this.role,
    required this.status,
    required this.email,
    required this.username,
    this.profileImage,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      accountId: map['accountId'] ?? '',
      role: map['role'] ?? 'user',
      status: map['status'] ?? 'active',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      profileImage: map['profileImage'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'accountId': accountId,
    'role': role,
    'status': status,
    'email': email,
    'username': username,
    'profileImage': profileImage,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}