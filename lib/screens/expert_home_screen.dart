import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';
import 'requests_screen.dart';
import 'expert_chat_screen.dart';
import 'expert_schedule_screen.dart';

class ExpertHomeScreen extends StatefulWidget {
  const ExpertHomeScreen({super.key});

  @override
  State<ExpertHomeScreen> createState() => _ExpertHomeScreenState();
}

class _ExpertHomeScreenState extends State<ExpertHomeScreen> {
  int _currentIndex = 0;
  int _profileTabIndex = 0;

  String _name = '';
  String _specialty = '';
  double _rating = 0.0;
  int _reviewCount = 0;
  int _responseTime = 15;
  int _successRate = 96;
  int _totalCases = 0;
  String _education = '';
  String _experience = '';
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
      final doc = await FirebaseFirestore.instance
          .collection('specialists')
          .doc(uid)
          .get();

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

      if (!mounted) return;
      final d = doc.data() ?? {};
      setState(() {
        _name        = d['fullName'] ?? d['name'] ?? d['username'] ?? '';
        _specialty   = d['specialty'] ?? (d['specializations'] is List && (d['specializations'] as List).isNotEmpty ? (d['specializations'] as List)[0].toString() : '');
        _rating      = (d['rating'] is num) ? (d['rating'] as num).toDouble() : 0.0;
        _reviewCount = d['reviewCount'] ?? 0;
        _responseTime = (d['responseTime'] is num) ? (d['responseTime'] as num).toInt() : 15;
        _successRate = (d['successRate'] is num) ? (d['successRate'] as num).toInt() : 96;
        _totalCases  = (d['totalCases'] is num) ? (d['totalCases'] as num).toInt() : 0;
        _education   = d['education'] ?? '';
        _experience  = (d['experience'] != null) ? d['experience'].toString() : '';
        _reviews     = reviews;
        _loading     = false;
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: false, // مضافة لمنع تداخل الكيبورد
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
                child: const Icon(
                  Icons.logout,
                  color: Color(0xFF16A34A),
                ),
              ),
              onPressed: _logout,
            ),
          ],
        ),
        body: _loading
            ? const Center(
            child: CircularProgressIndicator(
                color: Color(0xFF16A34A)))
            : _buildBody(),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildProfileTab();
      case 1:
        return const ExpertScheduleScreen();
      case 2:
        return const _ChatsPage();
      case 3:
        return const RequestsScreen();
      default:
        return const SizedBox();
    }
  }

  // ── Bottom Nav ────────────────────────────────────────────────
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
          label: 'الملف',
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
          _buildStatsRow(),
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
                _name.isNotEmpty ? _name[0].toUpperCase() : 'خ',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name.isNotEmpty ? 'د. $_name' : 'د. الخبير',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                if (_specialty.isNotEmpty)
                  Text(_specialty,
                      style: const TextStyle(
                          color: Color(0xFFBBF7D0), fontSize: 12)),
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
                        )),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${_rating.toStringAsFixed(1)} ($_reviewCount تقييم)',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    if (_totalCases == 0) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          _statItem('$_responseTime دقيقة', 'متوسط الرد'),
          _vDivider(),
          _statItem('$_successRate%', 'نسبة النجاح'),
          _vDivider(),
          _statItem('$_totalCases', 'حالة تم حلها'),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF14532D))),
          const SizedBox(height: 2),
          Text(label,
              style:
              const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
      width: 1, height: 32, color: const Color(0xFFE5E7EB));

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
                padding:
                const EdgeInsets.symmetric(vertical: 12),
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
                child: Text(tabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: selected
                          ? const Color(0xFF16A34A)
                          : Colors.grey,
                    )),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildInfoContent() {
    return Column(
      children: [
        const SizedBox(height: 12),
        if (_specialty.isNotEmpty)
          _sectionCard(
            title: 'التخصصات',
            child: Text(_specialty,
                style: const TextStyle(
                    fontSize: 13, color: Colors.black87)),
          ),
        const SizedBox(height: 12),
        if (_education.isNotEmpty || _experience.isNotEmpty)
          _sectionCard(
            title: 'المعلومات المهنية',
            child: Column(
              children: [
                if (_education.isNotEmpty) ...[
                  _infoItem(Icons.school_outlined, _education),
                  const SizedBox(height: 10),
                ],
                if (_experience.isNotEmpty)
                  _infoItem(Icons.work_outline, _experience),
              ],
            ),
          ),
      ],
    );
  }

  Widget _infoItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF16A34A), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.5)),
        ),
      ],
    );
  }

  Widget _buildReportsContent() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text('لا توجد تقارير حالياً',
            style:
            TextStyle(color: Colors.grey, fontSize: 14)),
      ),
    );
  }

  Widget _buildReviewsContent() {
    if (_reviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('لا توجد تقييمات بعد',
              style: TextStyle(
                  color: Colors.grey, fontSize: 14)),
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
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['userName'] ?? 'مستخدم',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.black87)),
                    Row(
                      children: List.generate(
                        5,
                            (i) => Icon(
                          i < rating
                              ? Icons.star
                              : Icons.star_border,
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
            Text(r['comment'],
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _sectionCard(
      {required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 12),
          child,
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
              child: Text('لا توجد محادثات',
                  style:
                  TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final data =
              chats[index].data() as Map<String, dynamic>;
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
                      isOnline: online, // تمرير المعامل المطلوب
                    ),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10), // استخدام only بدلاً من .bottom
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFbbf7d0)),
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
                            backgroundColor:
                            const Color(0xFFdcfce7),
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0]
                                  : '؟',
                              style: const TextStyle(
                                  color: Color(0xFF15803d),
                                  fontSize: 18),
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
                                      width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Text(userName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Text(time,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500])),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(lastMessage,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 11,
                          backgroundColor:
                          const Color(0xFF16A34A),
                          child: Text('$unread',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11)),
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