import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';
import 'specialist_list_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});
  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentIndex = 0; // 0=الرئيسية, 1=الخبراء, 2=كاميرا, 3=ملفي

  final List<Widget> _pages = const [
    _ReportsDashboard(),
    SpecialistListScreen(),
    _CameraPlaceholder(),
    _ProfilePlaceholder(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
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
            child: Image.asset('assets/images/logo.png',
                errorBuilder: (_, __, ___) => const Icon(Icons.eco,
                    color: Color(0xFF16A34A))),
          ),
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
        body: _pages[_currentIndex],
        bottomNavigationBar: _buildBottomNav(),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF16A34A),
          shape: const CircleBorder(),
          onPressed: () => setState(() => _currentIndex = 2),
          child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, Icons.home_outlined, 'الرئيسية'),
          _navItem(1, Icons.chat_bubble_outline, 'الخبراء'),
          const SizedBox(width: 48), // مكان الـ FAB
          _navItem(3, Icons.person_outline, 'ملفي'),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isSelected
                  ? const Color(0xFF16A34A)
                  : Colors.grey[400],
              size: 24),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? const Color(0xFF16A34A)
                      : Colors.grey[400])),
        ],
      ),
    );
  }
}

// ─── صفحة التقارير (الرئيسية) ────────────────────────────────
class _ReportsDashboard extends StatefulWidget {
  const _ReportsDashboard();

  @override
  State<_ReportsDashboard> createState() => _ReportsDashboardState();
}

class _ReportsDashboardState extends State<_ReportsDashboard> {
  final _db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, dynamic>? _selectedReport;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('reports')
          .where('isShared', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        final allReports = snapshot.data?.docs
            .map((d) =>
        {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList() ??
            [];

        // فلترة البحث
        final filtered = allReports.where((r) {
          final q = _searchQuery.toLowerCase();
          return (r['plantName'] ?? '').toLowerCase().contains(q) ||
              (r['diagnosis'] ?? '').toLowerCase().contains(q) ||
              (r['disease'] ?? '').toLowerCase().contains(q);
        }).toList();

        // إحصائيات
        final total = allReports.length;
        final healthy =
            allReports.where((r) => r['status'] == 'healthy').length;
        final diseased =
            allReports.where((r) => r['status'] == 'diseased').length;
        final avgConf = total == 0
            ? 0
            : (allReports.fold<num>(
            0, (s, r) => s + (r['confidence'] ?? 0)) /
            total)
            .round();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── العنوان ──────────────────────────────────
            const Text('لوحة التقارير',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF166534))),
            const SizedBox(height: 4),
            const Text('استكشف تقارير تشخيص النباتات المشاركة من المجتمع',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),

            // ── الإحصائيات ───────────────────────────────
            Row(
              children: [
                _StatCard(total.toString(), 'تقرير', Icons.bar_chart,
                    Colors.blue),
                const SizedBox(width: 8),
                _StatCard(healthy.toString(), 'صحي', Icons.trending_up,
                    Colors.green),
                const SizedBox(width: 8),
                _StatCard(diseased.toString(), 'مريض', Icons.warning_amber,
                    Colors.red),
                const SizedBox(width: 8),
                _StatCard('$avgConf%', 'دقة', Icons.emoji_events,
                    Colors.purple),
              ],
            ),
            const SizedBox(height: 16),

            // ── البحث ────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _searchController,
                textDirection: TextDirection.rtl,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: const InputDecoration(
                  hintText: 'ابحث عن نبات أو مرض...',
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: Colors.grey),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('${filtered.length} نتيجة',
                  style:
                  const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            const SizedBox(height: 16),

            // ── التقارير ─────────────────────────────────
            const Text('التقارير المشاركة',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF166534))),
            const SizedBox(height: 10),

            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'لم يتم العثور على نتائج'
                        : 'لا توجد تقارير مشاركة بعد',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.8,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final report = filtered[index];
                  return _ReportCard(
                    report: report,
                    onTap: () =>
                        setState(() => _selectedReport = report),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // ── ديالوج تفاصيل التقرير ────────────────────────────────
  @override
  Widget build2(BuildContext context) => const SizedBox();
}

// في الـ build الرئيسي نستخدم Stack لعرض الديالوج
// لكن هنا نستخدم showDialog عادي من داخل _ReportCard

// ─── بطاقة إحصائية ───────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final MaterialColor color;

  const _StatCard(this.value, this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.shade50,
          border: Border.all(color: color.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color.shade600, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color.shade700)),
            Text(label,
                style:
                TextStyle(fontSize: 11, color: color.shade600)),
          ],
        ),
      ),
    );
  }
}

// ─── بطاقة تقرير ─────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onTap;

  const _ReportCard({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isHealthy = report['status'] == 'healthy';
    final imageUrl = report['plantImage'] ?? '';

    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                    child: imageUrl.isNotEmpty
                        ? Image.network(imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _imgPlaceholder())
                        : _imgPlaceholder(),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isHealthy ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isHealthy ? 'صحي' : 'مريض',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // معلومات
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(report['plantName'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(report['diagnosis'] ?? '',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${report['confidence'] ?? 0}%',
                            style: const TextStyle(fontSize: 10)),
                      ),
                      Row(
                        children: [
                          Icon(Icons.visibility,
                              size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 2),
                          Text('عرض',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final isHealthy = report['status'] == 'healthy';
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تفاصيل التقرير'),
          contentPadding: const EdgeInsets.all(16),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // صورة
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: (report['plantImage'] ?? '').isNotEmpty
                      ? Image.network(report['plantImage'],
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgPlaceholder())
                      : _imgPlaceholder(),
                ),
                const SizedBox(height: 12),

                // اسم النبات
                _detailCard('🌱 اسم النبات', report['plantName'] ?? '',
                    Colors.purple),

                // التشخيص
                _detailCard(
                  '🔍 التشخيص',
                  report['diagnosis'] ?? '',
                  isHealthy ? Colors.green : Colors.red,
                  extra: report['disease'] ?? '',
                ),

                // العلاج
                _detailCard(
                    '💊 العلاج الموصى به', report['treatment'] ?? '',
                    Colors.blue),

                // معلومات إضافية
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('تم التشخيص بواسطة',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                          Text(report['capturedBy'] ?? '',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'دقة: ${report['confidence'] ?? 0}%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text('تاريخ التقرير:',
                          style:
                          TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(width: 8),
                      Text(report['date'] ?? '',
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailCard(String title, String content, MaterialColor color,
      {String extra = ''}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.shade50,
        border: Border.all(color: color.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color.shade800)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 13)),
          if (extra.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(extra, style: const TextStyle(fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    height: 120,
    color: Colors.grey[200],
    child: const Center(
        child: Icon(Icons.image, size: 40, color: Colors.grey)),
  );
}

// ─── Placeholders ─────────────────────────────────────────────
class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();
  @override
  Widget build(BuildContext context) => const Center(
      child: Text('صفحة الكاميرا',
          style: TextStyle(fontSize: 18, color: Colors.grey)));
}

class _ProfilePlaceholder extends StatelessWidget {
  const _ProfilePlaceholder();
  @override
  Widget build(BuildContext context) => const Center(
      child: Text('صفحة الملف الشخصي',
          style: TextStyle(fontSize: 18, color: Colors.grey)));
}