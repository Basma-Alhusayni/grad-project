import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'splash_screen.dart';
import 'specialist_list_screen.dart';
import 'diagnosis_screen.dart';
import 'user_reports_screen.dart';
import 'user_profile_screen.dart';

// ─── MAIN HOME SCREEN ───────────────────────────────────────
class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const _ReportsDashboard(),
      const SpecialistListScreen(),
      const DiagnosisScreen(),
      const UserReportsScreen(),
      const UserProfileScreen(),
    ];
    _setOnlineStatus();
  }

  Future<void> _setOnlineStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'isOnline': true,
        });
      } catch (e) {
        debugPrint('Error updating online status: $e');
      }
    }
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
              onPressed: () async {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .update({'isOnline': false});
                  } catch (e) {
                    debugPrint('Error updating online status: $e');
                  }
                }
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
        body: IndexedStack(index: _currentIndex, children: _pages),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return SafeArea(
      bottom: true,
      child: Container(
        height: 90,
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 75,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _navItem(0, Icons.home_outlined, Icons.home, 'الرئيسية'),
                  _navItem(
                    1,
                    Icons.chat_bubble_outline,
                    Icons.chat_bubble,
                    'الخبراء',
                  ),
                  _navItem(
                    2,
                    Icons.camera_alt,
                    Icons.camera_alt,
                    'التشخيص',
                    isCircle: true,
                  ),
                  _navItem(
                    3,
                    Icons.description_outlined,
                    Icons.description,
                    'تقاريري',
                  ),
                  _navItem(4, Icons.person_outline, Icons.person, 'ملفي'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label, {
    bool isCircle = false,
  }) {
    final isSelected = _currentIndex == index;
    final Color activeColor = const Color(0xFF16A34A);
    final Color inactiveColor = Colors.grey[400]!;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 5.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCircle)
              Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF14532D) : activeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 24,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 28,
                ),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── COMMUNITY FEED DASHBOARD ───────────────────────────────
class _ReportsDashboard extends StatefulWidget {
  const _ReportsDashboard();

  @override
  State<_ReportsDashboard> createState() => _ReportsDashboardState();
}

class _ReportsDashboardState extends State<_ReportsDashboard> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _notifier = ValueNotifier<String>('');

  @override
  void dispose() {
    _searchController.dispose();
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, snapshot) {
            String displayName = '...';
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              displayName = data['fullName'] ?? 'مستخدم';
            }
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14532D), Color(0xFF16A34A)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مرحباً، $displayName 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.eco_rounded, color: Colors.white, size: 36),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          onChanged: (v) => _notifier.value = v,
          decoration: InputDecoration(
            hintText: 'ابحث عن اسم النبات...',
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: ValueListenableBuilder<String>(
              valueListenable: _notifier,
              builder: (context, query, _) {
                return query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _notifier.value = '';
                        },
                      )
                    : const SizedBox.shrink();
              },
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'التقارير المشاركة',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF166534),
          ),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<String>(
          valueListenable: _notifier,
          builder: (context, query, child) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('community_feed')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  );
                }
                final allDocs = snapshot.data?.docs ?? [];
                final filtered = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final plantName = (data['plantName'] ?? '')
                      .toString()
                      .toLowerCase();
                  return plantName.contains(query.toLowerCase().trim());
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('لا توجد نتائج مطابقة'),
                    ),
                  );
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _ReportCard(
                    report: filtered[i].data() as Map<String, dynamic>,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;

  const _ReportCard({required this.report});

  bool _isDiseased(String label) {
    final l = label.toLowerCase();
    return l.isNotEmpty &&
        !l.contains('healthy') &&
        !l.contains('fresh') &&
        !l.contains('سليم') &&
        !l.contains('طازج');
  }

  @override
  Widget build(BuildContext context) {
    final isHealthy = report['status'] == 'سليم' || report['isHealthy'] == true;
    final imageUrl = report['ImageUrl'] ?? report['imageUrl'] ?? '';
    final isSpecialistReport = report['reportType'] == 'specialist';

    // Only get confidence data for AI reports
    final int plantConf = isSpecialistReport
        ? 0
        : ((report['plantNameConfidence'] ?? report['confidence'] ?? 0) as num)
              .toInt();
    final int diseaseConf = isSpecialistReport
        ? 0
        : ((report['diseaseConfidence'] ?? report['confidence'] ?? 0) as num)
              .toInt();
    final String plantLbl = isSpecialistReport
        ? ''
        : (report['plantNetLabel'] ?? '').toString();
    final String diseaseLbl = isSpecialistReport
        ? ''
        : (report['modelDiseaseLabel'] ?? '').toString();
    final Color diseaseColor = _isDiseased(diseaseLbl)
        ? Colors.red
        : const Color(0xFF16A34A);

    // Specialist report colors
    final specialistColor = const Color(0xFF8B5CF6);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) => SharedReportDetailPage(report: report),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: isSpecialistReport
              ? Border.all(color: specialistColor.withOpacity(0.3), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image with status badge ──────────────────────────
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imgPlaceholder(),
                          )
                        : _imgPlaceholder(),
                  ),
                  // Specialist badge (only for specialist reports)
                  if (isSpecialistReport)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: specialistColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, color: Colors.white, size: 10),
                            SizedBox(width: 4),
                            Text(
                              'تقرير خبير',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Status badge
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isHealthy ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isHealthy ? 'سليم' : 'مريض',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Info section ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plant name with verified icon for specialist
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report['plantName'] ?? 'نبات',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSpecialistReport)
                        Icon(Icons.verified, color: specialistColor, size: 14),
                    ],
                  ),

                  // Shared by (different text for specialist)
                  if (isSpecialistReport)
                    Text(
                      'بواسطة الخبير: ${report['specialistName'] ?? 'خبير'}',
                      style: TextStyle(fontSize: 10, color: specialistColor),
                      maxLines: 1,
                    )
                  else
                    Text(
                      'بواسطة: ${report['sharedBy'] ?? 'مستخدم'}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      maxLines: 1,
                    ),

                  const SizedBox(height: 6),

                  // Show different content based on report type
                  if (isSpecialistReport) ...[
                    Text(
                      report['diagnosis'] ?? '',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.verified, color: specialistColor, size: 10),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            'معتمد من خبير متخصص',
                            style: TextStyle(
                              fontSize: 9,
                              color: specialistColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // AI Report shows confidence bars (only if data exists)
                    if (plantConf > 0)
                      _MiniConfidenceBar(
                        icon: '🌿',
                        percent: plantConf,
                        sublabel: plantLbl.isNotEmpty ? plantLbl : '—',
                        color: const Color(0xFF16A34A),
                      ),
                    if (plantConf > 0) const SizedBox(height: 5),
                    if (diseaseConf > 0)
                      _MiniConfidenceBar(
                        icon: '🧬',
                        percent: diseaseConf,
                        sublabel: diseaseLbl.isNotEmpty
                            ? (_isDiseased(diseaseLbl)
                                  ? 'مرضية: $diseaseLbl'
                                  : 'النبات سليم')
                            : '—',
                        color: diseaseColor,
                      ),
                    // If no confidence data, show diagnosis
                    if (plantConf == 0 && diseaseConf == 0)
                      Text(
                        report['diagnosis'] ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],

                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.arrow_circle_left_outlined,
                      size: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    color: Colors.grey[100],
    child: const Center(child: Icon(Icons.eco_outlined, color: Colors.grey)),
  );
}

