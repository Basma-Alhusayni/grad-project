import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';
import 'admin_shared_reports_screen.dart'; // ← NEW IMPORT

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 2;
  String _name = '';
  String _email = '';
  bool _loading = true;
  String _searchQuery = '';
  String _filterStatus = 'active';
  String selectedStatus = 'pending';
  String _selectedEditStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  Future<void> _fetchAdminData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.reload();
    final authEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final doc = await FirebaseFirestore.instance
        .collection('admins')
        .doc(user.uid)
        .get();
    final firestoreEmail = doc.data()?['email'] ?? '';
    if (authEmail.isNotEmpty && authEmail != firestoreEmail) {
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .update({'email': authEmail});
      await FirebaseFirestore.instance
          .collection('accounts')
          .doc(user.uid)
          .update({'email': authEmail});
    }
    if (!mounted) return;
    setState(() {
      _name = doc.data()?['username'] ?? '';
      _email = authEmail.isNotEmpty ? authEmail : firestoreEmail;
      _loading = false;
    });
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

  void _showFullImage(String url) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'معاينة الوثيقة',
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
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4))
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(
                      maxScale: 4.0,
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            color: const Color(0xFFF3F4F6),
                            child: const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF16A34A)),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          height: 200,
                          width: double.infinity,
                          color: const Color(0xFFFEF2F2),
                          child: const Icon(Icons.broken_image,
                              color: Colors.red, size: 48),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(padding: EdgeInsets.only(bottom: 16)),
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
        // ── UPDATED BODY SWITCH ──────────────────────────────────
        body: _loading
            ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF16A34A)))
            : _currentIndex == 0
            ? _buildUsersTab()
            : _currentIndex == 1
            ? _buildSpecialistsTab()
            : _currentIndex == 2
            ? _buildRequestsTab()
            : _currentIndex == 3
            ? _buildEditRequestsTab()
            : _currentIndex == 4
            ? const AdminSharedReportsScreen()   // ← NEW TAB
            : _buildProfileTab(),
        // ── UPDATED BOTTOM NAV (6 items) ────────────────────────
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: const Color(0xFF16A34A),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 8,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'المستخدمين',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.verified_user_outlined),
              activeIcon: Icon(Icons.verified_user),
              label: 'الخبراء',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_add_outlined),
              activeIcon: Icon(Icons.person_add),
              label: 'طلبات الانضمام',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.edit_note_outlined),
              activeIcon: Icon(Icons.edit_note),
              label: 'طلبات التعديل',
            ),
            BottomNavigationBarItem(          // ← NEW
              icon: Icon(Icons.public_outlined),
              activeIcon: Icon(Icons.public),
              label: 'المنشورات',
            ),
            BottomNavigationBarItem(          // ← Profile shifted to index 5
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'الملف الشخصي',
            ),
          ],
        ),
      ),
    );
  }

