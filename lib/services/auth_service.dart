import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'email_service.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // Firebase Console → Project Settings → General → Web API Key
  static const String _firebaseWebApiKey = 'AIzaSyCMExWm5DRSPHLmo0IuaM_YUpptRcNTtLM';

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> getUserRole(String uid) async {
    final doc = await _db.collection('accounts').doc(uid).get();
    return doc.data()?['role'];
  }

  // ── تسجيل مستخدم عادي ──────────────────────────────────────
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
        'isFirstLogin': false,
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
        'isOnline': true,
      });

      await cred.user!.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  // ── تسجيل مسؤول (كود داخلي) ───────────────────────────────
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
        'isFirstLogin': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('admins').doc(uid).set({
        'adminId': uid,
        'accountId': uid,
        'email': email,
        'username': username,
      });

      await cred.user!.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  // ── تقديم طلب انضمام خبير ──────────────────────────────────
  Future<String?> submitSpecialistRequest({
    required String email,
    required String fullName,
    required String certificates,
    required String experience,
    List<String> certificateImageUrls = const [],
  }) async {
    try {
      final existingRequests = await _db
          .collection('specialist_requests')
          .where('email', isEqualTo: email)
          .get();

      for (final doc in existingRequests.docs) {
        final status = doc.data()['status'] ?? '';
        if (status == 'pending') {
          return 'يوجد طلب معلق بهذا البريد الإلكتروني، يرجى الانتظار حتى تتم مراجعته';
        }
        if (status == 'approved') {
          return 'تم قبول طلبك مسبقاً. يرجى تسجيل الدخول كخبير';
        }
      }

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

  // ── توليد كلمة مرور مؤقتة ──────────────────────────────────
  String _generateTempPassword() {
    const words = ['Plant', 'Green', 'Bloom', 'Leaf', 'Bio', 'Flora', 'Crop', 'Herb', 'Seed', 'Field'];
    const symbols = ['!', '@', '#', r'$', '&'];
    final rand = Random.secure();
    final word = words[rand.nextInt(words.length)];
    final digits = rand.nextInt(900) + 100;
    final symbol = symbols[rand.nextInt(symbols.length)];
    return '$word$digits$symbol';
  }

  // ── اعتماد طلب الخبير من قبل الأدمن ────────────────────────
  Future<String?> approveSpecialistRequest({
    required Map<String, dynamic> requestData,
    required String requestDocId,
  }) async {
    final email = (requestData['email'] ?? '').toString().trim();
    final fullName = (requestData['fullName'] ?? '').toString().trim();

    try {
      String uid;
      final tempPassword = _generateTempPassword();

      final createResult = await _createAuthAccountViaRestApi(
        email: email,
        password: tempPassword,
      );

      if (createResult['error'] == 'EMAIL_EXISTS') {
        final existingAccount = await _db
            .collection('accounts')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (existingAccount.docs.isEmpty) {
          await _auth.sendPasswordResetEmail(email: email);
          return 'يوجد حساب بهذا البريد ولكن لا يوجد مستند Firestore. تم إرسال رابط إعادة التعيين.';
        }

        uid = existingAccount.docs.first.id;

        await _db.collection('accounts').doc(uid).update({
          'role': 'specialist',
          'status': 'active',
          'username': fullName,
          'isFirstLogin': true,
        });

        await _auth.sendPasswordResetEmail(email: email);

      } else if (createResult['uid'] != null) {
        uid = createResult['uid']!;

        await _db.collection('accounts').doc(uid).set({
          'accountId': uid,
          'role': 'specialist',
          'status': 'active',
          'email': email,
          'username': fullName,
          'isFirstLogin': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

      } else {
        throw Exception(createResult['error'] ?? 'Unknown REST API error');
      }

      await _db.collection('specialists').doc(uid).set({
        'specialistId': uid,
        'accountId': uid,
        'email': email,
        'fullName': fullName,
        'certificates': requestData['certificates'] ?? '',
        'experience': requestData['experience'] ?? '',
        'certificateImages': requestData['certificateImages'] ?? [],
        'rating': 0.0,
        'reviewCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'isOnline': true,
      }, SetOptions(merge: true));

      await _db
          .collection('specialist_requests')
          .doc(requestDocId)
          .update({'status': 'approved', 'specialistId': uid});

      final emailResult = await EmailService.sendApprovalEmail(
        toEmail: email,
        toName: fullName,
        tempPassword: createResult['error'] == 'EMAIL_EXISTS'
            ? '(راجع بريدك — تم إرسال رابط تعيين كلمة المرور)'
            : tempPassword,
      );

      if (!emailResult.success) {
        return 'تم القبول ✓ لكن فشل إرسال البريد: ${emailResult.error}';
      }

      return null;
    } catch (e) {
      return 'حدث خطأ: $e';
    }
  }

  // ── رفض طلب خبير ───────────────────────────────────────────
  Future<String?> rejectSpecialistRequest({
    required String requestDocId,
    required String expertEmail,
    required String expertName,
    required String rejectionReason,
  }) async {
    try {
      await _db.collection('specialist_requests').doc(requestDocId).update({
        'status': 'rejected',
        'rejectionReason': rejectionReason,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      final emailResult = await EmailService.sendRejectionEmail(
        toEmail: expertEmail,
        toName: expertName,
        rejectionReason: rejectionReason,
      );

      if (!emailResult.success) return 'تم الرفض ✓ لكن فشل إرسال البريد: ${emailResult.error}';
      return null;
    } catch (e) {
      return 'حدث خطأ: $e';
    }
  }

  // ── تسجيل دخول (مستخدم / أدمن) مع التحقق من الدور ────────────
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
      if (!doc.exists) {
        await _auth.signOut();
        return {'error': 'هذا الحساب غير مسجل في النظام'};
      }

      final role = doc.data()!['role'];

      // 🔥 الإصلاح: التحقق الصارم من الدور المخصص لكل شاشة
      if (role != expectedRole) {
        await _auth.signOut();
        String roleLabel = expectedRole == 'admin' ? 'مدير' : 'مستخدم';
        return {'error': 'عذراً، هذا الحساب ليس حساب $roleLabel'};
      }

      final status = doc.data()!['status'];
      if (status == 'suspended') {
        await _auth.signOut();
        return {'error': 'حسابك موقوف حالياً، لا يمكنك تسجيل الدخول'};
      }

      if (!cred.user!.emailVerified) {
        await _auth.signOut();
        return {'error': null, 'needsVerification': true, 'email': email};
      }

      return {'role': role, 'uid': uid};
    } on FirebaseAuthException catch (e) {
      return {'error': _mapError(e.code)};
    }
  }

  // ── تسجيل دخول الخبير مع التحقق من الدور والدخول الأول ───────
  Future<Map<String, dynamic>> specialistLogin({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      final uid = cred.user!.uid;

      final doc = await _db.collection('accounts').doc(uid).get();
      if (!doc.exists) {
        await _auth.signOut();
        return {'error': 'الحساب غير موجود'};
      }

      final role = doc.data()!['role'];

      // 🔥 الإصلاح: منع الأدمن أو المستخدم من دخول واجهة الخبير
      if (role != 'specialist') {
        await _auth.signOut();
        return {'error': 'هذا الحساب ليس حساب خبير'};
      }

      final status = doc.data()!['status'];
      if (status == 'suspended') {
        await _auth.signOut();
        return {'error': 'حسابك موقوف حالياً، لا يمكنك تسجيل الدخول'};
      }

      final isFirstLogin = doc.data()!['isFirstLogin'] == true;
      return {'role': role, 'uid': uid, 'isFirstLogin': isFirstLogin};
    } on FirebaseAuthException catch (e) {
      return {'error': _mapError(e.code)};
    }
  }

  // ── تغيير كلمة المرور عند الدخول الأول ─────────────────────
  Future<String?> changePasswordFirstTime({
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'الجلسة منتهية، يرجى إعادة تسجيل الدخول';

      await user.updatePassword(newPassword);
      await _db
          .collection('accounts')
          .doc(user.uid)
          .update({'isFirstLogin': false});

      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return 'حدث خطأ: $e';
    }
  }

  // ── استعادة كلمة المرور ────────────────────────────────────
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  Future<void> signOut() => _auth.signOut();

  // ── استخدام REST API لإنشاء حساب بدون التأثير على جلسة الأدمن ──
  Future<Map<String, String>> _createAuthAccountViaRestApi({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_firebaseWebApiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': false,
      }),
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return {'uid': data['localId'] as String};
    return {'error': data['error']?['message'] ?? 'Unknown'};
  }

  // ── تحويل رموز الخطأ لرسائل عربية مفهومة ─────────────────────
  String _mapError(String code) {
    switch (code) {
      case 'user-not-found': return 'البريد الإلكتروني غير مسجل';
      case 'wrong-password': return 'كلمة المرور غير صحيحة';
      case 'email-already-in-use': return 'البريد الإلكتروني مستخدم بالفعل';
      case 'weak-password': return 'كلمة المرور ضعيفة جداً (6 أحرف على الأقل)';
      case 'invalid-email': return 'البريد الإلكتروني غير صحيح';
      case 'too-many-requests': return 'محاولات كثيرة. حاول لاحقاً';
      case 'invalid-credential': return 'هناك خطأ في البريد الإلكتروني أو كلمة المرور';
      case 'requires-recent-login': return 'يرجى تسجيل الخروج والدخول مجدداً ثم المحاولة';
      default: return 'هناك خطأ في البريد الإلكتروني أو في كلمة المرور';
    }
  }
}