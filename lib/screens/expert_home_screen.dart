import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';
import 'requests_screen.dart';
import 'expert_chat_screen.dart';
import 'expert_schedule_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ExpertHomeScreen extends StatefulWidget {
  const ExpertHomeScreen({super.key});

  @override
  State<ExpertHomeScreen> createState() => _ExpertHomeScreenState();
}

class _ExpertHomeScreenState extends State<ExpertHomeScreen> {
  int _currentIndex = 0;
  int _profileTabIndex = 0;

  // ── الحقول الفعلية الموجودة في Firestore ──
  String _fullName = '';
  String _email = '';
  String _experience = '';
  String _certificates = '';
  double _rating = 0.0;
  int _reviewCount = 0;
  List<String> _certificateImages = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      // ── جلب بيانات specialists ──
      final doc = await FirebaseFirestore.instance
          .collection('specialists')
          .doc(uid)
          .get();

      final d = doc.data() ?? {};

      // ── جلب صور الشهادات من specialists أولاً ──
      List<String> certImages = [];
      if (d['certificateImages'] is List) {
        certImages = (d['certificateImages'] as List)
            .map((e) => e.toString())
            .toList();
      }

      // ── إذا ما فيه صور في specialists نجيبها من specialist_requests ──
      if (certImages.isEmpty) {
        try {
          final reqSnap = await FirebaseFirestore.instance
              .collection('specialist_requests')
              .where('specialistId', isEqualTo: uid)
              .limit(1)
              .get();

          if (reqSnap.docs.isNotEmpty) {
            final reqData = reqSnap.docs.first.data();
            if (reqData['certificateImages'] is List) {
              certImages = (reqData['certificateImages'] as List)
                  .map((e) => e.toString())
                  .toList();
            }
          }
        } catch (_) {}
      }

      // ── جلب التقييمات ──
      List<Map<String, dynamic>> reviews = [];
      try {
        final reviewsSnap = await FirebaseFirestore.instance
            .collection('specialists')
            .doc(uid)
            .collection('reviews')
            .limit(10)
            .get();
        reviews = reviewsSnap.docs.map((e) => e.data()).toList();
      } catch (_) {}

      // ── جلب الإيميل من Auth ──
      await FirebaseAuth.instance.currentUser?.reload();
      final authEmail = FirebaseAuth.instance.currentUser?.email ?? '';