// ── Users management Tab ────────────────────────────────────────────
  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'البحث عن مستخدم...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
          ),
        ),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, usersSnap) {
            if (!usersSnap.hasData) return const SizedBox();

            final users = usersSnap.data!.docs;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('accounts')
                  .snapshots(),
              builder: (context, accSnap) {
                if (!accSnap.hasData) return const SizedBox();

                final accounts = accSnap.data!.docs;

                int active = 0;
                int disabled = 0;

                for (var user in users) {
                  final userId = user.id;

                  final acc = accounts.where((a) => a['accountId'] == userId);

                  if (acc.isNotEmpty) {
                    final status = acc.first['status'];

                    if (status == 'active') {
                      active++;
                    } else {
                      disabled++;
                    }
                  }
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _filterStatus = 'active';
                            });
                          },
                          child: _statBox(
                            "$active",
                            "مستخدم نشط",
                            Colors.green,
                            _filterStatus == 'active',
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _filterStatus = 'disabled';
                            });
                          },
                          child: _statBox(
                            "$disabled",
                            "مستخدم معطل",
                            Colors.red,
                            _filterStatus == 'disabled',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),

        const SizedBox(height: 10),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, usersSnap) {
              if (!usersSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('accounts')
                    .snapshots(),
                builder: (context, accSnap) {
                  if (!accSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = usersSnap.data!.docs;
                  final accounts = accSnap.data!.docs;

                  final combined = users.map((user) {
                    final data = user.data() as Map<String, dynamic>;
                    final uid = user.id;

                    final accList = accounts.where((a) => a.id == uid).toList();

                    final accData = accList.isNotEmpty
                        ? accList.first.data() as Map<String, dynamic>
                        : {};

                    return {
                      ...data,
                      'uid': uid,
                      'status': accData['status'] ?? 'active',
                      'createdAt': accData['createdAt'],
                    };
                  }).toList();

                  final filtered = combined.where((user) {
                    final name =
                    (user['username'] ?? '').toString().toLowerCase();

                    if (!name.contains(_searchQuery)) return false;

                    if (_filterStatus == 'active') {
                      return user['status'] == 'active';
                    }

                    if (_filterStatus == 'disabled') {
                      return user['status'] != 'active';
                    }

                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            _filterStatus == 'active'
                                ? 'لا يوجد مستخدمين نشطين'
                                : _filterStatus == 'disabled'
                                ? 'لا يوجد مستخدمين معطلين'
                                : 'لا يوجد مستخدمين',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 15),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final user = filtered[index];

                      final status = user['status'];
                      final uid = user['uid'];

                      DateTime? createdAt =
                      (user['createdAt'] as Timestamp?)?.toDate();

                      String formattedDate = createdAt != null
                          ? "${createdAt.day}-${createdAt.month}-${createdAt
                          .year}"
                          : "";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [

                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [

                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: status == 'active'
                                                ? Colors.green
                                                : Colors.grey,
                                            borderRadius: BorderRadius.circular(
                                                12),
                                          ),
                                          child: Text(
                                            status == 'active' ? 'نشط' : 'معطل',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11),
                                          ),
                                        ),

                                        const SizedBox(width: 8),

                                        Text(
                                          user['username'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      user['email'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.grey),
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      "تاريخ الانضمام • $formattedDate",
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            PopupMenuButton<String>(
                              icon: const Icon(
                                  Icons.more_vert, color: Colors.grey),
                              onSelected: (value) {
                                if (value == 'view') {
                                  _showUserDetails(
                                      user, status, formattedDate, uid);
                                } else if (value == 'toggle') {
                                  _toggleStatus(uid, status);
                                }
                              },
                              itemBuilder: (context) =>
                              [
                                const PopupMenuItem(
                                  value: 'view',
                                  child: Row(
                                    children: [
                                      Icon(Icons.visibility, size: 18),
                                      SizedBox(width: 8),
                                      Text('عرض التفاصيل'),
                                    ],
                                  ),
                                ),

                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Row(
                                    children: [
                                      Icon(Icons.block, size: 18),
                                      SizedBox(width: 8),
                                      Text(status == 'active'
                                          ? 'تعطيل الحساب'
                                          : 'تفعيل الحساب'),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }

  Widget _statBox(String count, String label, MaterialColor color,
      bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isSelected ? color.shade100 : color.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? color.shade600 : color.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isSelected ? color.shade800 : color.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? color.shade700 : color.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(
      Map<String, dynamic> data,
      String status,
      String createdAt,
      String userId,
      ) async {
    final reportsSnapshot = await FirebaseFirestore.instance
        .collection('reports')
        .where('userId', isEqualTo: userId)
        .count()
        .get();

    final reportsCount = reportsSnapshot.count;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Center(
                child: Text(
                  'معلومات المستخدم',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),

              _detailRow('الاسم', data['username'] ?? ''),
              _detailRow('البريد الإلكتروني', data['email'] ?? ''),
              _detailRow('تاريخ الانضمام', createdAt),
              _detailRow('عدد التقارير', reportsCount.toString()),

              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'active' ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status == 'active' ? 'نشط' : 'معطل',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const Text('حالة الحساب', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFFFFF),
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _toggleStatus(String uid, String status) async {
    final newStatus = status == 'active' ? 'suspended' : 'active';

    await FirebaseFirestore.instance
        .collection('accounts')
        .doc(uid)
        .update({
      'status': newStatus,
    });

    setState(() {});
  }

// ── Specialists management Tab ────────────────────────────────────────────
  Widget _buildSpecialistsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'البحث عن خبير...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
          ),
        ),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('specialists')
              .snapshots(),
          builder: (context, specSnap) {
            if (!specSnap.hasData) return const SizedBox();

            final specialists = specSnap.data!.docs;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('accounts')
                  .snapshots(),
              builder: (context, accSnap) {
                if (!accSnap.hasData) return const SizedBox();

                final accounts = accSnap.data!.docs;

                int active = 0;
                int disabled = 0;

                for (var spec in specialists) {
                  final accountId = spec['accountId'];

                  final accList =
                  accounts.where((a) => a['accountId'] == accountId);

                  if (accList.isNotEmpty) {
                    final status = accList.first['status'];

                    if (status == 'active') {
                      active++;
                    } else {
                      disabled++;
                    }
                  }
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _filterStatus = 'active'),
                          child: _statBox(
                            "$active",
                            "خبير نشط",
                            Colors.green,
                            _filterStatus == 'active',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _filterStatus = 'disabled'),
                          child: _statBox(
                            "$disabled",
                            "خبير معطل",
                            Colors.red,
                            _filterStatus == 'disabled',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),

        const SizedBox(height: 10),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('specialists')
                .snapshots(),
            builder: (context, specSnap) {
              if (!specSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('accounts')
                    .snapshots(),
                builder: (context, accSnap) {
                  if (!accSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final specialists = specSnap.data!.docs;
                  final accounts = accSnap.data!.docs;

                  final combined = specialists.map((spec) {
                    final data = spec.data() as Map<String, dynamic>;
                    final accountId = data['accountId'];

                    final accList = accounts
                        .where((a) => a['accountId'] == accountId)
                        .toList();

                    final accData = accList.isNotEmpty
                        ? accList.first.data() as Map<String, dynamic>
                        : {};

                    return {
                      ...data,
                      'status': accData['status'] ?? 'active',
                    };
                  }).toList();

                  final filtered = combined.where((spec) {
                    final name =
                    (spec['fullName'] ?? '').toString().toLowerCase();

                    if (!name.contains(_searchQuery)) return false;

                    if (_filterStatus == 'active') {
                      return spec['status'] == 'active';
                    }

                    if (_filterStatus == 'disabled') {
                      return spec['status'] != 'active';
                    }

                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            _filterStatus == 'active'
                                ? 'لا يوجد خبراء نشطين'
                                : _filterStatus == 'disabled'
                                ? 'لا يوجد خبراء معطلين'
                                : 'لا يوجد خبراء',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 15),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final spec = filtered[index];

                      final status = spec['status'];
                      final accountId = spec['accountId'];

                      DateTime? createdAt =
                      (spec['createdAt'] as Timestamp?)?.toDate();

                      String formattedDate = createdAt != null
                          ? "${createdAt.year}-${createdAt.month}-${createdAt
                          .day}"
                          : "";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [

                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [

                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: status == 'active'
                                                ? Colors.green
                                                : Colors.grey,
                                            borderRadius: BorderRadius.circular(
                                                12),
                                          ),
                                          child: Text(
                                            status == 'active' ? 'نشط' : 'معطل',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11),
                                          ),
                                        ),

                                        const SizedBox(width: 8),

                                        Text(
                                          spec['fullName'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      spec['email'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.grey),
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      "تاريخ الانضمام • $formattedDate",
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                if (value == 'view') {
                                  _showSpecialistDetails(
                                      spec, status, formattedDate);
                                } else if (value == 'toggle') {
                                  _toggleStatus(accountId, status);
                                }
                              },
                              itemBuilder: (context) =>
                              [
                                const PopupMenuItem(
                                  value: 'view',
                                  child: Row(
                                    children: [
                                      Icon(Icons.visibility),
                                      SizedBox(width: 8),
                                      Text('عرض التفاصيل'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Row(
                                    children: [
                                      Icon(Icons.block, size: 18),
                                      SizedBox(width: 8),
                                      Text(status == 'active'
                                          ? 'تعطيل الحساب'
                                          : 'تفعيل الحساب'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showSpecialistDetails(
      Map<String, dynamic> data,
      String status,
      String createdAt,
      ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Center(
                child: Text(
                  'تفاصيل الخبير',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),

              const SizedBox(height: 20),

              _detailRow('الاسم', data['fullName'] ?? ''),
              _detailRow('البريد', data['email'] ?? ''),
              _detailRow('تاريخ الانضمام', createdAt),
              _detailRow('عدد الحالات', data['reviewCount']?.toString() ?? '0'),
              _detailRow('التقييم', data['rating']?.toString() ?? '0.0'),
              _detailRow('الخبرة', data['experience'] ?? ''),
              _detailRow('الشهادات', data['certificates'] ?? ''),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: status == 'active' ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status == 'active' ? 'نشط' : 'معطل',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const Text('حالة الحساب', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFFFFF),
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'إغلاق',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

// ── Requests Tab ────────────────────────────────────────────
  Widget _buildRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('specialist_requests')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        final pending = docs
            .where((d) => (d.data() as Map)['status'] == 'pending')
            .length;
        final approved = docs
            .where((d) => (d.data() as Map)['status'] == 'approved')
            .length;
        final rejected = docs
            .where((d) => (d.data() as Map)['status'] == 'rejected')
            .length;

        return Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _filterCard('pending', 'معلقة', Colors.orange,
                      Icons.pending_actions, pending),
                  const SizedBox(width: 10),
                  _filterCard('approved', 'موافق عليها', Colors.green,
                      Icons.check_circle_outline, approved),
                  const SizedBox(width: 10),
                  _filterCard('rejected', 'مرفوضة', Colors.red,
                      Icons.cancel_outlined, rejected),
                ],
              ),
            ),
            Expanded(
              child: _requestsList(selectedStatus),
            ),
          ],
        );
      },
    );
  }

  Widget _filterCard(
      String status,
      String label,
      MaterialColor color,
      IconData icon,
      int count,
      ) {
    final isSelected = selectedStatus == status;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            selectedStatus = status;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.shade100 : color.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color.shade600 : color.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? color.shade800 : color.shade600,
                  size: 26),

              const SizedBox(height: 6),

              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color.shade800 : color.shade700,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? color.shade700 : color.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requestsList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('specialist_requests')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child:
              CircularProgressIndicator(color: Color(0xFF16A34A)));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  status == 'pending'
                      ? 'لا توجد طلبات معلقة'
                      : status == 'approved'
                      ? 'لا توجد طلبات موافق عليها'
                      : 'لا توجد طلبات مرفوضة',
                  style:
                  const TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            return _buildRequestCard(data, docId, status);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(
      Map<String, dynamic> data, String docId, String status) {
    final statusColor = status == 'pending'
        ? Colors.orange
        : status == 'approved'
        ? Colors.green
        : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFDCFCE7),
                  child: Text(
                    (data['fullName'] ?? 'خ')[0],
                    style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['fullName'] ?? 'غير محدد',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF14532D)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data['email'] ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                    Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    status == 'pending'
                        ? 'معلق'
                        : status == 'approved'
                        ? 'موافق عليه'
                        : 'مرفوض',
                    style: TextStyle(fontSize: 11, color: statusColor),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _requestRow(Icons.workspace_premium_outlined,
                    'الشهادات', data['certificates'] ?? '—'),
                const SizedBox(height: 8),
                _requestRow(Icons.history_edu_outlined, 'الخبرة',
                    data['experience'] ?? '—'),
                if (data['certificateImages'] != null &&
                    (data['certificateImages'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'الصور المرفقة:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount:
                      (data['certificateImages'] as List).length,
                      itemBuilder: (context, i) {
                        final imgUrl =
                        data['certificateImages'][i].toString();
                        return GestureDetector(
                          onTap: () => _showFullImage(imgUrl),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.grey.shade200),
                              image: DecorationImage(
                                  image: NetworkImage(imgUrl),
                                  fit: BoxFit.cover),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (status == 'rejected' &&
                    (data['rejectionReason'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border:
                      Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('سبب الرفض:',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(data['rejectionReason'],
                            style: const TextStyle(
                                fontSize: 13, color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (status == 'pending')
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _approveRequest(data, docId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.check,
                          color: Colors.white, size: 16),
                      label: const Text('قبول',
                          style: TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showRejectDialog(data, docId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFCC0000),
                        side: const BorderSide(
                            color: Color(0xFFCC0000)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.close,
                          color: Color(0xFFCC0000), size: 16),
                      label: const Text('رفض',
                          style: TextStyle(
                              color: Color(0xFFCC0000),
                              fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _requestRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF16A34A), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _approveRequest(
      Map<String, dynamic> data, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('تأكيد القبول',
              style: TextStyle(
                  color: Color(0xFF14532D),
                  fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('هل تريد قبول طلب ${data['fullName'] ?? ''}؟'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border:
                  Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Row(children: [
                  Icon(Icons.email_outlined,
                      color: Color(0xFF16A34A), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سيتم إرسال رابط تعيين كلمة المرور إلى بريده الإلكتروني تلقائياً',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF166534)),
                    ),
                  ),
                ]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('قبول',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child:
          CircularProgressIndicator(color: Color(0xFF16A34A)),
        ),
      );
    }

    final err = await AuthService().approveSpecialistRequest(
      requestData: data,
      requestDocId: docId,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('حدث خطأ: $err'),
          backgroundColor: Colors.red));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ تم قبول ${data['fullName'] ?? ''} | تم إرسال رابط تعيين كلمة المرور إلى بريده'),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showRejectDialog(Map<String, dynamic> data, String docId) {
    final reasonController = TextEditingController();
    String? reasonError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              const Icon(Icons.cancel_outlined,
                  color: Color(0xFFCC0000), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'رفض طلب ${data['fullName'] ?? ''}',
                  style: const TextStyle(
                      color: Color(0xFF14532D),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ]),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                            const Color(0xFFDCFCE7),
                            child: Text(
                              (data['fullName'] ?? 'خ')[0],
                              style: const TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(data['fullName'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Text(data['email'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('سبب الرفض *',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      textDirection: TextDirection.rtl,
                      onChanged: (v) {
                        setDialogState(() {
                          reasonError = v.trim().isEmpty
                              ? 'سبب الرفض مطلوب'
                              : null;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'اكتب سبب الرفض هنا...',
                        hintStyle: TextStyle(
                            fontSize: 12, color: Colors.grey[400]),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFFCC0000), width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                        errorText: reasonError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.email_outlined,
                            color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'سيتم إرسال سبب الرفض إلى بريد المتقدم تلقائياً',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9A3412)),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                      ),
                      child: const Text('إلغاء',
                          style:
                          TextStyle(color: Colors.black38)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final reason =
                        reasonController.text.trim();
                        if (reason.isEmpty) {
                          setDialogState(() =>
                          reasonError = 'سبب الرفض مطلوب');
                          return;
                        }
                        Navigator.pop(ctx);
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF16A34A)),
                          ),
                        );
                        final err = await AuthService()
                            .rejectSpecialistRequest(
                          requestDocId: docId,
                          expertEmail: data['email'] ?? '',
                          expertName: data['fullName'] ?? '',
                          rejectionReason: reason,
                        );
                        if (!mounted) return;
                        Navigator.pop(context);
                        if (err != null) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                              content: Text('حدث خطأ: $err'),
                              backgroundColor: Colors.red));
                        } else {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: Text(
                                '❌ تم رفض طلب ${data['fullName']}'),
                            backgroundColor:
                            const Color(0xFF2D322C),
                          ));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCC0000),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text('رفض الطلب',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

// ── Edit requests Tab ────────────────────────────────────────────
  Widget _buildEditRequestsTab() {
    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Specialist_edit_request')
              .snapshots(),
          builder: (context, snap) {
            final docs = snap.data?.docs ?? [];
            final pending = docs.where((d) =>
            (d.data() as Map)['status'] == 'pending').length;
            final approved = docs.where((d) =>
            (d.data() as Map)['status'] == 'approved').length;
            final rejected = docs.where((d) =>
            (d.data() as Map)['status'] == 'rejected').length;

            return Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                _editFilterCard('pending', 'معلقة', Colors.orange,
                    Icons.pending_actions, pending),
                const SizedBox(width: 10),
                _editFilterCard('approved', 'موافق عليها', Colors.green,
                    Icons.check_circle_outline, approved),
                const SizedBox(width: 10),
                _editFilterCard('rejected', 'مرفوضة', Colors.red,
                    Icons.cancel_outlined, rejected),
              ]),
            );
          },
        ),
        Expanded(child: _editRequestsList()),
      ],
    );
  }

  Widget _editFilterCard(String status, String label, MaterialColor color,
      IconData icon, int count) {
    final isSelected = _selectedEditStatus == status;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selectedEditStatus = status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.shade100 : color.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color.shade600 : color.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(children: [
            Icon(icon,
                color: isSelected ? color.shade800 : color.shade600,
                size: 26),
            const SizedBox(height: 6),
            Text('$count',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? color.shade800 : color.shade700)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? color.shade700 : color.shade600)),
          ]),
        ),
      ),
    );
  }

  Widget _editRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Specialist_edit_request')
          .where('status', isEqualTo: _selectedEditStatus)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF16A34A)));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  _selectedEditStatus == 'pending'
                      ? 'لا توجد طلبات معلقة'
                      : _selectedEditStatus == 'approved'
                      ? 'لا توجد طلبات موافق عليها'
                      : 'لا توجد طلبات مرفوضة',
                  style: const TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _editRequestCard(data, docs[i].id);
          },
        );
      },
    );
  }

  Widget _editRequestCard(Map<String, dynamic> data, String docId) {
    final status = data['status'] as String;
    final statusColor = status == 'pending'
        ? Colors.orange
        : status == 'approved'
        ? Colors.green
        : Colors.red;

    final oldImages = List<String>.from(data['oldCertificateImages'] ?? []);
    final newImages = List<String>.from(data['newCertificateImages'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFDCFCE7),
                child: Text(
                  (data['specialistName'] ?? 'خ')[0],
                  style: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(data['specialistName'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF14532D))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  status == 'pending' ? 'معلق' : status == 'approved' ? 'موافق عليه' : 'مرفوض',
                  style: TextStyle(fontSize: 11, color: statusColor),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _editComparisonRow('الاسم الكامل', data['oldFullName'], data['newFullName']),
                _editComparisonRow('الخبرة', data['oldExperience'], data['newExperience']),
                _editComparisonRow('الشهادات', data['oldCertificates'], data['newCertificates']),
                _editComparisonRow('البريد الإلكتروني', data['oldEmail'], data['newEmail']),
                if (oldImages.isNotEmpty || newImages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('صور الشهادات',
                      style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('قبل', style: TextStyle(fontSize: 11, color: Colors.red)),
                            const SizedBox(height: 4),
                            oldImages.isEmpty
                                ? const Text('—', style: TextStyle(color: Colors.grey))
                                : Wrap(
                              spacing: 4, runSpacing: 4,
                              children: oldImages.map((url) => ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(url, width: 60, height: 60, fit: BoxFit.cover),
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('بعد', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A))),
                            const SizedBox(height: 4),
                            newImages.isEmpty
                                ? const Text('لم يتم تغييرها', style: TextStyle(color: Colors.grey))
                                : Wrap(
                              spacing: 4, runSpacing: 4,
                              children: newImages.map((url) => ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(url, width: 60, height: 60, fit: BoxFit.cover),
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (status == 'rejected' && (data['rejectionReason'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('سبب الرفض:', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(data['rejectionReason'], style: const TextStyle(fontSize: 13, color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (status == 'pending')
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveEditRequest(data, docId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.check, color: Colors.white, size: 16),
                    label: const Text('قبول', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditRejectDialog(data, docId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFCC0000),
                      side: const BorderSide(color: Color(0xFFCC0000)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.close, color: Color(0xFFCC0000), size: 16),
                    label: const Text('رفض', style: TextStyle(color: Color(0xFFCC0000), fontSize: 13)),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _editComparisonRow(String label, String? oldVal, String? newVal) {
    final changed = (oldVal ?? '') != (newVal ?? '') && (newVal ?? '').isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                child: Text(oldVal ?? '—', style: TextStyle(fontSize: 12, color: changed ? Colors.red : Colors.grey)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: changed ? const Color(0xFFF0FDF4) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(newVal ?? '—',
                    style: TextStyle(
                        fontSize: 12,
                        color: changed ? const Color(0xFF16A34A) : Colors.grey,
                        fontWeight: changed ? FontWeight.bold : FontWeight.normal)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

// ── Approve edit request ──────────────────────────────────────────────
  Future<void> _approveEditRequest(Map<String, dynamic> data, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تأكيد القبول',
              style: TextStyle(color: Color(0xFF14532D), fontWeight: FontWeight.bold)),
          content: Text('هل تريد قبول تعديلات ${data['specialistName'] ?? ''}؟ سيتم تحديث بياناته تلقائياً.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              child: const Text('قبول', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    final specialistId = data['specialistId'] as String;
    final batch = FirebaseFirestore.instance.batch();

    batch.update(FirebaseFirestore.instance.collection('Specialist_edit_request').doc(docId), {'status': 'approved'});

    final updates = <String, dynamic>{};
    if ((data['newFullName'] ?? '').isNotEmpty && data['newFullName'] != data['oldFullName']) updates['fullName'] = data['newFullName'];
    if ((data['newExperience'] ?? '').isNotEmpty && data['newExperience'] != data['oldExperience']) updates['experience'] = data['newExperience'];
    if ((data['newCertificates'] ?? '').isNotEmpty && data['newCertificates'] != data['oldCertificates']) updates['certificates'] = data['newCertificates'];
    if ((data['newEmail'] ?? '').isNotEmpty && data['newEmail'] != data['oldEmail']) updates['email'] = data['newEmail'];
    final newImages = List<String>.from(data['newCertificateImages'] ?? []);
    if (newImages.isNotEmpty) updates['certificateImages'] = newImages;

    if (updates.isEmpty) {
      await FirebaseFirestore.instance.collection('Specialist_edit_request').doc(docId).update({'status': 'approved'});
      return;
    }

    batch.update(FirebaseFirestore.instance.collection('specialists').doc(specialistId), updates);

    final accountUpdates = <String, dynamic>{};
    if ((data['newEmail'] ?? '').isNotEmpty && data['newEmail'] != data['oldEmail']) accountUpdates['email'] = data['newEmail'];
    if ((data['newFullName'] ?? '').isNotEmpty && data['newFullName'] != data['oldFullName']) accountUpdates['username'] = data['newFullName'];
    if (accountUpdates.isNotEmpty) {
      batch.update(FirebaseFirestore.instance.collection('accounts').doc(specialistId), accountUpdates);
    }

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ تم قبول تعديلات ${data['specialistName'] ?? ''} وتحديث بياناته'),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 3),
      ));
    }
  }

// ── Reject edit request ──────────────────────────────────────────────
  void _showEditRejectDialog(Map<String, dynamic> data, String docId) {
    final reasonController = TextEditingController();
    String? reasonError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              const Icon(Icons.cancel_outlined, color: Color(0xFFCC0000), size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text('رفض تعديل ${data['specialistName'] ?? ''}',
                  style: const TextStyle(color: Color(0xFF14532D), fontWeight: FontWeight.bold, fontSize: 16))),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('سبب الرفض *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  maxLines: 4,
                  textDirection: TextDirection.rtl,
                  onChanged: (v) => setDialog(() { reasonError = v.trim().isEmpty ? 'سبب الرفض مطلوب' : null; }),
                  decoration: InputDecoration(
                    hintText: 'أدخل سبب الرفض...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    errorText: reasonError,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
              ElevatedButton.icon(
                onPressed: () async {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) { setDialog(() => reasonError = 'سبب الرفض مطلوب'); return; }
                  Navigator.pop(ctx);
                  await FirebaseFirestore.instance.collection('Specialist_edit_request').doc(docId).update({
                    'status': 'rejected',
                    'rejectionReason': reason,
                    'rejectedAt': FieldValue.serverTimestamp(),
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('❌ تم رفض تعديلات ${data['specialistName'] ?? ''}'),
                      backgroundColor: Colors.orange,
                    ));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCC0000)),
                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                label: const Text('رفض', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

// ── Profile Tab ──────────────────────────────────────────────
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF16A34A), width: 2),
                  ),
                  child: const Icon(Icons.shield, color: Color(0xFF16A34A), size: 38),
                ),
                const SizedBox(height: 10),
                Text(_name.isNotEmpty ? _name : 'مدير النظام',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF14532D))),
                const SizedBox(height: 4),
                const Text('مدير النظام', style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8E8E8))),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المعلومات الشخصية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                      GestureDetector(
                        onTap: _showEditDialog,
                        child: const Row(children: [
                          Icon(Icons.edit_outlined, color: Color(0xFF16A34A), size: 17),
                          SizedBox(width: 4),
                          Text('تعديل', style: TextStyle(fontSize: 13, color: Color(0xFF16A34A))),
                        ]),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                _buildInfoRow(label: 'الاسم', value: _name.isNotEmpty ? _name : 'مدير النظام', icon: Icons.person_outline, iconColor: const Color(0xFF16A34A)),
                const Divider(height: 1, color: Color(0xFFEEEEEE), indent: 16, endIndent: 16),
                _buildInfoRow(label: 'البريد الإلكتروني', value: _email.isNotEmpty ? _email : 'admin@bioshield.com', icon: Icons.email_outlined, iconColor: const Color(0xFF16A34A)),
                const Divider(height: 1, color: Color(0xFFEEEEEE), indent: 16, endIndent: 16),
                _buildInfoRow(label: 'الصلاحيات', value: 'صلاحيات: كاملة', icon: Icons.settings_outlined, iconColor: const Color(0xFF16A34A)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8E8E8))),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Align(alignment: Alignment.centerRight, child: Text('الأمان', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87))),
                ),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: Color(0xFF16A34A)),
                  title: const Text('تغيير كلمة المرور', style: TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
                  onTap: _showChangePasswordDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton.icon(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0000),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    bool sending = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('تغيير كلمة المرور', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF14532D))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('سيتم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني', style: TextStyle(fontSize: 13, color: Colors.grey), textAlign: TextAlign.right),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF86EFAC))),
                  child: Row(children: [
                    const Icon(Icons.email_outlined, color: Color(0xFF16A34A), size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_email, style: const TextStyle(fontSize: 14, color: Color(0xFF166534), fontWeight: FontWeight.w500), textDirection: TextDirection.ltr)),
                  ]),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: sending ? null : () async {
                  setDialogState(() => sending = true);
                  try {
                    await FirebaseAuth.instance.sendPasswordResetEmail(email: _email);
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم إرسال رابط إعادة التعيين إلى بريدك'), backgroundColor: Color(0xFF16A34A)));
                  } catch (e) {
                    setDialogState(() => sending = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('إرسال', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog() {
    final nameController = TextEditingController(text: _name);
    final emailController = TextEditingController(text: _email);
    bool saving = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('تعديل المعلومات الشخصية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF14532D))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'الاسم',
                    labelStyle: const TextStyle(color: Color(0xFF16A34A)),
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF16A34A)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    labelStyle: const TextStyle(color: Color(0xFF16A34A)),
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF16A34A)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: saving ? null : () async {
                  setDialogState(() => saving = true);
                  try {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    final newName = nameController.text.trim();
                    final newEmail = emailController.text.trim();
                    if (uid != null) {
                      await FirebaseFirestore.instance.collection('admins').doc(uid).update({'username': newName, 'email': newEmail});
                      await FirebaseFirestore.instance.collection('accounts').doc(uid).update({'username': newName, 'email': newEmail});
                      if (newEmail != _email) await FirebaseAuth.instance.currentUser?.verifyBeforeUpdateEmail(newEmail);
                    }
                    if (!mounted) return;
                    setState(() { _name = newName; _email = newEmail; });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات بنجاح ✓'), backgroundColor: Color(0xFF16A34A)));
                  } catch (e) {
                    setDialogState(() => saving = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('حفظ', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({required String label, required String value, required IconData icon, required Color iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 3),
              Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87)),
            ],
          )),
          Icon(icon, color: iconColor, size: 22),
        ],
      ),
    );
  }
}