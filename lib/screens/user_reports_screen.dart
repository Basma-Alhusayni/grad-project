import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import '../services/image_upload_service.dart';

class UserReportsScreen extends StatefulWidget {
  const UserReportsScreen({super.key});
  @override
  State<UserReportsScreen> createState() => _UserReportsScreenState();
}

class _UserReportsScreenState extends State<UserReportsScreen> {
  static const _green600 = Color(0xFF16A34A);
  String _filter = 'الكل';
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _filterChip(String label, String count) {
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
        child: Text(
          '$label ($count)',
          style: TextStyle(
              color: active ? Colors.white : Colors.grey[700],
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              fontSize: 13),
        ),
      ),
    );
  }

  // ── UPDATED: query top-level reports collection by userId ──
  Stream<QuerySnapshot> _reportsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('reports')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  String _iconForPlant(String type) {
    switch (type) {
      case 'vegetables': return '🥬';
      case 'mint':       return '🌿';
      case 'sidr':       return '🍃';
      case 'palm':       return '🌴';
      default:           return '🌱';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _reportsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _green600));
        }
        final allDocs = snapshot.data?.docs ?? [];
        final allReports = allDocs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id':         doc.id,
            'plantName':  data['plantName'] ?? '',
            'disease':    data['diagnosis'] ?? '',
            'status':     data['status'] ?? '',
            'date':       data['date'] ?? '',
            'confidence': data['confidence'] ?? 0,
            'treatment':  data['treatment'] ?? '',
            'plantType':  data['plantType'] ?? '',
            'icon':       _iconForPlant(data['plantType'] ?? ''),
            'feedDocId':  data['feedDocId'] ?? '',
            'imageUrl':  data['imageUrl'] ?? '',//Jumana
          };
        }).toList();

        final filtered = allReports.where((r) {
          final matchFilter = _filter == 'الكل' || r['status'] == _filter;
          final matchSearch = _search.isEmpty ||
              (r['plantName'] as String).contains(_search) ||
              (r['disease'] as String).contains(_search) ||
              (r['status'] as String).contains(_search) ||
              (r['date'] as String).contains(_search);
          return matchFilter && matchSearch;
        }).toList();

        final sharedCount = allReports
            .where((r) => (r['feedDocId'] as String).isNotEmpty)
            .length;

        return Column(children: [


          // ── 4 Stat Cards ────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              _StatCard(value: '${allReports.length}', label: 'الكل',
                  color: const Color(0xFF0284C7), bgColor: const Color(0xFFEFF6FF)),
              const SizedBox(width: 8),
              _StatCard(value: '${allReports.where((r) => r['status'] == 'مريض').length}',
                  label: 'مريضة', color: const Color(0xFFDC2626), bgColor: const Color(0xFFFEF2F2)),
              const SizedBox(width: 8),
              _StatCard(value: '${allReports.where((r) => r['status'] == 'سليم').length}',
                  label: 'صحية', color: const Color(0xFF16A34A), bgColor: const Color(0xFFDCFCE7)),
              const SizedBox(width: 8),
              _StatCard(value: '$sharedCount', label: 'مشاركة',
                  color: const Color(0xFF7C3AED), bgColor: const Color(0xFFF3F0FF)),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Search bar ───────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              onChanged: (v) => setState(() => _search = v.trim()),
              decoration: InputDecoration(
                hintText: 'ابحث باسم النبات أو التشخيص...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                hintTextDirection: TextDirection.rtl,
                prefixIcon: _search.isNotEmpty
                    ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _search = '');
                    })
                    : const Icon(Icons.search, color: Color(0xFF16A34A)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Filter chips ─────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _filterChip('الكل', '${allReports.length}'),
              const SizedBox(width: 8),
              _filterChip('مريض', '${allReports.where((r) => r['status'] == 'مريض').length}'),
              const SizedBox(width: 8),
              _filterChip('سليم', '${allReports.where((r) => r['status'] == 'سليم').length}'),
              if (_search.isNotEmpty) ...[
                const Spacer(),
                Text('${filtered.length} / ${allReports.length}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ]),
          ),
          const SizedBox(height: 12),

          // ── Reports list ────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('لا توجد تقارير بعد',
                      style: TextStyle(color: Colors.grey[500],
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('قم بتشخيص نبات لتظهر تقاريرك هنا',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ]))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (_, i) => _ReportCard(report: filtered[i]),
            ),
          ),
        ]);
      },
    );
  }
}