      if (!mounted) return;
      setState(() {
        _fullName = d['fullName'] ?? '';
        _email = authEmail.isNotEmpty ? authEmail : (d['email'] ?? '');
        _experience = d['experience'] ?? '';
        _certificates = d['certificates'] ?? '';
        _rating = (d['rating'] is num) ? (d['rating'] as num).toDouble() : 0.0;
        _reviewCount = (d['reviewCount'] is num)
            ? (d['reviewCount'] as num).toInt()
            : 0;
        _certificateImages = certImages;
        _reviews = reviews;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  // ── عرض صورة الشهادة كاملة ──────────────────────────────────
  void _showFullImage(String url) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'معاينة الشهادة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF14532D),
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.65,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(
                      maxScale: 5.0,
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 250,
                            color: const Color(0xFFF3F4F6),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          height: 200,
                          width: double.infinity,
                          color: const Color(0xFFFEF2F2),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                color: Colors.red,
                                size: 48,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'تعذر تحميل الصورة',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFFF0FDF4),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          centerTitle: true,
          title: const Text(
            'BioShield',
            style: TextStyle(
              color: Color(0xFF16A34A),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              'assets/images/logo_without_background.png',
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.eco, color: Color(0xFF16A34A)),
            ),
          ),
          actions: [
            IconButton(
              icon: Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(3.1416),
                child: const Icon(Icons.logout, color: Color(0xFFCC0000)),
              ),
              onPressed: _logout,
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF16A34A)),
              )
            : _buildBody(),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const RequestsScreen();
      case 1:
        return const _ChatsPage();
      case 2:
        return const ExpertScheduleScreen();
      case 3:
        return _buildProfileTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      selectedItemColor: const Color(0xFF16A34A),
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment_outlined),
          activeIcon: Icon(Icons.assignment),
          label: 'الطلبات',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          activeIcon: Icon(Icons.chat_bubble),
          label: 'المحادثات',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          activeIcon: Icon(Icons.calendar_today),
          label: 'الجدول',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'الملف الشخصي',
        ),
      ],
    );
  }

  // ── تاب الملف الشخصي ─────────────────────────────────────────
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildProfileHeader(),
          _buildTabBar(),
          _profileTabIndex == 0
              ? _buildInfoContent()
              : _profileTabIndex == 1
              ? _buildReportsContent()
              : _buildReviewsContent(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF14532D)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF14532D),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Center(
              child: Text(
                _fullName.isNotEmpty ? _fullName[0].toUpperCase() : 'خ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fullName.isNotEmpty ? 'د. $_fullName' : 'د. الخبير',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < _rating.floor()
                            ? Icons.star
                            : i < _rating
                            ? Icons.star_half
                            : Icons.star_border,
                        color: const Color(0xFFFBBF24),
                        size: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_rating.toStringAsFixed(1)} ($_reviewCount تقييم)',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showEditRequestSheet,
            icon: const Icon(Icons.edit, color: Colors.white, size: 20),
            tooltip: 'طلب تعديل',
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    const tabs = ['المعلومات', 'التقارير', 'التقييمات'];
    return Container(
      color: Colors.white,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _profileTabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _profileTabIndex = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected
                          ? const Color(0xFF16A34A)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? const Color(0xFF16A34A) : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── ارسال طلب تعديل للبيانات ────────────────────────────────────────────
  void _showEditRequestSheet() {
    final nameController = TextEditingController(text: _fullName);
    final certificatesController = TextEditingController(text: _certificates);
    final experienceController = TextEditingController(text: _experience);
    final emailController = TextEditingController(text: _email);
    List<File> newImages = [];
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              20,
              16,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Center(
                    child: Text(
                      'طلب تعديل المعلومات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'سيتم مراجعة التعديلات من قِبل الإدارة قبل تطبيقها',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _editField('الاسم الكامل', nameController),
                  _editField('الخبرة', experienceController, maxLines: 3),
                  _editField('الشهادات', certificatesController, maxLines: 3),
                  _editField('البريد الإلكتروني', emailController),
                  const SizedBox(height: 12),

                  const Text(
                    'صور الشهادات',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await ImagePicker().pickMultiImage();
                      if (picked.isNotEmpty) {
                        setSheet(
                          () => newImages = picked
                              .map((e) => File(e.path))
                              .toList(),
                        );
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey.shade50,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.upload_file, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            newImages.isNotEmpty
                                ? 'تم اختيار ${newImages.length} صورة ✓'
                                : 'اضغط لاختيار صور الشهادات',
                            style: TextStyle(
                              color: newImages.isNotEmpty
                                  ? const Color(0xFF16A34A)
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (newImages.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: newImages.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              newImages[i],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              setSheet(() => isLoading = true);
                              try {
                                await _submitEditRequest(
                                  newFullName: nameController.text.trim(),
                                  newExperience: experienceController.text
                                      .trim(),
                                  newCertificates: certificatesController.text
                                      .trim(),
                                  newEmail: emailController.text.trim(),
                                  newImages: newImages,
                                );
                                if (mounted) Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '✅ تم إرسال طلب التعديل للمراجعة',
                                    ),
                                    backgroundColor: Color(0xFF16A34A),
                                  ),
                                );
                              } catch (e) {
                                setSheet(() => isLoading = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('حدث خطأ: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'إرسال طلب التعديل',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _editField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitEditRequest({
    required String newFullName,
    required String newExperience,
    required String newCertificates,
    required String newEmail,
    required List<File> newImages,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // تحميل صور الشهادات الجديدة
    List<String> newImageUrls = [];
    for (int i = 0; i < newImages.length; i++) {
      final ref = FirebaseStorage.instance.ref().child(
        'certificate_edit_requests/$uid/${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
      );
      await ref.putFile(newImages[i]);
      final url = await ref.getDownloadURL();
      newImageUrls.add(url);
    }

    await FirebaseFirestore.instance.collection('Specialist_edit_request').add({
      'specialistId': uid,
      'specialistName': _fullName,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
      'rejectionReason': '',
      // القيم الجديدة
      'newFullName': newFullName,
      'newExperience': newExperience,
      'newCertificates': newCertificates,
      'newEmail': newEmail,
      'newCertificateImages': newImageUrls,
      // القيم القديمة للمقارنة
      'oldFullName': _fullName,
      'oldExperience': _experience,
      'oldCertificates': _certificates,
      'oldEmail': _email,
      'oldCertificateImages': _certificateImages,
    });
  }

  // ── تاب المعلومات ────────────────────────────────────────────
  Widget _buildInfoContent() {
    return Column(
      children: [
        const SizedBox(height: 12),

        // ── بطاقة المعلومات الشخصية
        _sectionCard(
          title: 'المعلومات الشخصية',
          children: [
            _buildInfoRow(
              label: 'الاسم الكامل',
              value: _fullName.isNotEmpty ? _fullName : '—',
              icon: Icons.person_outline,
            ),
            _divider(),
            _buildInfoRow(
              label: 'البريد الإلكتروني',
              value: _email.isNotEmpty ? _email : '—',
              icon: Icons.email_outlined,
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ── بطاقة المعلومات المهنية
        _sectionCard(
          title: 'المعلومات المهنية',
          children: [
            _buildInfoRow(
              label: 'سنوات الخبرة',
              value: _experience.isNotEmpty ? _experience : '—',
              icon: Icons.work_outline,
            ),
            _divider(),
            _buildInfoRow(
              label: 'الشهادات',
              value: _certificates.isNotEmpty ? _certificates : '—',
              icon: Icons.workspace_premium_outlined,
            ),
          ],
        ),

        // ── صور الشهادات
        if (_certificateImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildCertificateImages(),
        ],

        const SizedBox(height: 16),

        // ── قسم الأمان ──
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'الأمان',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              ListTile(
                leading: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFF16A34A),
                ),
                title: const Text(
                  'تغيير كلمة المرور',
                  style: TextStyle(fontSize: 14),
                ),
                trailing: const Icon(
                  Icons.arrow_back_ios,
                  size: 14,
                  color: Colors.grey,
                ),
                onTap: _showChangePasswordDialog,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        // ── زر تسجيل الخروج
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCC0000),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.logout, color: Colors.white, size: 20),
              label: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  // ── تغيير كلمة المرور (خبير) ──────────────────────────────
  void _showChangePasswordDialog() {
    bool sending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'تغيير كلمة المرور',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF14532D),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'سيتم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.email_outlined,
                        color: Color(0xFF16A34A),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _email,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF166534),
                            fontWeight: FontWeight.w500,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: sending
                    ? null
                    : () async {
                        setDialogState(() => sending = true);
                        try {
                          await FirebaseAuth.instance.sendPasswordResetEmail(
                            email: _email,
                          );
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '✅ تم إرسال رابط إعادة التعيين إلى بريدك',
                              ),
                              backgroundColor: Color(0xFF16A34A),
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => sending = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('حدث خطأ: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'إرسال',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── بطاقة صور الشهادات ──────────────────────────────────────
  Widget _buildCertificateImages() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  color: Color(0xFF16A34A),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'صور الشهادات',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_certificateImages.length} صورة',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
              ),
              itemCount: _certificateImages.length,
              itemBuilder: (context, i) {
                final imgUrl = _certificateImages[i];
                return GestureDetector(
                  onTap: () => _showFullImage(imgUrl),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE8E8E8)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Image.network(
                            imgUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: const Color(0xFFF0FDF4),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF16A34A),
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFF3F4F6),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                    size: 32,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'تعذر التحميل',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // شريط سفلي مع رقم الشهادة وأيقونة تكبير
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(9),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.55),
                                ],
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'شهادة ${i + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Icon(
                                  Icons.zoom_in,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          ...children,
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
    height: 1,
    color: Color(0xFFEEEEEE),
    indent: 16,
    endIndent: 16,
  );

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
          Icon(icon, color: const Color(0xFF16A34A), size: 22),
        ],
      ),
    );
  }

  // ── تاب التقارير ─────────────────────────────────────────────
  Widget _buildReportsContent() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text(
          'لا توجد تقارير حالياً',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ),
    );
  }

  // ── تاب التقييمات ────────────────────────────────────────────
  Widget _buildReviewsContent() {
    if (_reviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'لا توجد تقييمات بعد',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }
    return Column(
      children: [
        const SizedBox(height: 12),
        ..._reviews.map((r) => _reviewCard(r)),
      ],
    );
  }

  Widget _reviewCard(Map<String, dynamic> r) {
    final rating = (r['rating'] ?? 5).toInt();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFDCFCE7),
                child: Text(
                  (r['userName'] ?? 'م')[0],
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['userName'] ?? 'مستخدم',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < rating ? Icons.star : Icons.star_border,
                          color: const Color(0xFFFBBF24),
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((r['comment'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              r['comment'],
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── صفحة المحادثات ───────────────────────────────────────────
class _ChatsPage extends StatelessWidget {
  const _ChatsPage();

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<QuerySnapshot>(
        stream: db.collection('chats').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = snapshot.data?.docs ?? [];
          if (chats.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد محادثات',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final data = chats[index].data() as Map<String, dynamic>;
              final chatId = chats[index].id;
              final userName = data['userName'] ?? '';
              final lastMessage = data['lastMessage'] ?? '';
              final time = data['time'] ?? '';
              final unread = data['unread'] ?? 0;
              final online = data['online'] ?? false;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExpertChatScreen(
                      chatId: chatId,
                      userName: userName,
                      isOnline: online,
                    ),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFbbf7d0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFFdcfce7),
                            child: Text(
                              userName.isNotEmpty ? userName[0] : '؟',
                              style: const TextStyle(
                                color: Color(0xFF15803d),
                                fontSize: 18,
                              ),
                            ),
                          ),
                          if (online)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              lastMessage,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: const Color(0xFF16A34A),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
