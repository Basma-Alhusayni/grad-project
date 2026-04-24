import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;

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

  late Stream<QuerySnapshot> _reportsStreamVar;

  @override
  void initState() {
    super.initState();
    _reportsStreamVar = _getReportsStream();
  }

  Stream<QuerySnapshot> _getReportsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('reports')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _filterChip(String label, int count) {
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
      stream: _reportsStreamVar,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _green600));
        }

        final allDocs = snapshot.data?.docs ?? [];
        final allReports = allDocs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id':                  doc.id,
            'plantName':           data['plantName'] ?? '',
            'disease':             data['diagnosis'] ?? '',
            'status':              data['status'] ?? '',
            'date':                data['date'] ?? '',
            'confidence':          data['confidence'] ?? 0,
            // ─── two separate confidence fields ───
            'plantNameConfidence': data['plantNameConfidence'] ?? data['confidence'] ?? 0,
            'diseaseConfidence':   data['diseaseConfidence'] ?? data['confidence'] ?? 0,
            'plantNetLabel':       data['plantNetLabel'] ?? '',
            'modelDiseaseLabel':   data['modelDiseaseLabel'] ?? '',
            // ──────────────────────────────────────
            'treatment':           data['treatment'] ?? '',
            'plantType':           data['plantType'] ?? '',
            'icon':                _iconForPlant(data['plantType'] ?? ''),
            'feedDocId':           data['feedDocId'] ?? '',
            'details':             data['details'] ?? '',
            'imageUrl':            data['imageUrl'] ?? '',
            'userName':            data['userName'] ?? '',
            'userId':              data['userId'] ?? '',
          };
        }).toList();

        final filtered = allReports.where((r) {
          final matchFilter = _filter == 'الكل' || r['status'] == _filter;
          final matchSearch = _search.isEmpty ||
              (r['plantName'] as String).toLowerCase().contains(_search.toLowerCase());
          return matchFilter && matchSearch;
        }).toList();

        final sharedCount = allReports.where((r) => (r['feedDocId'] as String).isNotEmpty).length;

        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              _StatCard(value: '${allReports.length}', label: 'الكل', color: const Color(0xFF0284C7), bgColor: const Color(0xFFEFF6FF)),
              const SizedBox(width: 8),
              _StatCard(value: '${allReports.where((r) => r['status'] == 'مريض').length}', label: 'مريضة', color: const Color(0xFFDC2626), bgColor: const Color(0xFFFEF2F2)),
              const SizedBox(width: 8),
              _StatCard(value: '${allReports.where((r) => r['status'] == 'سليم').length}', label: 'صحية', color: const Color(0xFF16A34A), bgColor: const Color(0xFFDCFCE7)),
              const SizedBox(width: 8),
              _StatCard(value: '$sharedCount', label: 'مشاركة', color: const Color(0xFF7C3AED), bgColor: const Color(0xFFF3F0FF)),
            ]),
          ),
          const SizedBox(height: 14),
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
                    : const Icon(Icons.search, color: _green600),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _green600, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _filterChip('الكل', allReports.length),
              const SizedBox(width: 8),
              _filterChip('مريض', allReports.where((r) => r['status'] == 'مريض').length),
              const SizedBox(width: 8),
              _filterChip('سليم', allReports.where((r) => r['status'] == 'سليم').length),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (_, i) => _ReportCard(report: filtered[i], key: ValueKey(filtered[i]['id'])),
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('لا توجد نتائج', style: TextStyle(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.bold)),
        ]));
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  const _ReportCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final isHealthy = report['status'] == 'سليم';
    final sc = isHealthy ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final sb = isHealthy ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final isShared = (report['feedDocId'] as String).isNotEmpty;
    final imageUrl = report['imageUrl'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportDetailPage(report: report))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isHealthy ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA), width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, width: 52, height: 52, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 52, height: 52, color: sb,
                    child: Center(child: Text(report['icon'], style: const TextStyle(fontSize: 26)))))
                : Container(width: 52, height: 52, color: sb,
                child: Center(child: Text(report['icon'], style: const TextStyle(fontSize: 26)))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(report['plantName'], style: const TextStyle(color: Color(0xFF14532D), fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 3),
            Text(report['disease'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 4),
            Row(children: [
              Text(report['date'], style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              if (isShared) ...[const SizedBox(width: 8), _SharedBadge()],
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: sb, borderRadius: BorderRadius.circular(20)),
                child: Text(report['status'], style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey[400]),
          ]),
        ]),
      ),
    );
  }
}

