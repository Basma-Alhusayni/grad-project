import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';
import 'requests_screen.dart';
import 'chat_with_user_screen.dart';
import 'expert_schedule_screen.dart';

class ExpertHomeScreen extends StatefulWidget {
  const ExpertHomeScreen({super.key});
  @override
  State<ExpertHomeScreen> createState() => _ExpertHomeScreenState();
}

class _ExpertHomeScreenState extends State<ExpertHomeScreen> {
  String _name = '';
  bool _loading = true;
  int _currentIndex = 3;

  @override
  void initState() {
    super.initState();
    _fetchName();
  }

  Future<void> _fetchName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('specialists')
        .doc(uid)
        .get();
    if (!mounted) return;
    setState(() {
      _name = doc.data()?['fullName'] ?? doc.data()?['username'] ?? '';
      _loading = false;
    });
  }

  List<Widget> get _pages => [
    _ProfilePage(name: _name),
    const ExpertScheduleScreen(),
    const _ChatsPage(),
    const RequestsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0FDF4),
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'خبير النباتات',
            style: TextStyle(
              color: Color(0xFF166534),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              'assets/images/logo.png',
              errorBuilder: (_, __, ___) =>
              const Icon(Icons.eco, color: Color(0xFF16A34A)),
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 1,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFF16A34A)),
              onPressed: () async {
                await AuthService().signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                      (_) => false,
                );
              },
            ),
          ],
        ),
        body: _loading
            ? const Center(
            child: CircularProgressIndicator(
                color: Color(0xFF16A34A)))
            : _pages[_currentIndex],
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.person_outline, 'الملف'),
              _navItem(1, Icons.calendar_today_outlined, 'الجدول'),
              _navItem(2, Icons.chat_bubble_outline, 'المحادثات'),
              _navItem(3, Icons.assignment_outlined, 'الطلبات'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFF16A34A) : Colors.grey[400],
            size: 26,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
              isSelected ? FontWeight.bold : FontWeight.normal,
              color:
              isSelected ? const Color(0xFF16A34A) : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 2),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: isSelected ? 20 : 0,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
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
                    builder: (_) => ChatWithUserScreen(
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
                    border:
                    Border.all(color: const Color(0xFFbbf7d0)),
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
                                      color: Colors.white, width: 2),
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
                          backgroundColor: const Color(0xFF16A34A),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
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

// ─── صفحة الملف الشخصي ───────────────────────────────────────
class _ProfilePage extends StatelessWidget {
  final String name;
  const _ProfilePage({required this.name});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: RichText(
                textAlign: TextAlign.right,
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF14532D)),
                  children: [
                    const TextSpan(text: 'مرحباً '),
                    TextSpan(
                      text: name,
                      style:
                      const TextStyle(color: Color(0xFF16A34A)),
                    ),
                    const TextSpan(text: ' !'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'لوحة تحكم الخبير',
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}