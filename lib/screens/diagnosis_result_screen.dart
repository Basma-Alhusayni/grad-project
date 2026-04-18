import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../models/diagnosis_result.dart';
import '../widgets/common_widgets.dart';
import 'expert_selection_screen.dart';

class DiagnosisResultScreen extends StatefulWidget {
  final DiagnosisResult result;
  const DiagnosisResultScreen({super.key, required this.result});

  @override
  State<DiagnosisResultScreen> createState() => _DiagnosisResultScreenState();
}

class _DiagnosisResultScreenState extends State<DiagnosisResultScreen> {
  bool _isSaving = false;
  bool _isAlreadySaved = false;

  final cloudinary = CloudinaryPublic(
      'dicojx5rg',
      'bioshield_preset',
      cache: false
  );

  @override
  void initState() {
    super.initState();
    if (widget.result.status == DiagnosisStatus.failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCustomFailureDialog();
      });
    }
  }

  void _showCustomFailureDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'فشل تشخيص المرض',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.red,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'لم نتمكن من الحصول على نتائج دقيقة\nماذا تريد أن تفعل؟', // إضافة سطر جديد هنا
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black, // نص أسود
                    fontSize: 16,       // حجم أكبر
                    height: 1.5,        // مسافة بين الأسطر
                  ),
                ),
                const SizedBox(height: 24),

                // زر التواصل مع خبير (الأخضر)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExpertSelectionScreen(failedImage: widget.result.imagePath),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_search_rounded, color: Colors.white),
                    label: const Text('التواصل مع خبير', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // زر حاول مرة أخرى (أبيض)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.refresh_rounded, color: Colors.grey),
                    label: const Text('حاول مرة أخرى', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white, // خلفية بيضاء
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300, width: 1.2), // إطار خفيف
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Future<String?> _uploadImage() async {
    try {
      if (!await File(widget.result.imagePath).exists()) return null;
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(widget.result.imagePath),
      );
      return response.secureUrl;
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveToProfile() async {
    if (_isAlreadySaved) return;

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final remoteUrl = await _uploadImage();
      if (remoteUrl == null) throw Exception("فشل رفع الصورة للسحابة");

      // الحقول التي سيتم حفظها في مجموعة reports
      await FirebaseFirestore.instance.collection('reports').add({
        'userId': user.uid,
        'plantName': widget.result.plantNameAr,      // اسم النبات
        'diagnosis': widget.result.diagnosis,        // التشخيص
        'details': widget.result.details,            // التفاصيل والمعلومات (تمت إضافتها هنا)
        'status': widget.result.status == DiagnosisStatus.healthy ? 'سليم' : 'مريض',
        'confidence': widget.result.confidence.toInt(),
        'treatment': widget.result.treatment,        // العلاج الموصى به
        'imageUrl': remoteUrl,
        'date': DateTime.now().toString().split(' ')[0],
        'createdAt': FieldValue.serverTimestamp(),
        'isHealthy': widget.result.status == DiagnosisStatus.healthy,
        'plantType': widget.result.plantNetLabel,
        'isSharedToCommunity': false,
      });

      if (!mounted) return;

      setState(() {
        _isAlreadySaved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ تم حفظ التقرير في ملفك الشخصي', textDirection: TextDirection.rtl),
            backgroundColor: Color(0xFF16A34A)
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ في الحفظ: $e', textDirection: TextDirection.rtl))
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _exportPDF() async {
    try {
      final pdf = pw.Document();
      final fontData = await rootBundle.load("assets/fonts/Amiri-Regular.ttf");
      final arabicFont = pw.Font.ttf(fontData);

      final File imageFile = File(widget.result.imagePath);
      pw.MemoryImage? profileImage;
      if (await imageFile.exists()) {
        profileImage = pw.MemoryImage(imageFile.readAsBytesSync());
      }

      pdf.addPage(
        pw.Page(
          theme: pw.ThemeData.withFont(
            base: arabicFont,
            bold: arabicFont,
            italic: arabicFont,
          ),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text('تقرير تشخيص BioShield',
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(thickness: 1),
                  pw.SizedBox(height: 15),
                  if (profileImage != null)
                    pw.Center(
                      child: pw.Container(
                        height: 200,
                        width: 300,
                        child: pw.Image(profileImage, fit: pw.BoxFit.cover),
                      ),
                    ),
                  pw.SizedBox(height: 20),
                  _pdfResultRow('اسم النبات:', widget.result.plantNameAr),
                  _pdfResultRow('الحالة الصحية:', widget.result.status == DiagnosisStatus.healthy ? "سليم" : "مريض"),
                  _pdfResultRow('دقة التشخيص:', '${widget.result.confidence.toInt()}%'),
                  pw.SizedBox(height: 15),
                  pw.Text('التشخيص الملحوظ:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 5),
                    child: pw.Text(widget.result.diagnosis, style: const pw.TextStyle(fontSize: 12)),
                  ),
                  pw.SizedBox(height: 15),
                  pw.Text('العلاج الموصى به:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 5),
                    child: pw.Text(widget.result.treatment, style: const pw.TextStyle(fontSize: 12)),
                  ),
                  pw.Spacer(),
                  pw.Divider(thickness: 0.5),
                  pw.Center(
                    child: pw.Text('تم إنشاء هذا التقرير بواسطة تطبيق BioShield',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/bioshield_report.pdf");
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'تقرير BioShield');

    } catch (e) {
      debugPrint("PDF Error: $e");
    }
  }

  pw.Widget _pdfResultRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(width: 5),
          pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Color get _statusColor {
    switch (widget.result.status) {
      case DiagnosisStatus.healthy:  return AppTheme.primaryGreen;
      case DiagnosisStatus.diseased: return AppTheme.red;
      case DiagnosisStatus.failed:   return AppTheme.orange;
      default:                       return AppTheme.grey;
    }
  }

  Color get _statusBgColor {
    switch (widget.result.status) {
      case DiagnosisStatus.healthy:  return AppTheme.bgGreen;
      case DiagnosisStatus.diseased: return AppTheme.lightRed;
      case DiagnosisStatus.failed:   return AppTheme.lightOrange;
      default:                       return AppTheme.lightGrey;
    }
  }

  String get _statusIcon => widget.result.status == DiagnosisStatus.healthy ? '✅' : (widget.result.status == DiagnosisStatus.diseased ? '🔴' : '❌');

  String get _statusText {
    switch (widget.result.status) {
      case DiagnosisStatus.healthy:  return 'النبات سليم وبصحة جيدة';
      case DiagnosisStatus.diseased: return 'تم اكتشاف مرض';
      case DiagnosisStatus.failed:   return 'فشل التشخيص';
      default:                       return 'جاري التحليل';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.bgGreen,
        appBar: AppBar(
          title: const Text('نتيجة التشخيص'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.result.imagePath.isNotEmpty)
                _FullWidthImage(imagePath: widget.result.imagePath).animate().fadeIn(duration: 400.ms),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatusHeader(
                      statusText: _statusText,
                      statusIcon: _statusIcon,
                      statusColor: _statusColor,
                      statusBgColor: _statusBgColor,
                      confidence: widget.result.confidence,
                      plantNetConfidence: widget.result.plantNetConfidence,
                      plantNetLabel: widget.result.plantNetLabel,
                      openAIPlantConfidence: widget.result.openAIPlantConfidence,
                      openAIPlantLabel: widget.result.openAIPlantLabel,
                      modelDiseaseConfidence: widget.result.modelDiseaseConfidence,
                      modelDiseaseLabel: widget.result.modelDiseaseLabel,
                      openAIDiseaseConfidence: widget.result.openAIDiseaseConfidence,
                      openAIDiseaseLabel: widget.result.openAIDiseaseLabel,
                    ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                    const SizedBox(height: 14),
                    _FullWidthInfoCard(
                      title: 'اسم النبات',
                      content: widget.result.plantNameAr,
                      backgroundColor: AppTheme.lightPurple,
                      borderColor: AppTheme.purple.withOpacity(0.3),
                      titleColor: AppTheme.purple,
                      icon: '🌱',
                    ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
                    const SizedBox(height: 12),
                    _FullWidthInfoCard(
                      title: widget.result.status == DiagnosisStatus.healthy ? 'الحالة الصحية' : 'التشخيص',
                      content: widget.result.diagnosis,
                      backgroundColor: widget.result.status == DiagnosisStatus.healthy ? AppTheme.bgGreen : AppTheme.lightRed,
                      borderColor: _statusColor.withOpacity(0.3),
                      titleColor: _statusColor,
                      icon: widget.result.status == DiagnosisStatus.healthy ? '💚' : '🔬',
                    ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                    const SizedBox(height: 12),
                    if (widget.result.details.trim().isNotEmpty)
                      _FullWidthInfoCard(
                        title: 'التفاصيل والمعلومات',
                        content: widget.result.details,
                        backgroundColor: AppTheme.lightBlue,
                        borderColor: AppTheme.blue.withOpacity(0.3),
                        titleColor: AppTheme.blue,
                        icon: 'ℹ️',
                      ).animate().fadeIn(duration: 400.ms, delay: 280.ms),
                    const SizedBox(height: 12),
                    if (widget.result.treatment.trim().isNotEmpty)
                      _FullWidthInfoCard(
                        title: widget.result.status == DiagnosisStatus.healthy ? 'نصائح العناية' : 'العلاج الموصى به',
                        content: widget.result.treatment,
                        backgroundColor: const Color(0xFFFFFBEB),
                        borderColor: AppTheme.orange.withOpacity(0.3),
                        titleColor: AppTheme.orange,
                        icon: widget.result.status == DiagnosisStatus.healthy ? '🌿' : '💊',
                      ).animate().fadeIn(duration: 400.ms, delay: 320.ms),
                    const SizedBox(height: 24),
                    _isSaving
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
                        : _isAlreadySaved
                        ? _buildDisabledButton(
                      label: 'تم حفظ التقرير مسبقاً',
                      icon: Icons.check_circle_outline_rounded,
                    )
                        : _buildMainButton(
                      label: 'حفظ التقرير في ملفي الشخصي',
                      icon: Icons.archive_outlined,
                      onTap: _saveToProfile,
                    ).animate().fadeIn(duration: 400.ms, delay: 350.ms),
                    const SizedBox(height: 12),
                    _buildSecondaryButton(
                      label: 'تصدير PDF',
                      icon: Icons.picture_as_pdf_rounded,
                      onTap: _exportPDF,
                    ).animate().fadeIn(duration: 400.ms, delay: 370.ms),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainButton({required String label, required IconData icon, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 22),
        label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildDisabledButton({required String label, required IconData icon}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: null,
        icon: Icon(icon, color: Colors.grey[600], size: 22),
        label: Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[300],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({required String label, required IconData icon, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: const Color(0xFF16A34A), size: 18),
        label: Text(label, style: const TextStyle(color: Color(0xFF16A34A), fontSize: 13, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ─── HELPER UI CLASSES ───────────────────────────────────────
class _FullWidthImage extends StatelessWidget {
  final String imagePath;
  const _FullWidthImage({required this.imagePath});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 280),
      color: Colors.black,
      child: Image.file(File(imagePath), width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 200, color: AppTheme.bgGreen, child: const Center(child: Icon(Icons.broken_image_rounded, color: AppTheme.grey, size: 48)))),
    );
  }
}

class _FullWidthInfoCard extends StatelessWidget {
  final String title, content, icon;
  final Color backgroundColor, borderColor, titleColor;
  const _FullWidthInfoCard({required this.title, required this.content, required this.backgroundColor, required this.borderColor, required this.titleColor, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(icon, style: const TextStyle(fontSize: 16)), const SizedBox(width: 6), Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor))]), const SizedBox(height: 10), SizedBox(width: double.infinity, child: Text(content, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.7), textAlign: TextAlign.start))]),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final String statusText, statusIcon;
  final Color statusColor, statusBgColor;
  final double confidence, plantNetConfidence, openAIPlantConfidence, modelDiseaseConfidence, openAIDiseaseConfidence;
  final String plantNetLabel, openAIPlantLabel, modelDiseaseLabel, openAIDiseaseLabel;
  const _StatusHeader({required this.statusText, required this.statusIcon, required this.statusColor, required this.statusBgColor, required this.confidence, required this.plantNetConfidence, required this.plantNetLabel, required this.openAIPlantConfidence, required this.openAIPlantLabel, required this.modelDiseaseConfidence, required this.modelDiseaseLabel, required this.openAIDiseaseConfidence, required this.openAIDiseaseLabel});
  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withOpacity(0.2)), boxShadow: [BoxShadow(color: statusColor.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))]), child: Column(children: [Text(statusIcon, style: const TextStyle(fontSize: 48)), const SizedBox(height: 8), Text('نتيجة التشخيص', style: TextStyle(fontSize: 13, color: statusColor.withOpacity(0.7))), Text(statusText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor)), const SizedBox(height: 16), _SectionLabel(label: 'تحديد النوع', icon: '🌿'), const SizedBox(height: 8), Row(children: [Expanded(child: _ConfidenceItem(label: 'PlantNet', icon: '🌍', value: plantNetConfidence, sublabel: _shortLabel(plantNetLabel))), Container(width: 1, height: 56, color: statusColor.withOpacity(0.15)), Expanded(child: _ConfidenceItem(label: 'OpenAI', icon: '🤖', value: openAIPlantConfidence, sublabel: _shortLabel(openAIPlantLabel)))]), const SizedBox(height: 14), Divider(color: statusColor.withOpacity(0.15)), const SizedBox(height: 8), _SectionLabel(label: 'تشخيص المرض', icon: '🔬'), const SizedBox(height: 8), Row(children: [Expanded(child: _ConfidenceItem(label: 'النموذج', icon: '🧬', value: modelDiseaseConfidence, sublabel: _shortLabel(modelDiseaseLabel), isDisease: modelDiseaseConfidence >= 20 && !modelDiseaseLabel.toLowerCase().contains('healthy'))), Container(width: 1, height: 56, color: statusColor.withOpacity(0.15)), Expanded(child: _ConfidenceItem(label: 'OpenAI', icon: '🤖', value: openAIDiseaseConfidence, sublabel: _shortLabel(openAIDiseaseLabel), isDisease: statusColor == AppTheme.red && openAIDiseaseConfidence >= 20))])]));
  }
  String _shortLabel(String label) { if (label.isEmpty || label == '—') return '—'; String clean = label.replaceAll('___', ' — ').replaceAll('__', ' ').replaceAll('_', ' ').trim(); if (!clean.runes.any((r) => r >= 0x0600 && r <= 0x06FF)) clean = clean.replaceAll(RegExp(r'\s+[A-Z][a-z]*\..*$'), '').trim(); return clean.length > 24 ? '${clean.substring(0, 22)}..' : clean; }
}

class _SectionLabel extends StatelessWidget {
  final String label, icon;
  const _SectionLabel({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) { return Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(icon, style: const TextStyle(fontSize: 13)), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.grey))]); }
}

class _ConfidenceItem extends StatelessWidget {
  final String label, icon, sublabel;
  final double value;
  final bool isDisease;
  const _ConfidenceItem({required this.label, required this.value, required this.icon, required this.sublabel, this.isDisease = false});
  @override
  Widget build(BuildContext context) { return Column(children: [Text(icon, style: const TextStyle(fontSize: 18)), const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.grey)), Text('${value.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))), const SizedBox(height: 2), Text(sublabel, style: const TextStyle(fontSize: 9, color: Color(0xFF374151), fontStyle: FontStyle.italic, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis)]); }
}