class _SharedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFFF3F0FF), borderRadius: BorderRadius.circular(10)),
      child: const Row(children: [
        Icon(Icons.share_rounded, color: Color(0xFF7C3AED), size: 10),
        SizedBox(width: 3),
        Text('مشارك', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  REPORT DETAIL PAGE
// ═══════════════════════════════════════════════════════════════
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
  static const _darkBg   = Color(0xFF2D322C);

  String? _feedDocId;
  bool _isShared = false;
  bool _sharingLoading = false;

  bool get _isHealthy => widget.report['status'] == 'سليم';
  Color get _sc => _isHealthy ? _green600 : const Color(0xFFDC2626);
  Color get _sb => _isHealthy ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);

  @override
  void initState() {
    super.initState();
    _feedDocId = widget.report['feedDocId']?.toString();
    _isShared = _feedDocId != null && _feedDocId!.isNotEmpty;
  }

  Future<void> _shareToggle() async {
    if (_sharingLoading) return;
    setState(() => _sharingLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (_isShared && _feedDocId != null) {
        // ── UNSHARE: delete from both community_feed and shared_reports ──
        await FirebaseFirestore.instance.collection('community_feed').doc(_feedDocId).delete();

        // Also delete from shared_reports if it exists there
        final sharedQuery = await FirebaseFirestore.instance
            .collection('shared_reports')
            .where('feedDocId', isEqualTo: _feedDocId)
            .get();
        for (final doc in sharedQuery.docs) {
          await doc.reference.delete();
        }

        await FirebaseFirestore.instance.collection('reports').doc(widget.report['id']).update({
          'feedDocId': '',
          'isSharedToCommunity': false,
        });
        setState(() { _isShared = false; _feedDocId = null; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم إلغاء المشاركة', textDirection: TextDirection.rtl)));

      } else {
        // ── SHARE ──
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final userName = userDoc.data()?['fullName'] ?? userDoc.data()?['username'] ?? 'مستخدم';

        // Shared payload includes both confidence values
        final sharedData = {
          'plantName':           widget.report['plantName'],
          'ImageUrl':            widget.report['imageUrl'],
          'diagnosis':           widget.report['disease'],
          'details':             widget.report['details'],
          'treatment':           widget.report['treatment'],
          'isHealthy':           _isHealthy,
          'confidence':          widget.report['confidence'],
          // ─── NEW: two percentages ───────────────────────────
          'plantNameConfidence': widget.report['plantNameConfidence'] ?? widget.report['confidence'],
          'diseaseConfidence':   widget.report['diseaseConfidence'] ?? widget.report['confidence'],
          'plantNetLabel':       widget.report['plantNetLabel'] ?? '',
          'modelDiseaseLabel':   widget.report['modelDiseaseLabel'] ?? '',
          // ────────────────────────────────────────────────────
          'status':              widget.report['status'],
          'date':                widget.report['date'],
          'createdAt':           FieldValue.serverTimestamp(),
          'sharedBy':            userName,     // ← person's real name
          'userId':              user.uid,
          'reportId':            widget.report['id'],
        };

        // Write to community_feed (for the home feed)
        final ref = await FirebaseFirestore.instance.collection('community_feed').add(sharedData);

        // Write to shared_reports (for admin management)
        await FirebaseFirestore.instance.collection('shared_reports').add({
          ...sharedData,
          'feedDocId': ref.id,
        });

        // Update the report document
        await FirebaseFirestore.instance.collection('reports').doc(widget.report['id']).update({
          'feedDocId': ref.id,
          'isSharedToCommunity': true,
        });

        setState(() { _isShared = true; _feedDocId = ref.id; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ تمت المشاركة مع المجتمع!', textDirection: TextDirection.rtl),
                  backgroundColor: _green600));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _sharingLoading = false);
    }
  }

  Future<void> _exportPDF() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جاري حفظ التقرير...', textDirection: TextDirection.rtl),
              duration: Duration(seconds: 2)));
      final pdf = pw.Document();
      final fontData = await rootBundle.load("assets/fonts/Amiri-Regular.ttf");
      final arabicFont = pw.Font.ttf(fontData);

      pw.MemoryImage? reportImage;
      if (widget.report['imageUrl'].isNotEmpty) {
        final resp = await http.get(Uri.parse(widget.report['imageUrl']));
        if (resp.statusCode == 200) reportImage = pw.MemoryImage(resp.bodyBytes);
      }

      // Values are already stored with the minimum-25 rule applied at save time
      final int plantNameConf  = ((widget.report['plantNameConfidence'] ?? widget.report['confidence'] ?? 0) as num).toInt();
      final int diseaseConf    = ((widget.report['diseaseConfidence']   ?? widget.report['confidence'] ?? 0) as num).toInt();
      final String plantLabelPdf   = (widget.report['plantNetLabel']     ?? '').toString();
      final String diseaseLabelPdf = (widget.report['modelDiseaseLabel'] ?? '').toString();
      final bool isHealthyPdf = widget.report['status'] == 'سليم';
      final String diseaseSublabel = diseaseLabelPdf.isNotEmpty
          ? (isHealthyPdf ? 'النبات سليم' : 'تم رصد علامات مرضية: $diseaseLabelPdf')
          : '—';

      pdf.addPage(pw.Page(
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFont),
        build: (ctx) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Center(child: pw.Text('تقرير تشخيص BioShield',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
            pw.Divider(),
            if (reportImage != null)
              pw.Center(child: pw.Container(height: 200, width: 300,
                  child: pw.Image(reportImage, fit: pw.BoxFit.cover))),
            _pdfRow('اسم النبات:', widget.report['plantName']),
            _pdfRow('الحالة الصحية:', widget.report['status']),
            _pdfRow('تاريخ الفحص:', widget.report['date']),
            pw.SizedBox(height: 10),
            // ─── Plant name confidence block ───────────────────
            _pdfConfidenceBlock(
              arabicFont: arabicFont,
              label: 'دقة تحديد الاسم العلمي للنبات:',
              percent: plantNameConf,
              sublabel: plantLabelPdf.isNotEmpty ? plantLabelPdf : '—',
              barColor: PdfColors.green700,
            ),
            pw.SizedBox(height: 10),
            // ─── Disease confidence block ──────────────────────
            _pdfConfidenceBlock(
              arabicFont: arabicFont,
              label: 'دقة تشخيص المرض:',
              percent: diseaseConf,
              sublabel: diseaseSublabel,
              barColor: isHealthyPdf ? PdfColors.green700 : PdfColors.red700,
            ),
            pw.SizedBox(height: 15),
            pw.Text('التشخيص الملحوظ:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(widget.report['disease'], style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 10),
            pw.Text('التفاصيل والمعلومات:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(widget.report['details'], style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 10),
            pw.Text('العلاج الموصى به:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(widget.report['treatment'], style: const pw.TextStyle(fontSize: 12)),
            pw.Spacer(),
            pw.Center(child: pw.Text('تم إنشاء هذا التقرير بواسطة تطبيق BioShield',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey))),
          ]),
        ),
      ));

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/bioshield_report.pdf");
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'تقرير BioShield');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ فشل تصدير الملف'), backgroundColor: Colors.red));
    }
  }

  pw.Widget _pdfRow(String label, String value) =>
      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(children: [
            pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(width: 5),
            pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
          ]));

  // ── PDF confidence bar block (label + bar + sublabel) ─────────
  pw.Widget _pdfConfidenceBlock({
    required pw.Font arabicFont,
    required String label,
    required int percent,
    required String sublabel,
    required PdfColor barColor,
  }) {
    final fraction = (percent / 100).clamp(0.0, 1.0);
    // A4 usable width ≈ 515 pt (595 − 40 margins each side)
    const double totalWidth = 515.0;
    final double filledWidth = totalWidth * fraction;

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      // Header row: label + percent
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(font: arabicFont, fontSize: 11, color: PdfColors.grey700)),
        pw.Text('$percent%', style: pw.TextStyle(font: arabicFont, fontSize: 11,
            fontWeight: pw.FontWeight.bold, color: barColor)),
      ]),
      pw.SizedBox(height: 4),
      // Progress bar — track
      pw.Stack(children: [
        pw.Container(
          height: 8,
          width: totalWidth,
          decoration: pw.BoxDecoration(
            color: PdfColors.grey300,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
        ),
        // Filled portion — only render when non-zero to avoid zero-width artefact
        if (filledWidth > 0)
          pw.Container(
            height: 8,
            width: filledWidth,
            decoration: pw.BoxDecoration(
              color: barColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
          ),
      ]),
      pw.SizedBox(height: 3),
      // Sublabel
      pw.Text(sublabel, style: pw.TextStyle(font: arabicFont, fontSize: 10,
          fontStyle: pw.FontStyle.italic, color: barColor)),
    ]);
  }

  Future<void> _deleteReport() async {
    if (_isShared) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن حذف التقرير المشارك', textDirection: TextDirection.rtl),
              backgroundColor: _darkBg));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف التقرير'),
          content: const Text('هل أنت متأكد من الحذف؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('حذف', style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('reports').doc(widget.report['id']).delete();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('🗑️ تم الحذف', textDirection: TextDirection.rtl),
                  backgroundColor: _darkBg));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ خطأ: $e', textDirection: TextDirection.rtl)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl            = widget.report['imageUrl'] ?? '';
    final double confidence   = (widget.report['confidence'] as num).toDouble();
    final int plantNameConf   = (widget.report['plantNameConfidence'] as num?)?.toInt() ?? confidence.toInt();
    final int diseaseConf     = (widget.report['diseaseConfidence'] as num?)?.toInt() ?? confidence.toInt();
    final String plantLabel   = (widget.report['plantNetLabel'] ?? '').toString();
    final String diseaseLabel = (widget.report['modelDiseaseLabel'] ?? '').toString();

    return Scaffold(
      backgroundColor: _green50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text('تفاصيل التقرير',
            style: TextStyle(color: _green900, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          Transform.rotate(
            angle: 3.14159,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              color: Colors.black,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(borderRadius: BorderRadius.circular(16),
                  child: Image.network(imageUrl, height: 180, fit: BoxFit.cover)),
            const SizedBox(height: 12),

            // ── Status card ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
              child: Column(children: [
                Icon(_isHealthy ? Icons.check_circle : Icons.error, color: _sc, size: 60),
                const SizedBox(height: 12),
                Text(widget.report['plantName'],
                    style: const TextStyle(color: _green900, fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: _sb, borderRadius: BorderRadius.circular(20)),
                    child: Text(widget.report['status'], style: TextStyle(color: _sc, fontWeight: FontWeight.bold))),
                const SizedBox(height: 16),

                // ─── Two confidence bars ──────────────────────
                _ConfidenceRow(
                  label: '🌿 دقة تحديد اسم النبات',
                  value: plantNameConf,
                  color: _green600,
                  sublabel: plantLabel.isNotEmpty ? plantLabel : '—',
                ),
                const SizedBox(height: 10),
                _ConfidenceRow(
                  label: '🧬 دقة تشخيص المرض',
                  value: diseaseConf,
                  color: _isHealthy ? _green600 : const Color(0xFFDC2626),
                  sublabel: diseaseLabel.isNotEmpty
                      ? (_isHealthy ? 'النبات سليم' : 'تم رصد علامات مرضية: $diseaseLabel')
                      : '—',
                ),
                // ─────────────────────────────────────────────

                const SizedBox(height: 12),
                Text('📅 ${widget.report['date']}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 12),

            _InfoCard(
              title: _isHealthy ? 'الحالة الصحية' : 'التشخيص',
              icon: _isHealthy ? Icons.check_circle_outline : Icons.biotech,
              titleColor: _sc, backgroundColor: _sb, borderColor: _sc.withOpacity(0.3),
              child: Text(widget.report['disease']),
            ),
            const SizedBox(height: 12),
            if (widget.report['details'].toString().isNotEmpty)
              _InfoCard(
                title: 'التفاصيل والمعلومات',
                icon: Icons.info_outline,
                titleColor: const Color(0xFF0284C7),
                backgroundColor: const Color(0xFFEFF6FF),
                borderColor: const Color(0xFF0284C7).withOpacity(0.3),
                child: Text(widget.report['details']),
              ),
            const SizedBox(height: 12),
            _InfoCard(
              title: _isHealthy ? 'نصائح العناية' : 'العلاج الموصى به',
              icon: _isHealthy ? Icons.eco_outlined : Icons.healing,
              titleColor: const Color(0xFFD97706),
              backgroundColor: const Color(0xFFFFFBEB),
              borderColor: const Color(0xFFD97706).withOpacity(0.3),
              child: Text(widget.report['treatment']),
            ),
            const SizedBox(height: 24),

            Row(children: [
              Expanded(child: _ActionBtn(icon: Icons.picture_as_pdf, label: 'PDF', color: Colors.blue, onTap: _exportPDF)),
              const SizedBox(width: 10),
              Expanded(
                child: _sharingLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _ActionBtn(
                  icon: _isShared ? Icons.cancel : Icons.share,
                  label: _isShared ? 'إلغاء المشاركة' : 'مشاركة',
                  color: _isShared ? Colors.orange : _green600,
                  onTap: _shareToggle,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            _ActionBtn(icon: Icons.delete_forever, label: 'حذف التقرير', color: Colors.red, onTap: _deleteReport),
            const SizedBox(height: 60),
          ]),
        ),
      ),
    );
  }
}

// ─── Reusable confidence bar with sublabel ────────────────────
class _ConfidenceRow extends StatelessWidget {
  final String label;
  final String sublabel;
  final int value;
  final Color color;
  const _ConfidenceRow({
    required this.label,
    required this.value,
    required this.color,
    this.sublabel = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text('$value%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: (value / 100).clamp(0.0, 1.0),
          backgroundColor: color.withOpacity(0.1),
          color: color,
          minHeight: 8,
        ),
      ),
      if (sublabel.isNotEmpty) ...[
        const SizedBox(height: 5),
        Text(
          sublabel,
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    ]);
  }
}


// ─── Shared helpers ───────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String value, label;
  final Color color, bgColor;
  const _StatCard({required this.value, required this.label, required this.color, required this.bgColor});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2))),
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
  final IconData icon;
  final Color titleColor, backgroundColor, borderColor;
  const _InfoCard({required this.title, required this.child, required this.icon,
    required this.titleColor, required this.backgroundColor, required this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor)),
    margin: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: titleColor, size: 18),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 10),
      DefaultTextStyle(
          style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.6),
          child: child),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52,
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ]),
    ),
  );
}