// ═══════════════════════════════════════════════
//  REPORT CARD
// ═══════════════════════════════════════════════
class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final isHealthy = report['status'] == 'سليم';
    final sc = isHealthy ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final sb = isHealthy ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final isShared = (report['feedDocId'] as String).isNotEmpty;
    final imageUrl = report['imageUrl'] ?? '';//Jumana
        report['image'] ??
        report['plantImage'] ??
            report['ImageUrl']??
        '';

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ReportDetailPage(report: report))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isHealthy ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
              width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          //Jumana
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? Image.network(
              imageUrl,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
            )
                : Container(
              width: 52,
              height: 52,
              color: sb,
              child: Center(
                child: Text(report['icon'],
                    style: const TextStyle(fontSize: 26)),
              ),
            ),
          ),//Jumana

          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(report['plantName'],
                style: const TextStyle(color: Color(0xFF14532D),
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 3),
            Text(report['disease'], maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 4),
            Row(children: [
              Text(report['date'], style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              if (isShared) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF3F0FF),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Row(children: [
                    Icon(Icons.share_rounded, color: Color(0xFF7C3AED), size: 10),
                    SizedBox(width: 3),
                    Text('مشارك', style: TextStyle(
                        color: Color(0xFF7C3AED), fontSize: 10,
                        fontWeight: FontWeight.bold)),
                  ]),
                ),
              ],
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: sb, borderRadius: BorderRadius.circular(20)),
              child: Text(report['status'],
                  style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Icon(Icons.arrow_back_ios, size: 13, color: Colors.grey[400]),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  REPORT DETAIL PAGE
// ═══════════════════════════════════════════════
class ReportDetailPage extends StatefulWidget {
  final Map<String, dynamic> report;
  const ReportDetailPage({super.key, required this.report});
  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  static const _green600 = Color(0xFF16A34A);
  static const _green900 = Color(0xFF14532D);
  static const _green50  = Color(0xFFF0FDF4);

  String? _feedDocId;
  bool _isShared = false;
  bool _sharingLoading = false;

  bool get _isHealthy => widget.report['status'] == 'سليم';
  Color get _sc => _isHealthy ? _green600 : const Color(0xFFDC2626);
  Color get _sb => _isHealthy ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);

  @override
  void initState() {
    super.initState();
    final existing = widget.report['feedDocId'] ?? '';
    if (existing.isNotEmpty) {
      _feedDocId = existing;
      _isShared = true;
    }
  }

  // ── UPDATED: uses top-level reports collection ──
  Future<void> _shareToggle() async {
    if (_sharingLoading) return;
    setState(() => _sharingLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (_isShared && _feedDocId != null) {
        // Cancel share
        await FirebaseFirestore.instance
            .collection('community_feed').doc(_feedDocId).delete();
        await FirebaseFirestore.instance
            .collection('reports').doc(widget.report['id'])
            .update({
          'feedDocId':           FieldValue.delete(),
          'isSharedToCommunity': false,
        });
        setState(() { _isShared = false; _feedDocId = null; });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ تم إلغاء المشاركة', textDirection: TextDirection.rtl),
        ));
      } else {
        // Check if already shared to prevent duplicates
        final existingDoc = await FirebaseFirestore.instance
            .collection('reports').doc(widget.report['id']).get();
        final existingFeedId = existingDoc.data()?['feedDocId'] ?? '';
        if (existingFeedId.isNotEmpty) {
          setState(() { _isShared = true; _feedDocId = existingFeedId; });
          if (mounted) setState(() => _sharingLoading = false);
          return;
        }

        // Share
        final doc = await FirebaseFirestore.instance
            .collection('accounts').doc(user.uid).get();
        final userName = doc.data()?['fullName'] ??
            doc.data()?['username'] ?? 'مستخدم';

        final ref = await FirebaseFirestore.instance
            .collection('community_feed').add({
          'plantName':  widget.report['plantName'],
          'ImageUrl':  widget.report['imageUrl'],//Jumana
          'diagnosis':  widget.report['disease'],
          'treatment':  widget.report['treatment'],
          'isHealthy':  _isHealthy,
          'confidence': widget.report['confidence'],
          'status':     widget.report['status'],
          'plantType':  widget.report['plantType'],
          'date':       widget.report['date'],
          'createdAt':  FieldValue.serverTimestamp(),
          'sharedBy':   userName,
          'userId':     user.uid,
          'reportId':   widget.report['id'],
        });

        await FirebaseFirestore.instance
            .collection('reports').doc(widget.report['id'])
            .update({
          'feedDocId':           ref.id,
          'isSharedToCommunity': true,
        });

        await Share.share(
          '🌿 BioShield - تقرير تشخيص نبات\n'
              '━━━━━━━━━━━━━━━━━━\n'
              'النبات: ${widget.report['plantName']}\n'
              'الحالة: ${widget.report['status']}\n'
              'التشخيص: ${widget.report['disease']}\n'
              'الدقة: ${widget.report['confidence']}%\n'
              'العلاج: ${widget.report['treatment']}\n'
              '━━━━━━━━━━━━━━━━━━\n'
              'التاريخ: ${widget.report['date']}\n'
              'تمت المشاركة عبر تطبيق BioShield 🌱',
        );

        setState(() { _isShared = true; _feedDocId = ref.id; });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ تمت المشاركة مع المجتمع!',
              textDirection: TextDirection.rtl),
          backgroundColor: Color(0xFF16A34A),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ خطأ: $e', textDirection: TextDirection.rtl),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _sharingLoading = false);
    }
  }

  Future<void> _exportPDF() async {
    try {
      final pdf = pw.Document();
      pdf.addPage(pw.Page(
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('BioShield - Plant Diagnosis Report',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 12),
            pw.Text('Plant: ${widget.report['plantName']}'),
            pw.SizedBox(height: 8),
            pw.Text('Status: ${widget.report['status']}'),
            pw.SizedBox(height: 8),
            pw.Text('Confidence: ${widget.report['confidence']}%'),
            pw.SizedBox(height: 8),
            pw.Text('Diagnosis: ${widget.report['disease']}'),
            pw.SizedBox(height: 8),
            pw.Text('Treatment: ${widget.report['treatment']}'),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.Text('Date: ${widget.report['date']}'),
            pw.Text('Generated by BioShield AI System'),
          ],
        ),
      ));
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/bioshield_report.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)],
          text: 'تقرير تشخيص النبات - BioShield');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('❌ خطأ في تصدير PDF',
              textDirection: TextDirection.rtl)));
    }
  }

  // ── UPDATED: deletes from top-level reports collection ──
  Future<void> _deleteReport() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('حذف التقرير',
              style: TextStyle(color: Color(0xFF14532D), fontWeight: FontWeight.bold)),
          content: const Text('هل أنت متأكد من حذف هذا التقرير؟',
              style: TextStyle(color: Colors.grey)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      // If shared, remove from community feed too
      if (_isShared && _feedDocId != null) {
        await FirebaseFirestore.instance
            .collection('community_feed').doc(_feedDocId).delete();
      }
      // Delete from top-level reports collection
      await FirebaseFirestore.instance
          .collection('reports').doc(widget.report['id']).delete();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🗑️ تم حذف التقرير', textDirection: TextDirection.rtl),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.report['imageUrl'] ?? '';//Jumana

    return Scaffold(
      backgroundColor: _green50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _green600),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('تفاصيل التقرير',
            style: TextStyle(color: _green900, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),



          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 8),

            //Jumana
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 12),

            // ── Status card ──────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3))],
              ),
              child: Column(children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: _sb, shape: BoxShape.circle),
                  child: Icon(_isHealthy ? Icons.check_circle_outline : Icons.error_outline,
                      color: _sc, size: 46),
                ),
                const SizedBox(height: 12),
                Text(widget.report['plantName'],
                    style: const TextStyle(color: _green900,
                        fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: _sb, borderRadius: BorderRadius.circular(20)),
                  child: Text(widget.report['status'],
                      style: TextStyle(color: _sc, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(height: 8),
                Text('📅 ${widget.report['date']}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Confidence ───────────────────
            _InfoCard(
              title: 'دقة التشخيص',
              child: Row(children: [
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (widget.report['confidence'] as int) / 100,
                    backgroundColor: const Color(0xFFE5E7EB),
                    color: _sc, minHeight: 10,
                  ),
                )),
                const SizedBox(width: 12),
                Text('${widget.report['confidence']}٪',
                    style: TextStyle(color: _sc, fontWeight: FontWeight.bold, fontSize: 18)),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Diagnosis ────────────────────
            _InfoCard(
              title: 'التشخيص',
              icon: Icons.biotech_rounded,
              child: Text(widget.report['disease'],
                  style: const TextStyle(color: _green900, fontSize: 14, height: 1.6)),
            ),
            const SizedBox(height: 12),

            // ── Treatment ────────────────────
            _InfoCard(
              title: 'العلاج الموصى به',
              icon: Icons.healing_rounded,
              child: Text(widget.report['treatment'],
                  style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.6)),
            ),
            const SizedBox(height: 24),

            // ── Row 1: PDF + Share toggle ────
            Row(children: [
              Expanded(child: _ActionBtn(
                icon: Icons.picture_as_pdf_rounded,
                label: 'تصدير PDF',
                color: const Color(0xFF0284C7),
                onTap: _exportPDF,
              )),
              const SizedBox(width: 10),
              Expanded(child: _sharingLoading
                  ? Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Center(child: SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)),
                )),
              )
                  : _ActionBtn(
                icon: _isShared ? Icons.cancel_outlined : Icons.share_rounded,
                label: _isShared ? 'إلغاء المشاركة' : 'مشاركة',
                color: _isShared ? Colors.orange : _green600,
                onTap: _shareToggle,
              )),
            ]),
            const SizedBox(height: 10),

            // ── Row 2: Delete + Close ────────
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: _deleteReport,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.shade300, width: 1.5),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                    const SizedBox(width: 6),
                    Text('حذف', style: TextStyle(color: Colors.red.shade400,
                        fontWeight: FontWeight.bold, fontSize: 14)),
                  ]),
                ),
              )),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.close, color: Colors.grey.shade500, size: 20),
                    const SizedBox(width: 6),
                    Text('إغلاق', style: TextStyle(color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold, fontSize: 14)),
                  ]),
                ),
              )),
            ]),
            const SizedBox(height: 30),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  WIDGETS
// ═══════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final Color bgColor;
  const _StatCard({required this.value, required this.label,
    required this.color, required this.bgColor});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: bgColor, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ]),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;
  const _InfoCard({required this.title, required this.child, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (icon != null) ...[
          Icon(icon, color: const Color(0xFF16A34A), size: 18),
          const SizedBox(width: 6),
        ],
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 10),
      child,
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label,
    required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    ),
  );
}