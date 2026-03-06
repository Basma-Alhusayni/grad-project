import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // ── Current user stream ──────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Get role from Firestore ──────────────────────────────
  Future<String?> getUserRole(String uid) async {
    final doc = await _db.collection('accounts').doc(uid).get();
    return doc.data()?['role'];
  }

  // ── Register User ────────────────────────────────────────
  Future<String?> registerUser({
    required String email,
    required String password,
    required String username,
    required String fullName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      final uid = cred.user!.uid;
      await _db.collection('accounts').doc(uid).set({
        'accountId': uid,
        'role': 'user',
        'status': 'active',
        'email': email,
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _db.collection('users').doc(uid).set({
        'userId': uid,
        'accountId': uid,
        'email': email,
        'username': username,
        'fullName': fullName,
        'profileImage': null,
        'userReportId': null,
      });
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  // ── Register Admin ───────────────────────────────────────
  Future<String?> registerAdmin({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      final uid = cred.user!.uid;
      await _db.collection('accounts').doc(uid).set({
        'accountId': uid,
        'role': 'admin',
        'status': 'active',
        'email': email,
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _db.collection('admins').doc(uid).set({
        'adminId': uid,
        'accountId': uid,
        'email': email,
        'username': username,
        'passwordHash': password, // store hashed in prod!
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  // ── Submit Specialist Request ────────────────────────────
  Future<String?> submitSpecialistRequest({
    required String email,
    required String fullName,
    required String certificates,
    required String experience,
    List<String> certificateImageUrls = const [],
  }) async {
    try {
      await _db.collection('specialist_requests').add({
        'email': email,
        'fullName': fullName,
        'certificates': certificates,
        'experience': experience,
        'certificateImages': certificateImageUrls,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'فشل إرسال الطلب. حاول مجدداً.';
    }
  }

  // ── Login ────────────────────────────────────────────────
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String expectedRole,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      final uid = cred.user!.uid;
      final doc = await _db.collection('accounts').doc(uid).get();
      if (!doc.exists) return {'error': 'الحساب غير موجود'};
      final role = doc.data()!['role'];
      // Admin can log in regardless of expectedRole
      if (role != expectedRole && role != 'admin') {
        await _auth.signOut();
        return {'error': 'نوع الحساب غير صحيح'};
      }
      return {'role': role, 'uid': uid};
    } on FirebaseAuthException catch (e) {
      return {'error': _mapError(e.code)};
    }
  }

  // ── Specialist Login (by email sent after approval) ──────
  Future<Map<String, dynamic>> specialistLogin({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      final uid = cred.user!.uid;
      final doc = await _db.collection('accounts').doc(uid).get();
      if (!doc.exists) return {'error': 'الحساب غير موجود'};
      final role = doc.data()!['role'];
      if (role != 'specialist') {
        await _auth.signOut();
        return {'error': 'هذا الحساب ليس حساب خبير'};
      }
      return {'role': role, 'uid': uid};
    } on FirebaseAuthException catch (e) {
      return {'error': _mapError(e.code)};
    }
  }

  // ── Reset Password ───────────────────────────────────────
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  // ── Sign Out ─────────────────────────────────────────────
  Future<void> signOut() => _auth.signOut();

  // ── Error mapper ─────────────────────────────────────────
  String _mapError(String code) {
    switch (code) {
      case 'user-not-found': return 'البريد الإلكتروني غير مسجل';
      case 'wrong-password': return 'كلمة المرور غير صحيحة';
      case 'email-already-in-use': return 'البريد الإلكتروني مستخدم بالفعل';
      case 'weak-password': return 'كلمة المرور ضعيفة جداً';
      case 'invalid-email': return 'البريد الإلكتروني غير صحيح';
      case 'too-many-requests': return 'محاولات كثيرة. حاول لاحقاً';
      default: return 'هناك خطأ في البريد الإلكتروني أو في كلمة المرور';
    }
  }
}