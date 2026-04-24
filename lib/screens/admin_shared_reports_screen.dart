import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Standalone screen — plug into AdminHomeScreen's bottom nav
/// or call it directly: Navigator.push(..., AdminSharedReportsScreen())
class AdminSharedReportsScreen extends StatefulWidget {
  const AdminSharedReportsScreen({super.key});
  @override
  State<AdminSharedReportsScreen> createState() => _AdminSharedReportsScreenState();
}

class _AdminSharedReportsScreenState extends State<AdminSharedReportsScreen> {
  static const _green600 = Color(0xFF16A34A);
  static const _green900 = Color(0xFF14532D);

  String _search = '';
  String _filter = 'الكل'; // 'الكل' | 'سليم' | 'مريض'
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Delete a shared report from BOTH collections ──────────────
  Future<void> _deletePost(Map<String, dynamic> data, String sharedDocId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('حذف المنشور', style: TextStyle(color: _green900, fontWeight: FontWeight.bold)),
          content: Text('هل تريد حذف منشور "${data['plantName'] ?? ''}" بواسطة ${data['sharedBy'] ?? ''}؟\nلا يمكن التراجع عن هذا الإجراء.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;

    try {
      // 1. Delete from shared_reports
      await FirebaseFirestore.instance.collection('shared_reports').doc(sharedDocId).delete();

      // 2. Delete from community_feed using feedDocId
      final feedDocId = data['feedDocId'] as String?;
      if (feedDocId != null && feedDocId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('community_feed').doc(feedDocId).delete();
      }

      // 3. Update the original report so it no longer shows as shared
      final reportId = data['reportId'] as String?;
      if (reportId != null && reportId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
          'feedDocId': '',
          'isSharedToCommunity': false,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ تم حذف المنشور بنجاح', textDirection: TextDirection.rtl),
              backgroundColor: Color(0xFF2D322C)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e', textDirection: TextDirection.rtl), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shared_reports')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _green600));
          }

          final allDocs = snapshot.data?.docs ?? [];
          final allPosts = allDocs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return {'_docId': doc.id, ...d};
          }).toList();

          // Apply filters
          final filtered = allPosts.where((p) {
            final name = (p['plantName'] ?? '').toString().toLowerCase();
            final shared = (p['sharedBy'] ?? '').toString().toLowerCase();
            final matchSearch = _search.isEmpty ||
                name.contains(_search.toLowerCase()) ||
                shared.contains(_search.toLowerCase());
            final status = p['status'] as String? ?? '';
            final matchFilter = _filter == 'الكل' ||
                (_filter == 'سليم' && status == 'سليم') ||
                (_filter == 'مريض' && status == 'مريض');
            return matchSearch && matchFilter;
          }).toList();

          final healthyCount = allPosts.where((p) => p['status'] == 'سليم').length;
          final sickCount    = allPosts.where((p) => p['status'] == 'مريض').length;

          return Column(
            children: [
              // ── Stat row ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  _statBox('${allPosts.length}', 'الكل', const Color(0xFF0284C7), const Color(0xFFEFF6FF)),
                  const SizedBox(width: 8),
                  _statBox('$healthyCount', 'سليمة', const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
                  const SizedBox(width: 8),
                  _statBox('$sickCount', 'مريضة', const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Search ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  textDirection: TextDirection.rtl,
                  onChanged: (v) => setState(() => _search = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم النبات أو المستخدم...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    prefixIcon: _search.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                        : const Icon(Icons.search, color: _green600),
                    filled: true, fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _green600, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Filter chips ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  _chip('الكل', allPosts.length),
                  const SizedBox(width: 8),
                  _chip('مريض', sickCount),
                  const SizedBox(width: 8),
                  _chip('سليم', healthyCount),
                ]),
              ),
              const SizedBox(height: 12),

              // ── List ──────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('لا توجد منشورات مشتركة',
                      style: TextStyle(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.bold)),
                ]))
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final post = filtered[i];
                    final docId = post['_docId'] as String;
                    return _SharedPostCard(
                      post: post,
                      onDelete: () => _deletePost(post, docId),
                      onTap: () => _showPostDetail(post, docId),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statBox(String value, String label, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Column(children: [
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _chip(String label, int count) {
    final active = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _green600 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _green600 : const Color(0xFFE5E7EB)),
        ),
        child: Text('$label ($count)',
            style: TextStyle(
                color: active ? Colors.white : Colors.grey[700],
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                fontSize: 13)),
      ),
    );
  }

  void _showPostDetail(Map<String, dynamic> post, String docId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostDetailSheet(post: post, docId: docId, onDelete: () {
        Navigator.pop(context);
        _deletePost(post, docId);
      }),
    );
  }
}