// ─── Compact confidence bar for the grid card ─────────────────
class _MiniConfidenceBar extends StatelessWidget {
  final String icon;
  final String sublabel;
  final int percent;
  final Color color;

  const _MiniConfidenceBar({
    required this.icon,
    required this.percent,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (percent / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon + percent on one row
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    Container(height: 6, color: color.withOpacity(0.12)),
                    FractionallySizedBox(
                      widthFactor: fraction,
                      child: Container(height: 6, color: color),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$percent%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        // Sublabel
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Text(
            sublabel,
            style: TextStyle(
              fontSize: 9,
              fontStyle: FontStyle.italic,
              color: color.withOpacity(0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SHARED REPORT DETAIL PAGE  — with conditional confidence bars
// ═══════════════════════════════════════════════════════════════
class SharedReportDetailPage extends StatelessWidget {
  final Map<String, dynamic> report;

  const SharedReportDetailPage({super.key, required this.report});

  // ── Determine if diseased based on modelDiseaseLabel ──────────
  bool _isDiseaseLabel(String label) {
    if (label.isEmpty) return false;
    final l = label.toLowerCase();
    return !l.contains('healthy') &&
        !l.contains('fresh') &&
        !l.contains('سليم') &&
        !l.contains('طازج');
  }

  @override
  Widget build(BuildContext context) {
    final isHealthy = report['status'] == 'سليم' || report['isHealthy'] == true;
    final imageUrl = report['ImageUrl'] ?? report['imageUrl'] ?? '';
    final Color pc = isHealthy ? const Color(0xFF16A34A) : Colors.red;
    final isSpecialistReport = report['reportType'] == 'specialist';

    // Specialist report colors
    final specialistColor = const Color(0xFF8B5CF6);

    // ── Confidence data (only for AI reports) ───────────────────
    final int plantNameConf = isSpecialistReport
        ? 0
        : ((report['plantNameConfidence'] as num?)?.toInt() ??
              (report['confidence'] as num?)?.toInt() ??
              0);
    final int diseaseConf = isSpecialistReport
        ? 0
        : ((report['diseaseConfidence'] as num?)?.toInt() ??
              (report['confidence'] as num?)?.toInt() ??
              0);
    final String plantLabel = isSpecialistReport
        ? ''
        : (report['plantNetLabel'] ?? '').toString();
    final String diseaseLabel = isSpecialistReport
        ? ''
        : (report['modelDiseaseLabel'] ?? '').toString();

    final Color diseaseBarColor = _isDiseaseLabel(diseaseLabel)
        ? Colors.red
        : const Color(0xFF16A34A);
    final String diseaseSublabel = diseaseLabel.isNotEmpty
        ? (_isDiseaseLabel(diseaseLabel)
              ? 'تم رصد علامات مرضية: $diseaseLabel'
              : 'النبات سليم')
        : '—';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAF8),
        appBar: AppBar(
          backgroundColor: isSpecialistReport ? specialistColor : Colors.white,
          elevation: 1,
          centerTitle: true,
          title: Text(
            isSpecialistReport ? 'تقرير الخبير' : 'تفاصيل التقرير المشترك',
            style: TextStyle(
              color: isSpecialistReport
                  ? Colors.white
                  : const Color(0xFF14532D),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: isSpecialistReport
                  ? Colors.white
                  : const Color(0xFF16A34A),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Plant image ────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        height: 280,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(height: 20),

              // ── Main info card ─────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: isSpecialistReport
                      ? Border.all(
                          color: specialistColor.withOpacity(0.3),
                          width: 1.5,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          report['plantName'] ?? 'نبات',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isSpecialistReport
                                ? specialistColor
                                : const Color(0xFF14532D),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSpecialistReport
                                ? specialistColor.withOpacity(0.1)
                                : pc.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isHealthy ? 'سليم' : 'مريض',
                            style: TextStyle(
                              color: isSpecialistReport ? specialistColor : pc,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),

                    // For specialist reports: Show BOTH sharer (user) AND specialist
                    if (isSpecialistReport) ...[
                      _detailRow(
                        Icons.person_outline,
                        'تمت المشاركة بواسطة',
                        report['sharedBy'] ?? 'مستخدم',
                        iconColor: specialistColor,
                      ),
                      const SizedBox(height: 4),
                      _detailRow(
                        Icons.verified,
                        'الخبير المعتمد',
                        report['specialistName'] ?? 'خبير',
                        iconColor: specialistColor,
                      ),
                    ] else ...[
                      _detailRow(
                        Icons.person_pin_rounded,
                        'تم النشر بواسطة',
                        report['sharedBy'] ?? 'مستخدم',
                      ),
                    ],

                    _detailRow(
                      Icons.calendar_month_rounded,
                      'تاريخ التقرير',
                      report['date'] ?? '—',
                      iconColor: isSpecialistReport ? specialistColor : null,
                    ),

                    const SizedBox(height: 16),

                    // ── ONLY SHOW CONFIDENCE BARS FOR AI REPORTS ──
                    if (!isSpecialistReport && plantNameConf > 0) ...[
                      _ConfidenceBar(
                        label: '🌿 دقة تحديد اسم النبات',
                        value: plantNameConf,
                        barColor: const Color(0xFF16A34A),
                        sublabel: plantLabel.isNotEmpty ? plantLabel : '—',
                      ),
                      const SizedBox(height: 14),
                      Divider(color: Colors.grey.withOpacity(0.2)),
                      const SizedBox(height: 14),
                      _ConfidenceBar(
                        label: '🧬 دقة تشخيص المرض',
                        value: diseaseConf,
                        barColor: diseaseBarColor,
                        sublabel: diseaseSublabel,
                      ),
                    ],

                    // For specialist reports, show a verification badge instead
                    if (isSpecialistReport) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: specialistColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified,
                              color: specialistColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'هذا التقرير معتمد من خبير متخصص',
                                style: TextStyle(
                                  color: specialistColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Diagnosis section ──────────────────────────────
              _infoSection(
                'التشخيص',
                report['diagnosis'] ?? 'لا يوجد بيانات',
                Icons.biotech_rounded,
                isSpecialistReport ? specialistColor : null,
              ),
              const SizedBox(height: 12),
              _infoSection(
                'العلاج الموصى به',
                report['treatment'] ?? 'لا يوجد علاج متاح حالياً',
                Icons.healing_rounded,
                isSpecialistReport ? specialistColor : null,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    Color? iconColor,
  }) {
    final color = iconColor ?? const Color(0xFF16A34A);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text('$label: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoSection(
    String title,
    String content,
    IconData icon, [
    Color? customColor,
  ]) {
    final color = customColor ?? const Color(0xFF16A34A);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              color: Colors.black87,
              height: 1.6,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 200,
    color: Colors.grey[200],
    child: const Icon(
      Icons.image_not_supported_outlined,
      size: 50,
      color: Colors.grey,
    ),
  );
}

// ─── Confidence bar widget (mirrors diagnosis_result_screen) ──
class _ConfidenceBar extends StatelessWidget {
  final String label;
  final String sublabel;
  final int value; // 0–100
  final Color barColor;

  const _ConfidenceBar({
    required this.label,
    required this.value,
    required this.barColor,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (value / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ),
            Text(
              value > 0 ? '$value%' : '—',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        // Sublabel
        Text(
          sublabel,
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: barColor.withOpacity(0.85),
          ),
        ),
      ],
    );
  }
}
