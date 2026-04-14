import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
enum _ScreenState { camera, processing, result, failure }

class DiagnosisResult {
  final String plantName;
  final String diagnosis;
  final String treatment;
  final bool isHealthy;
  final int confidence;
  DiagnosisResult({
    required this.plantName,
    required this.diagnosis,
    required this.treatment,
    required this.isHealthy,
    required this.confidence,
  });
}

class UserCameraScreen extends StatefulWidget {
  const UserCameraScreen({super.key});
  @override
  State<UserCameraScreen> createState() => _UserCameraScreenState();
}

class _UserCameraScreenState extends State<UserCameraScreen> {
  _ScreenState _state = _ScreenState.camera;
  File? _image;
  String? _selectedPlantType;
  DiagnosisResult? _result;

  static const _green900 = Color(0xFF14532D);
  static const _green700 = Color(0xFF15803D);
  static const _green600 = Color(0xFF16A34A);
  static const _green100 = Color(0xFFDCFCE7);
  static const _green50  = Color(0xFFF0FDF4);

  final _picker = ImagePicker();

  final _plantTypes = [
    {'id': 'vegetables', 'label': 'خضار وفواكه', 'icon': '🥬'},
    {'id': 'mint',       'label': 'ورق النعناع',  'icon': '🌿'},
    {'id': 'sidr',       'label': 'ورق النبق',    'icon': '🍃'},
    {'id': 'palm',       'label': 'سعف النخل',    'icon': '🌴'},
  ];

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
        source: source, imageQuality: 90, maxWidth: 1080);
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        _state = _ScreenState.camera;
      });
    }
  }

  Future<DiagnosisResult?> _runAIAnalysis() async {
    await Future.delayed(const Duration(seconds: 2));
    // TODO: Replace with real TFLite MobileNetV3 model
    final mockData = {
      'vegetables': DiagnosisResult(
        plantName: 'نبات الطماطم',
        diagnosis: 'النبات يعاني من لفحة مبكرة\nEarly Blight - Alternaria solani',
        treatment: 'إزالة الأوراق المصابة فوراً، رش مبيد فطري كل 7 أيام، تحسين التهوية حول النبات، تجنب الري الزائد.',
        isHealthy: false,
        confidence: 87,
      ),
      'mint': DiagnosisResult(
        plantName: 'نبات النعناع',
        diagnosis: 'النبات سليم وبصحة جيدة',
        treatment: 'استمر في الري المنتظم كل يومين، تعريض النبات للشمس لمدة 4-6 ساعات يومياً.',
        isHealthy: true,
        confidence: 95,
      ),
      'sidr': DiagnosisResult(
        plantName: 'نبات السدر (النبق)',
        diagnosis: 'إصابة بحشرات المن\nAphid Infestation',
        treatment: 'رش محلول الصابون والماء على الأوراق المصابة، استخدام مبيد حشري عضوي، تنظيف الأوراق بقطعة قماش مبللة أسبوعياً.',
        isHealthy: false,
        confidence: 78,
      ),
      'palm': DiagnosisResult(
        plantName: 'نخلة التمر',
        diagnosis: 'النخلة سليمة وبصحة جيدة',
        treatment: 'استمر في الري الأسبوعي والتسميد الدوري كل 3 أشهر.',
        isHealthy: true,
        confidence: 92,
      ),
    };
    return mockData[_selectedPlantType];
  }

  Future<void> _analyze() async {
    if (_selectedPlantType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('الرجاء اختيار نوع النبات أولاً', textDirection: TextDirection.rtl),
      ));
      return;
    }
    setState(() => _state = _ScreenState.processing);
    try {
      final result = await _runAIAnalysis();
      if (result == null || result.confidence < 60) {
        if (!mounted) return;
        setState(() => _state = _ScreenState.failure);
        return;
      }
      if (!mounted) return;
      setState(() { _result = result; _state = _ScreenState.result; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _state = _ScreenState.failure);
    }
  }

  // ── UPDATED: saves to top-level reports collection ──
  Future<void> _saveReport() async {
    if (_result == null) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('reports').add({
        'userId':              user.uid,
        'plantName':           _result!.plantName,
        'diagnosis':           _result!.diagnosis,
        'treatment':           _result!.treatment,
        'isHealthy':           _result!.isHealthy,
        'confidence':          _result!.confidence,
        'status':              _result!.isHealthy ? 'سليم' : 'مريض',
        'plantType':           _selectedPlantType,
        'date':                DateTime.now().toIso8601String().split('T')[0],
        'createdAt':           FieldValue.serverTimestamp(),
        'isSharedToCommunity': false,  // ← false by default
        'feedDocId':           '',     // ← empty until user shares
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ تم حفظ التقرير في ملفك الشخصي',
            textDirection: TextDirection.rtl),
        backgroundColor: Color(0xFF16A34A),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('❌ حدث خطأ أثناء الحفظ، تأكد من اتصال الإنترنت',
            textDirection: TextDirection.rtl),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _exportPDF() async {
    if (_result == null) return;
    try {
      final pdf = pw.Document();
      pdf.addPage(pw.Page(
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('BioShield - Plant Diagnosis Report',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 12),
            pw.Text('Plant Name: ${_result!.plantName}', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Text('Status: ${_result!.isHealthy ? "Healthy ✓" : "Diseased ✗"}', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Text('Confidence: ${_result!.confidence}%', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Text('Diagnosis: ${_result!.diagnosis}', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 8),
            pw.Text('Treatment: ${_result!.treatment}', style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.Text('Date: ${DateTime.now().toIso8601String().split("T")[0]}', style: const pw.TextStyle(fontSize: 12)),
            pw.Text('Generated by BioShield AI System', style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
      ));
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/bioshield_report.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'تقرير تشخيص النبات - BioShield');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('❌ حدث خطأ أثناء تصدير PDF', textDirection: TextDirection.rtl),
      ));
    }
  }

  Future<void> _share() async {
    if (_result == null) return;
    await Share.share(
      'تقرير BioShield 🌿\n━━━━━━━━━━━━━━━━━━\n'
          'النبات: ${_result!.plantName}\n'
          'التشخيص: ${_result!.diagnosis}\n'
          'الحالة: ${_result!.isHealthy ? "سليم ✅" : "مريض ❌"}\n'
          'دقة التشخيص: ${_result!.confidence}%\n'
          'العلاج: ${_result!.treatment}\n'
          '━━━━━━━━━━━━━━━━━━\n'
          'التاريخ: ${DateTime.now().toIso8601String().split("T")[0]}',
    );
  }

  void _showExpertDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Text('⚠️', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Flexible(child: Text('فشل التشخيص التلقائي',
                style: TextStyle(color: Color(0xFF14532D), fontWeight: FontWeight.bold, fontSize: 16))),
          ]),
          content: const Text(
            'لم نتمكن من تشخيص النبات بدقة كافية.\nهل تريد التواصل مع أحد خبرائنا المعتمدين للحصول على تشخيص دقيق؟',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('لاحقاً', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('سيتم تحويلك لصفحة الخبراء قريباً', textDirection: TextDirection.rtl),
                ));
              },
              child: const Text('التواصل مع خبير', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _reset() => setState(() {
    _image = null;
    _selectedPlantType = null;
    _state = _ScreenState.camera;
    _result = null;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Directionality(textDirection: TextDirection.rtl, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _ScreenState.camera:     return _buildCameraScreen();
      case _ScreenState.processing: return _buildProcessing();
      case _ScreenState.result:     return _buildResultScreen();
      case _ScreenState.failure:    return _buildFailureScreen();
    }
  }

  Widget _buildCameraScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 8),
        _Card(child: Column(children: [
          const Text('تشخيص النبات',
              style: TextStyle(color: _green900, fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 16),
          _image == null ? _buildPlaceholder() : _buildPreview(),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _GreenBtn(label: 'فتح الكاميرا', icon: Icons.camera_alt_rounded, onTap: () => _pickImage(ImageSource.camera))),
            const SizedBox(width: 12),
            Expanded(child: _OutlineBtn(label: 'رفع صورة', icon: Icons.upload_rounded, onTap: () => _pickImage(ImageSource.gallery))),
          ]),
          if (_image != null) ...[
            const SizedBox(height: 12),
            _GreenBtn(label: 'تحليل الصورة', icon: Icons.biotech_rounded, onTap: _analyze),
          ],
        ])),
        const SizedBox(height: 16),
        _Card(child: Column(children: [
          const Text('اختر نوع النبات',
              style: TextStyle(color: _green900, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Row(children: _plantTypes.map((type) {
            final selected = _selectedPlantType == type['id'];
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _selectedPlantType = type['id']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: selected ? _green100 : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? _green600 : const Color(0xFFE5E7EB), width: selected ? 2 : 1),
                ),
                child: Column(children: [
                  Text(type['icon']!, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(type['label']!, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10,
                          color: selected ? _green700 : Colors.grey[700],
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                ]),
              ),
            ));
          }).toList()),
        ])),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('💡 نصائح للحصول على أفضل النتائج:',
                style: TextStyle(color: Color(0xFF1E40AF), fontWeight: FontWeight.bold, fontSize: 13)),
            SizedBox(height: 8),
            _Tip('تأكد من وضوح الصورة والإضاءة الجيدة'),
            _Tip('صور الجزء المصاب من النبات بوضوح'),
            _Tip('تجنب الظلال والانعكاسات'),
            _Tip('اقترب من النبات لالتقاط تفاصيل أفضل'),
            _Tip('تأكد أن الصورة لنبات وليست لشيء آخر'),
          ]),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildPlaceholder() => Container(
    height: 220,
    decoration: BoxDecoration(
      color: _green50, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF86EFAC), width: 2),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.camera_alt_outlined, size: 56, color: _green600.withValues(alpha: 0.5)),
      const SizedBox(height: 12),
      Text('التقط صورة للنبات أو ارفع صورة\nمن معرض الصور',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 13)),
    ]),
  );

  Widget _buildPreview() => Stack(children: [
    ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.file(_image!, height: 240, width: double.infinity, fit: BoxFit.cover),
    ),
    Positioned(top: 8, left: 8, child: GestureDetector(
      onTap: () => setState(() => _image = null),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: const Icon(Icons.close, color: Colors.white, size: 16),
      ),
    )),
  ]);

  Widget _buildProcessing() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(
      width: 100, height: 100,
      decoration: BoxDecoration(
        color: _green100, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: _green600.withValues(alpha: 0.2), blurRadius: 24, spreadRadius: 4)],
      ),
      child: const Center(child: CircularProgressIndicator(color: _green600, strokeWidth: 3)),
    ),
    const SizedBox(height: 24),
    const Text('جاري تحليل الصورة...', style: TextStyle(color: _green900, fontSize: 18, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    Text('يرجى الانتظار', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
  ]));

  Widget _buildResultScreen() {
    final r = _result!;
    final sc = r.isHealthy ? _green600 : const Color(0xFFDC2626);
    final sb = r.isHealthy ? _green100 : const Color(0xFFFEE2E2);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 8),
        _Card(child: Column(children: [
          Container(width: 70, height: 70,
              decoration: BoxDecoration(color: sb, shape: BoxShape.circle),
              child: Icon(r.isHealthy ? Icons.check_circle_outline : Icons.error_outline, color: sc, size: 40)),
          const SizedBox(height: 12),
          const Text('نتيجة التشخيص', style: TextStyle(color: _green900, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: sb, borderRadius: BorderRadius.circular(20)),
            child: Text('دقة التشخيص: ${r.confidence}٪',
                style: TextStyle(color: sc, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ])),
        const SizedBox(height: 12),
        _Card(child: Row(children: [
          const Icon(Icons.eco_rounded, color: _green600, size: 22),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('اسم النبات', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(r.plantName, style: const TextStyle(color: _green900, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
        ])),
        const SizedBox(height: 12),
        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('التشخيص', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Text(r.diagnosis, style: const TextStyle(color: _green900, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: sb, borderRadius: BorderRadius.circular(20)),
            child: Text(r.isHealthy ? 'سليم' : 'مريض',
                style: TextStyle(color: sc, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ])),
        const SizedBox(height: 12),
        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Text('🌱', style: TextStyle(fontSize: 16)),
            SizedBox(width: 6),
            Text('العلاج الموصى به', style: TextStyle(color: _green900, fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          Text(r.treatment, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
        ])),
        const SizedBox(height: 20),
        _GreenBtn(label: 'حفظ التقرير في ملفي الشخصي', icon: Icons.save_alt_rounded, onTap: _saveReport),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _OutlineBtn(label: 'تصدير PDF', icon: Icons.picture_as_pdf_rounded, onTap: _exportPDF)),
          const SizedBox(width: 12),
          Expanded(child: _OutlineBtn(label: 'مشاركة', icon: Icons.share_rounded, onTap: _share)),
        ]),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh, color: _green600),
          label: const Text('تشخيص جديد', style: TextStyle(color: _green600)),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildFailureScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _showExpertDialog());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 40),
        _Card(child: Column(children: [
          Container(width: 70, height: 70,
              decoration: const BoxDecoration(color: Color(0xFFFEE2E2), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 40)),
          const SizedBox(height: 16),
          const Text('فشل التشخيص', style: TextStyle(color: Color(0xFF14532D), fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          Text('عذراً، لم نتمكن من تشخيص النبات بدقة كافية.\nيمكنك المحاولة مرة أخرى أو التواصل مع أحد الخبراء.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ])),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFCD34D)),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('⚠️', style: TextStyle(fontSize: 22)),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('هل تحتاج مساعدة خبير؟',
                  style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(height: 4),
              Text('يمكنك التواصل مع أحد خبرائنا المعتمدين للحصول على تشخيص دقيق لنبتاتك.',
                  style: TextStyle(color: Color(0xFF78350F), fontSize: 12)),
            ])),
          ]),
        ),
        const SizedBox(height: 20),
        _GreenBtn(label: 'التواصل مع خبير', icon: Icons.people_alt_rounded, onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('سيتم تحويلك لصفحة الخبراء قريباً', textDirection: TextDirection.rtl),
          ));
        }),
        const SizedBox(height: 12),
        _OutlineBtn(label: 'حاول مرة أخرى', icon: Icons.refresh_rounded, onTap: _reset),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3))],
    ),
    child: child,
  );
}

class _GreenBtn extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  const _GreenBtn({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF15803D), Color(0xFF16A34A)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x3316A34A), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF16A34A), width: 1.5),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: const Color(0xFF16A34A), size: 20),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
    ),
  );
}

class _Tip extends StatelessWidget {
  final String text;
  const _Tip(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('• ', style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 13)),
      Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 12))),
    ]),
  );
}