// ─── Card widget ──────────────────────────────────────────────
class _SharedPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  const _SharedPostCard({required this.post, required this.onDelete, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isHealthy = post['status'] == 'سليم' || post['isHealthy'] == true;
    final sc = isHealthy ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final sb = isHealthy ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final imageUrl = post['ImageUrl'] ?? post['imageUrl'] ?? '';
    final plantNameConf = (post['plantNameConfidence'] as num?)?.toInt() ?? (post['confidence'] as num?)?.toInt() ?? 0;
    final diseaseConf   = (post['diseaseConfidence']   as num?)?.toInt() ?? (post['confidence'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isHealthy ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA), width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(sb))
                : _placeholder(sb),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(post['plantName'] ?? '—',
                style: const TextStyle(color: Color(0xFF14532D), fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text('بواسطة: ${post['sharedBy'] ?? '—'}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 4),
            // Two confidence badges
            Row(children: [
              _confBadge('🌿 $plantNameConf%', const Color(0xFF16A34A)),
              const SizedBox(width: 6),
              _confBadge('🧬 $diseaseConf%', isHealthy ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
            ]),
            const SizedBox(height: 4),
            Text(post['date'] ?? '', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
          ])),

          // Status + delete
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: sb, borderRadius: BorderRadius.circular(20)),
                child: Text(post['status'] ?? '—',
                    style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _placeholder(Color bg) => Container(width: 60, height: 60, color: bg,
      child: const Center(child: Icon(Icons.eco_outlined, color: Colors.grey)));

  Widget _confBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );
}

// ─── Detail bottom sheet ──────────────────────────────────────
class _PostDetailSheet extends StatelessWidget {
  final Map<String, dynamic> post;
  final String docId;
  final VoidCallback onDelete;
  const _PostDetailSheet({required this.post, required this.docId, required this.onDelete});

  bool _isDiseased(String label) {
    final l = label.toLowerCase();
    return l.isNotEmpty && !l.contains('healthy') && !l.contains('fresh') &&
        !l.contains('سليم') && !l.contains('طازج');
  }

  @override
  Widget build(BuildContext context) {
    final isHealthy = post['status'] == 'سليم' || post['isHealthy'] == true;
    final sc = isHealthy ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final sb = isHealthy ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final imageUrl = post['ImageUrl'] ?? post['imageUrl'] ?? '';

    final int plantNameConf   = (post['plantNameConfidence'] as num?)?.toInt() ?? (post['confidence'] as num?)?.toInt() ?? 0;
    final int diseaseConf     = (post['diseaseConfidence']   as num?)?.toInt() ?? (post['confidence'] as num?)?.toInt() ?? 0;
    final String plantLabel   = (post['plantNetLabel']     ?? '').toString();
    final String diseaseLabel = (post['modelDiseaseLabel'] ?? '').toString();

    final Color diseaseBarColor = _isDiseased(diseaseLabel)
        ? const Color(0xFFDC2626)
        : const Color(0xFF16A34A);
    final String diseaseSublabel = diseaseLabel.isNotEmpty
        ? (_isDiseased(diseaseLabel) ? 'تم رصد علامات مرضية: $diseaseLabel' : 'النبات سليم')
        : '—';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Handle
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),

            if (imageUrl.isNotEmpty)
              ClipRRect(borderRadius: BorderRadius.circular(16),
                  child: Image.network(imageUrl, height: 200, fit: BoxFit.cover)),
            const SizedBox(height: 16),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(post['plantName'] ?? '—',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF14532D))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: sb, borderRadius: BorderRadius.circular(20)),
                  child: Text(post['status'] ?? '—', style: TextStyle(color: sc, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 8),
            Text('بواسطة: ${post['sharedBy'] ?? '—'}  |  ${post['date'] ?? '—'}',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 16),

            // ── Plant name confidence bar + label ─────────────────
            _detailConfBar(
              label: '🌿 دقة تحديد الاسم العلمي للنبات',
              value: plantNameConf,
              color: const Color(0xFF16A34A),
              sublabel: plantLabel.isNotEmpty ? plantLabel : '—',
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.grey.withOpacity(0.15)),
            const SizedBox(height: 14),
            // ── Disease confidence bar + label ────────────────────
            _detailConfBar(
              label: '🧬 دقة تشخيص المرض',
              value: diseaseConf,
              color: diseaseBarColor,
              sublabel: diseaseSublabel,
            ),
            const SizedBox(height: 16),

            // Sections
            _section('التشخيص', post['diagnosis'] ?? '—', Icons.biotech, sc),
            const SizedBox(height: 10),
            _section('العلاج الموصى به', post['treatment'] ?? '—', Icons.healing, const Color(0xFFD97706)),
            const SizedBox(height: 20),

            // Delete button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_forever, color: Colors.white),
                label: const Text('حذف المنشور', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _detailConfBar({
    required String label,
    required int value,
    required Color color,
    required String sublabel,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)))),
        Text('$value%', style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(children: [
          Container(height: 10, width: double.infinity,
              decoration: BoxDecoration(color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8))),
          FractionallySizedBox(
            widthFactor: (value / 100).clamp(0.0, 1.0),
            child: Container(height: 10,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8))),
          ),
        ]),
      ),
      const SizedBox(height: 5),
      Text(sublabel,
          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: color.withOpacity(0.8))),
    ]);
  }

  Widget _section(String title, String content, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        Text(content, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.6)),
      ]),
    );
  }
}