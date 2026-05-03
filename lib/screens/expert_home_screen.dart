import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';
import 'expert_chat_screen.dart';
import 'expert_schedule_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:bioshield/services/image_upload_service.dart';

class ExpertHomeScreen extends StatefulWidget {
  const ExpertHomeScreen({super.key});

  @override
  State<ExpertHomeScreen> createState() => _ExpertHomeScreenState();
}

class _ExpertHomeScreenState extends State<ExpertHomeScreen> {
  int _currentIndex = 0;
  int _profileTabIndex = 0;

  String _fullName = '';
  String _email = '';
  String _experience = '';
  String _certificates = '';
  double _rating = 0.0;
  int _reviewCount = 0;
  List<Map<String, dynamic>> _reports = [];
  List<String> _certificateImages = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;

  // Load specialist data and set the specialist as online when the screen opens
  @override
  void initState() {
    super.initState();
    _fetchData();

    _setOnlineStatus();
  }

  // Marks the specialist as online in Firestore
  Future<void> _setOnlineStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('specialists')
            .doc(uid)
            .update({'isOnline': true});
      } catch (e) {
        debugPrint('Error updating online status: $e');
      }
    }
  }

  // Loads the specialist's profile, certificate images, reviews, and reports from Firestore
  Future<void> _fetchData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('specialists')
          .doc(uid)
          .get();

      final d = doc.data() ?? {};

      List<String> certImages = [];
      if (d['certificateImages'] is List) {
        certImages = (d['certificateImages'] as List)
            .map((e) => e.toString())
            .toList();
      }

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

      List<Map<String, dynamic>> reports = [];
      try {
        final reportsSnap = await FirebaseFirestore.instance
            .collection('specialist_reports')
            .where('specialistId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .get();
        reports = reportsSnap.docs.map((e) => e.data()).toList();
      } catch (e) {
        debugPrint('Error fetching reports: $e');
      }

      await FirebaseAuth.instance.currentUser?.reload();
      final authEmail = FirebaseAuth.instance.currentUser?.email ?? '';

      final firestoreEmail = d['email'] ?? '';
      if (authEmail.isNotEmpty && authEmail != firestoreEmail) {
        await FirebaseFirestore.instance
            .collection('specialists')
            .doc(uid)
            .update({'email': authEmail});
        await FirebaseFirestore.instance.collection('accounts').doc(uid).update(
          {'email': authEmail},
        );
      }

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
        _reports = reports;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // Sets the specialist as offline, signs them out, and goes back to the splash screen
  Future<void> _logout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('specialists')
          .doc(uid)
          .update({'isOnline': false});
    }

    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  // Opens a zoomable full-screen preview of a certificate image
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

  // Builds the main expert screen with app bar, bottom nav, and the selected tab body
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

  // Returns the correct screen based on the selected bottom nav tab
  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const _ChatsPage();
      case 1:
        return const ExpertScheduleScreen();
      case 2:
        return _buildProfileTab();
      default:
        return const SizedBox();
    }
  }

  // Builds the bottom navigation bar with chats, schedule, and profile tabs
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

  // Listens to the specialist's Firestore document and builds the profile page with live data
  Widget _buildProfileTab() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('specialists')
          .doc(uid)
          .snapshots(),
      builder: (context, specSnapshot) {
        if (!specSnapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final d = specSnapshot.data!.data() as Map<String, dynamic>? ?? {};

        _rating = (d['rating'] ?? 0.0).toDouble();
        _reviewCount = (d['reviewCount'] ?? 0).toInt();
        _fullName = d['fullName'] ?? '';

        return SingleChildScrollView(
          child: Column(
            children: [
              _buildProfileHeader(),
              _buildTabBar(),
              _profileTabIndex == 0
                  ? _buildInfoContent()
                  : _profileTabIndex == 1
                  ? _buildReportsContent()
                  : _buildReviewsStream(uid),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // Listens to the specialist's reviews in real time and displays them as a list
  Widget _buildReviewsStream(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('specialists')
          .doc(uid)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final reviews = snapshot.data!.docs;
        if (reviews.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'لا توجد تقييمات بعد',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return Column(
          children: [
            const SizedBox(height: 12),
            ...reviews.map(
              (doc) => _reviewCard(doc.data() as Map<String, dynamic>),
            ),
          ],
        );
      },
    );
  }

  // Builds the green gradient header showing the specialist's name, star rating, and edit button
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
                      '${_rating.toStringAsFixed(1)} ($_reviewCount تقييمات)',
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

  // Builds the three-tab bar for switching between info, reports, and reviews
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

  // Opens a bottom sheet where the specialist can submit a request to edit their profile info
  void _showEditRequestSheet() {
    final nameController = TextEditingController(text: _fullName);
    final certificatesController = TextEditingController(text: _certificates);
    final experienceController = TextEditingController(text: _experience);
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
              MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'طلب تعديل المعلومات',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _editField(
                          'الاسم الكامل',
                          nameController,
                          hintText: 'مثال: محمد علي العمري',
                        ),
                        _editField(
                          'الخبرة',
                          experienceController,
                          maxLines: 3,
                          hintText: 'مثال: 10 سنوات في مجال علم النبات والتشخيص الزراعي',
                        ),
                        _editField(
                          'الشهادات',
                          certificatesController,
                          maxLines: 3,
                          hintText: 'مثال: بكالوريوس علوم زراعية، جامعة الملك سعود',
                        ),
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
                              setSheet(() {
                                newImages.addAll(picked.map((e) => File(e.path)));
                              });
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
                                const Icon(Icons.add_photo_alternate_outlined, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  newImages.isEmpty
                                      ? 'اضغط لإضافة صور الشهادات'
                                      : 'إضافة المزيد من الصور',
                                  style: TextStyle(
                                    color: newImages.isNotEmpty ? const Color(0xFF16A34A) : Colors.grey,
                                  ),
                                ),
                                const Spacer(),
                                if (newImages.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${newImages.length} صورة',
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
                        ),

                        if (newImages.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1,
                            ),
                            itemCount: newImages.length,
                            itemBuilder: (_, i) => Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    newImages[i],
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => setSheet(() => newImages.removeAt(i)),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(3),
                                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ]
                    ),
                  ),
                ),

                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
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
                                  fontWeight: FontWeight.bold,
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
      ),
    );
  }

  // A labeled text input field used inside the edit request sheet
  Widget _editField(
      String label,
      TextEditingController controller, {
        int maxLines = 1,
        String? hintText,
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
              hintText: hintText,
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              hintTextDirection: TextDirection.rtl,
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

  // Uploads new certificate images and submits the edit request to Firestore for admin review
  Future<void> _submitEditRequest({
    required String newFullName,
    required String newExperience,
    required String newCertificates,
    required List<File> newImages,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    List<String> newImageUrls = [];
    for (int i = 0; i < newImages.length; i++) {
      String? url = await ImageUploadService.uploadImage(newImages[i]);
      if (url != null) {
        newImageUrls.add(url);
      }
    }

    await FirebaseFirestore.instance.collection('Specialist_edit_request').add({
      'specialistId': uid,
      'specialistName': _fullName,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
      'rejectionReason': '',
      'newFullName': newFullName,
      'newExperience': newExperience,
      'newCertificates': newCertificates,
      'newCertificateImages': newImageUrls,
      'oldFullName': _fullName,
      'oldExperience': _experience,
      'oldCertificates': _certificates,
      'oldCertificateImages': _certificateImages,
    });
  }

  // Confirms with the specialist, re-authenticates, then deletes all their data and account
  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'حذف الحساب نهائياً',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'هذا الإجراء لا يمكن التراجع عنه. سيتم حذف:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              _deleteItem('بياناتك الشخصية'),
              _deleteItem('جميع تقاريرك'),
              _deleteItem('تقييماتك من المستخدمين'),
              _deleteItem('طلبات التعديل المعلقة'),
              _deleteItem('حسابك بشكل كامل'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'لا يمكن استرجاع أي بيانات بعد الحذف',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'حذف حسابي',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    final passwordController = TextEditingController();
    bool obscure = true;

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'تأكيد الهوية',
              style: TextStyle(
                color: Color(0xFF14532D),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أدخل كلمة المرور الحالية لتأكيد حذف الحساب.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Color(0xFF16A34A),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(ctx, passwordController.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'تأكيد الحذف',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (password == null || password.isEmpty) return;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF16A34A)),
        ),
      );
    }

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final uid = user.uid;

      final credential = EmailAuthProvider.credential(
        email: _email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      await Future.wait([
        FirebaseFirestore.instance.collection('specialists').doc(uid).delete(),

        FirebaseFirestore.instance.collection('accounts').doc(uid).delete(),

        _deleteCollection('specialist_reports', 'specialistId', uid),

        _deleteCollection('Specialist_edit_request', 'specialistId', uid),
      ]);

      await _deleteSubCollection('specialists', uid, 'reviews');

      await user.delete();

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context);
      String msg = 'حدث خطأ أثناء الحذف';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'كلمة المرور غير صحيحة';
      } else if (e.code == 'requires-recent-login') {
        msg = 'يرجى تسجيل الخروج والدخول مجدداً ثم المحاولة';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, textDirection: TextDirection.rtl),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ: $e', textDirection: TextDirection.rtl),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Deletes all documents in a collection where a specific field matches the specialist's uid
  Future<void> _deleteCollection(
    String collection,
    String field,
    String uid,
  ) async {
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .where(field, isEqualTo: uid)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  // Deletes all documents inside a sub-collection under a specific parent document
  Future<void> _deleteSubCollection(
    String parent,
    String docId,
    String sub,
  ) async {
    final snap = await FirebaseFirestore.instance
        .collection(parent)
        .doc(docId)
        .collection(sub)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  // A small row with a red icon used to list what will be deleted in the delete account dialog
  Widget _deleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.remove_circle_outline, color: Colors.red, size: 14),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  // Builds the info tab showing personal info, professional info, certificate images, security options, and logout
  Widget _buildInfoContent() {
    return Column(
      children: [
        const SizedBox(height: 12),

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

        if (_certificateImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildCertificateImages(),
        ],

        const SizedBox(height: 16),

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
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
                ),
                onTap: _showChangePasswordDialog,
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              ListTile(
                leading: const Icon(
                  Icons.email_outlined,
                  color: Color(0xFF16A34A),
                ),
                title: const Text(
                  'تغيير البريد الإلكتروني',
                  style: TextStyle(fontSize: 14),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey,
                ),
                onTap: _showChangeEmailDialog,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),


        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _deleteAccount,
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text(
                'حذف الحساب',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),


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


// Sends a password reset email to the specialist's current email address
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

// Lets the specialist enter a new email and sends a verification link to it
  void _showChangeEmailDialog() {
    final emailController = TextEditingController();
    String? emailError;
    bool saving = false;

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
              'تغيير البريد الإلكتروني',
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
                  'أدخل بريدك الإلكتروني الجديد. سيتم إرسال رابط تحقق إليه.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  onChanged: (v) => setDialogState(() {
                    emailError = v.trim().isEmpty
                        ? 'البريد الإلكتروني مطلوب'
                        : !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())
                        ? 'صيغة البريد غير صحيحة'
                        : null;
                  }),
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني الجديد',
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Color(0xFF16A34A),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    errorText: emailError,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ستحتاج لإعادة تسجيل الدخول بعد تغيير البريد',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
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
                onPressed: saving
                    ? null
                    : () async {
                        final newEmail = emailController.text.trim();
                        if (newEmail.isEmpty ||
                            !RegExp(
                              r'^[^@]+@[^@]+\.[^@]+',
                            ).hasMatch(newEmail)) {
                          setDialogState(
                            () => emailError = 'أدخل بريداً صحيحاً',
                          );
                          return;
                        }
                        if (newEmail == _email) {
                          setDialogState(
                            () => emailError = 'هذا هو بريدك الحالي',
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          final user = FirebaseAuth.instance.currentUser!;


                          await user.verifyBeforeUpdateEmail(newEmail);

                          if (!mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '✅ تم إرسال رابط التحقق إلى بريدك الجديد. تحقق منه لإتمام التغيير.',
                              ),
                              backgroundColor: Color(0xFF16A34A),
                              duration: Duration(seconds: 5),
                            ),
                          );
                        } on FirebaseAuthException catch (e) {
                          setDialogState(() => saving = false);
                          String msg = 'حدث خطأ';
                          if (e.code == 'requires-recent-login') {
                            msg =
                                'يرجى تسجيل الخروج والدخول مجدداً ثم المحاولة';
                          } else if (e.code == 'email-already-in-use') {
                            msg = 'هذا البريد مستخدم بالفعل';
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg),
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
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'إرسال رابط التحقق',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Builds a grid of the specialist's certificate images with a zoom-on-tap feature
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

  // A white card with a title and a list of rows — used to group related info fields
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

  // A thin horizontal line used between rows inside a section card
  Widget _divider() => const Divider(
    height: 1,
    color: Color(0xFFEEEEEE),
    indent: 16,
    endIndent: 16,
  );

  // A single row showing a label, a value, and an icon — used inside section cards
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

// Listens to the specialist's reports in real time and displays them as a list
  Widget _buildReportsContent() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(

      stream: FirebaseFirestore.instance
          .collection('specialist_reports')
          .where('specialistId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'حدث خطأ في جلب البيانات: \n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }


        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(50.0),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF16A34A)),
            ),
          );
        }


        final reports = snapshot.data?.docs ?? [];
        if (reports.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(60),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 70,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد تقارير طبية محفوظة حالياً',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }


        return Column(
          children: [
            const SizedBox(height: 12),
            ...reports.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _reportCard(data);
            }),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

// Builds one report card showing plant name, image, diagnosis, and suggested treatment
  Widget _reportCard(Map<String, dynamic> r) {
    final hasImage = (r['plantImage'] ?? '').toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.eco,
                  color: Color(0xFF16A34A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['plantName'] ?? 'نبات غير معروف',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF14532D),
                      ),
                    ),
                    Text(
                      'المستخدم: ${r['userName'] ?? 'مستخدم'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                r['date'] ?? '',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                r['plantImage'],
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          _detailSection('التشخيص:', r['diagnosis'] ?? 'لا يوجد تشخيص'),
          const SizedBox(height: 10),

          _detailSection(
            'العلاج المقترح:',
            r['treatment'] ?? 'لا يوجد علاج مقترح',
            isOrange: true,
          ),
        ],
      ),
    );
  }

  // A colored box showing a label and text content — used for diagnosis and treatment inside report cards
  Widget _detailSection(String label, String value, {bool isOrange = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOrange ? const Color(0xFFFFFBEB) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOrange ? const Color(0xFFFDE68A) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isOrange
                  ? const Color(0xFFD97706)
                  : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
// Builds the reviews list from the locally loaded reviews data
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

  // Builds one review card showing the user's name, star rating, and optional comment
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

class _ChatsPage extends StatefulWidget {
  const _ChatsPage();

  @override
  State<_ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<_ChatsPage> {
  String _chatFilter = 'all';
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();

  // Clean up the search controller when the chats page is removed
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Builds the chats page with search bar, filter chips, and a sorted list of all chats
  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<QuerySnapshot>(
        stream: db
            .collection('chats')
            .where('specialistId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF16A34A)),
            );
          }

          final allChats = snapshot.data?.docs ?? [];

          final activeCount = allChats
              .where((d) =>
          (d.data() as Map<String, dynamic>)['completed'] != true)
              .length;
          final completedCount = allChats
              .where((d) =>
          (d.data() as Map<String, dynamic>)['completed'] == true)
              .length;
          final totalCount = allChats.length;

          List<QueryDocumentSnapshot> filtered = allChats.where((d) {
            final data = d.data() as Map<String, dynamic>;

            final matchSearch = (data['userName'] ?? '')
                .toString()
                .toLowerCase()
                .contains(_searchText.toLowerCase());

            bool matchFilter = true;
            if (_chatFilter == 'pending') {
              matchFilter = data['completed'] != true;
            } else if (_chatFilter == 'completed') {
              matchFilter = data['completed'] == true;
            }

            return matchSearch && matchFilter;
          }).toList();

          filtered.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;

            DateTime parseTime(dynamic timeVal) {
              if (timeVal is Timestamp) return timeVal.toDate();
              if (timeVal is String && timeVal.isNotEmpty) {
                return DateTime.tryParse(timeVal) ?? DateTime(2000);
              }
              return DateTime(2000);
            }

            final timeA = parseTime(dataA['updatedAt'] ?? dataA['createdAt']);
            final timeB = parseTime(dataB['updatedAt'] ?? dataB['createdAt']);
            return timeB.compareTo(timeA);
          });

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          textDirection: TextDirection.rtl,
                          onChanged: (v) =>
                              setState(() => _searchText = v.trim()),
                          decoration: InputDecoration(
                            hintText: 'ابحث عن اسم المستخدم...',
                            hintStyle: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                            prefixIcon: _searchText.isNotEmpty
                                ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchText = '');
                                })
                                : const Icon(Icons.search,
                                color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _availChip(
                            'الكل ($totalCount)',
                            _chatFilter == 'all',
                                () => setState(() => _chatFilter = 'all'),
                          ),
                          const SizedBox(width: 8),
                          _availChip(
                            'جارية ($activeCount)',
                            _chatFilter == 'pending',
                                () => setState(() => _chatFilter = 'pending'),
                          ),
                          const SizedBox(width: 8),
                          _availChip(
                            'مكتملة ($completedCount)',
                            _chatFilter == 'completed',
                                () => setState(() => _chatFilter = 'completed'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          const Text('لا توجد دردشات حالياً',
                              style:
                              TextStyle(color: Colors.grey, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final data =
                        filtered[index].data() as Map<String, dynamic>;
                        final chatId = filtered[index].id;
                        final userName = data['userName'] ?? 'مستخدم';
                        final userId = data['userId'] ?? '';
                        final lastMessage = data['lastMessage'] ?? '';
                        final time = data['time'] ?? '';
                        final unread = data['expertUnread'] ?? 0;
                        final isCompleted = data['completed'] == true;

                        return GestureDetector(
                          onTap: () {
                            FirebaseFirestore.instance
                                .collection('chats')
                                .doc(chatId)
                                .update({'expertUnread': 0});

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExpertChatScreen(
                                  chatId: chatId,
                                  userName: userName,
                                  userId: userId,
                                ),
                              ),
                            );
                          },
                          onLongPress: () => _confirmDeleteChat(chatId, userName),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border:
                              Border.all(color: const Color(0xFFE1F1E4)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: const Color(0xFFDDF7DD),
                                  child: Text(
                                    userName.isNotEmpty ? userName[0] : 'م',
                                    style: const TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              userName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Color(0xFF2F3A33),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isCompleted
                                                  ? const Color(0xFF16A34A)
                                                  : Colors.orange,
                                              borderRadius:
                                              BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              isCompleted ? 'مكتملة' : 'جارية',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              lastMessage,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[600]),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            time,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[400]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (unread > 0) ...[
                                  const SizedBox(width: 10),
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: const Color(0xFF16A34A),
                                    child: Text(
                                      '$unread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // Confirms with the specialist then deletes the chat and all its linked reports and feed posts
  Future<void> _confirmDeleteChat(String chatId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('حذف المحادثة',
              style: TextStyle(
                  color: Color(0xFF14532D), fontWeight: FontWeight.bold)),
          content: Text('هل تريد حذف محادثة $userName؟ سيتم أيضاً حذف أي تقارير مشتركة مرتبطة بها.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, elevation: 0),
              child: const Text('حذف',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final db = FirebaseFirestore.instance;

      final feedSnap = await db.collection('community_feed').where('chatId', isEqualTo: chatId).get();
      for (var doc in feedSnap.docs) {
        await doc.reference.delete();
      }

      final reportSnap = await db.collection('specialist_reports').where('chatId', isEqualTo: chatId).get();
      for (var doc in reportSnap.docs) {
        await doc.reference.delete();
      }

      await db.collection('chats').doc(chatId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ تم حذف المحادثة والتقارير المرتبطة بها'),
            backgroundColor: Color(0xFF2D322C),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // A filter chip that highlights when active — used to filter chats by all, active, or completed
  Widget _availChip(String label, bool isActive, VoidCallback onTap) {
    const activeColor = Color(0xFF16A34A);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? activeColor : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[700],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}