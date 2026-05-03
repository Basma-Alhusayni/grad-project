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

  // Show the failure dialog after the screen loads if the diagnosis failed
  @override
  void initState() {
    super.initState();
    if (widget.result.status == DiagnosisStatus.failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCustomFailureDialog();
      });
    }
  }

  // Shows a dialog when diagnosis fails — lets user contact an expert or try again
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
                  'لم نتمكن من الحصول على نتائج دقيقة\nماذا تريد أن تفعل؟',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
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
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300, width: 1.2),
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

  // Uploads the diagnosed plant image to Cloudinary and returns the remote URL
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

  // Saves the diagnosis result as a report in Firestore under the user's profile
  Future<void> _saveToProfile() async {
    if (_isAlreadySaved) return;

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['fullName'] ?? userDoc.data()?['username'] ?? 'مستخدم';

      final remoteUrl = await _uploadImage();
      if (remoteUrl == null) throw Exception("فشل رفع الصورة للسحابة");

      int display(double raw) => (raw > 0 && raw < 25) ? 25 : raw.round();

      await FirebaseFirestore.instance.collection('reports').add({
        'userId': user.uid,
        'userName': userName,
        'plantName': widget.result.plantNameAr,
        'diagnosis': widget.result.diagnosis,
        'details': widget.result.details,
        'status': widget.result.status == DiagnosisStatus.healthy ? 'سليم' : 'مريض',
        'confidence': widget.result.confidence.round(),
        'plantNameConfidence': display(widget.result.plantNetConfidence),
        'diseaseConfidence':   display(widget.result.modelDiseaseConfidence),
        'plantNetLabel':       widget.result.plantNetLabel,
        'modelDiseaseLabel':   widget.result.modelDiseaseLabel,
        'treatment': widget.result.treatment,
        'imageUrl': remoteUrl,
        'date': DateTime.now().toString().split(' ')[0],
        'createdAt': FieldValue.serverTimestamp(),
        'isHealthy': widget.result.status == DiagnosisStatus.healthy,
        'plantType': widget.result.plantNetLabel,
        'isSharedToCommunity': false,
        'feedDocId': '',
      });

      if (!mounted) return;

      setState(() { _isAlreadySaved = true; });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حفظ التقرير في ملفك الشخصي', textDirection: TextDirection.rtl),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في الحفظ: $e', textDirection: TextDirection.rtl)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Generates a PDF report with the plant image and diagnosis details, then shares it
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

      final bool isHealthy = widget.result.status == DiagnosisStatus.healthy;

      int display(double raw) => (raw > 0 && raw < 25) ? 25 : raw.round();

      final int plantConf   = display(widget.result.plantNetConfidence);
      final int diseaseConf = display(widget.result.modelDiseaseConfidence);
      final String plantLbl   = widget.result.plantNetLabel;
      final String diseaseLbl = widget.result.modelDiseaseLabel;

      bool isDiseased(String label) {
        final l = label.toLowerCase();
        return l.isNotEmpty &&
            !l.contains('healthy') &&
            !l.contains('fresh') &&
            !l.contains('سليم') &&
            !l.contains('طازج');
      }

      final String diseaseSublabel = diseaseLbl.isNotEmpty
          ? (isDiseased(diseaseLbl)
          ? 'تم رصد علامات مرضية: $diseaseLbl'
          : 'النبات سليم')
          : '—';

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
                  _pdfResultRow('الحالة الصحية:', isHealthy ? 'سليم' : 'مريض'),
                  pw.SizedBox(height: 12),
                  _pdfConfidenceBlock(
                    arabicFont: arabicFont,
                    label: 'دقة تحديد الاسم العلمي للنبات:',
                    percent: plantConf,
                    sublabel: plantLbl.isNotEmpty ? plantLbl : '—',
                    barColor: PdfColors.green700,
                  ),
                  pw.SizedBox(height: 10),
                  _pdfConfidenceBlock(
                    arabicFont: arabicFont,
                    label: 'دقة تشخيص المرض:',
                    percent: diseaseConf,
                    sublabel: diseaseSublabel,
                    barColor: isDiseased(diseaseLbl) ? PdfColors.red700 : PdfColors.green700,
                  ),
                  pw.SizedBox(height: 15),
                  pw.Text('التشخيص الملحوظ:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 5),
                    child: pw.Text(widget.result.diagnosis,
                        style: const pw.TextStyle(fontSize: 12)),
                  ),
                  pw.SizedBox(height: 15),
                  pw.Text('العلاج الموصى به:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 5),
                    child: pw.Text(widget.result.treatment,
                        style: const pw.TextStyle(fontSize: 12)),
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

  // A single label-value row used inside the PDF layout
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

  // A confidence bar block used inside the PDF showing percentage and a progress bar
  pw.Widget _pdfConfidenceBlock({
    required pw.Font arabicFont,
    required String label,
    required int percent,
    required String sublabel,
    required PdfColor barColor,
  }) {
    final double fraction = (percent / 100).clamp(0.0, 1.0);
    const double totalWidth = 515.0;
    final double filledWidth = totalWidth * fraction;

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label,
            style: pw.TextStyle(font: arabicFont, fontSize: 11, color: PdfColors.grey700)),
        pw.Text('$percent%',
            style: pw.TextStyle(
                font: arabicFont, fontSize: 11,
                fontWeight: pw.FontWeight.bold, color: barColor)),
      ]),
      pw.SizedBox(height: 4),
      pw.Stack(children: [
        pw.Container(
          height: 8,
          width: totalWidth,
          decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
        ),
        if (filledWidth > 0)
          pw.Container(
            height: 8,
            width: filledWidth,
            decoration: pw.BoxDecoration(
                color: barColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
          ),
      ]),
      pw.SizedBox(height: 3),
      pw.Text(sublabel,
          style: pw.TextStyle(
              font: arabicFont, fontSize: 10,
              fontStyle: pw.FontStyle.italic, color: barColor)),
    ]);
  }

  // Returns the right color based on whether the plant is healthy, diseased, or failed
  Color get _statusColor {
    switch (widget.result.status) {
      case DiagnosisStatus.healthy:  return AppTheme.primaryGreen;
      case DiagnosisStatus.diseased: return AppTheme.red;
      case DiagnosisStatus.failed:   return AppTheme.orange;
      default:                       return AppTheme.grey;
    }
  }

  // Returns the background color matching the diagnosis status
  Color get _statusBgColor {
    switch (widget.result.status) {
      case DiagnosisStatus.healthy:  return AppTheme.bgGreen;
      case DiagnosisStatus.diseased: return AppTheme.lightRed;
      case DiagnosisStatus.failed:   return AppTheme.lightOrange;
      default:                       return AppTheme.lightGrey;
    }
  }

  // Returns an emoji icon matching the diagnosis status
  String get _statusIcon =>
      widget.result.status == DiagnosisStatus.healthy ? '✅' :
      widget.result.status == DiagnosisStatus.diseased ? '🔴' : '❌';

  // Returns a short Arabic description of the diagnosis status
  String get _statusText {
    switch (widget.result.status) {
      case DiagnosisStatus.healthy:  return 'النبات سليم وبصحة جيدة';
      case DiagnosisStatus.diseased: return 'تم اكتشاف مرض';
      case DiagnosisStatus.failed:   return 'فشل التشخيص';
      default:                       return 'جاري التحليل';
    }
  }

  // Builds the full results screen: plant image, status header, info cards, save and export buttons
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
                _FullWidthImage(imagePath: widget.result.imagePath)
                    .animate().fadeIn(duration: 400.ms),
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
                      content: widget.result.status == DiagnosisStatus.failed
                          ? '—'
                          : (widget.result.plantNameAr.isNotEmpty && widget.result.plantNameAr != 'نبات')
                          ? widget.result.plantNameAr
                          : (widget.result.plantName.isNotEmpty && widget.result.plantName != 'نبات')
                          ? widget.result.plantName
                          : '—',
                      backgroundColor: AppTheme.lightPurple,
                      borderColor: AppTheme.purple.withOpacity(0.3),
                      titleColor: AppTheme.purple,
                      icon: '🌱',
                    ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
                    const SizedBox(height: 12),
                    _FullWidthInfoCard(
                      title: widget.result.status == DiagnosisStatus.healthy
                          ? 'الحالة الصحية'
                          : widget.result.status == DiagnosisStatus.failed
                          ? 'نتيجة التشخيص'
                          : 'التشخيص',
                      content: widget.result.status == DiagnosisStatus.failed
                          ? '—'
                          : widget.result.diagnosis.isNotEmpty
                          ? widget.result.diagnosis
                          : '—',
                      backgroundColor: widget.result.status == DiagnosisStatus.healthy
                          ? AppTheme.bgGreen
                          : widget.result.status == DiagnosisStatus.failed
                          ? AppTheme.lightOrange
                          : AppTheme.lightRed,
                      borderColor: _statusColor.withOpacity(0.3),
                      titleColor: _statusColor,
                      icon: widget.result.status == DiagnosisStatus.healthy
                          ? '💚'
                          : widget.result.status == DiagnosisStatus.failed
                          ? '⚠️'
                          : '🔬',
                    ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                    const SizedBox(height: 12),
                    _FullWidthInfoCard(
                      title: 'التفاصيل والمعلومات',
                      content: widget.result.status == DiagnosisStatus.failed
                          ? '—'
                          : widget.result.details.trim().isNotEmpty
                          ? widget.result.details
                          : '—',
                      backgroundColor: AppTheme.lightBlue,
                      borderColor: AppTheme.blue.withOpacity(0.3),
                      titleColor: AppTheme.blue,
                      icon: 'ℹ️',
                    ).animate().fadeIn(duration: 400.ms, delay: 280.ms),
                    const SizedBox(height: 12),
                    _FullWidthInfoCard(
                      title: widget.result.status == DiagnosisStatus.healthy
                          ? 'نصائح العناية'
                          : widget.result.status == DiagnosisStatus.failed
                          ? 'التوصيات'
                          : 'العلاج الموصى به',
                      content: widget.result.status == DiagnosisStatus.failed
                          ? '—'
                          : widget.result.treatment.trim().isNotEmpty
                          ? widget.result.treatment
                          : '—',
                      backgroundColor: const Color(0xFFFFFBEB),
                      borderColor: AppTheme.orange.withOpacity(0.3),
                      titleColor: AppTheme.orange,
                      icon: widget.result.status == DiagnosisStatus.healthy
                          ? '🌿'
                          : widget.result.status == DiagnosisStatus.failed
                          ? '💡'
                          : '💊',
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

  // A green full-width button used for the main action
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

  // A greyed-out button shown when the report has already been saved
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

  // An outlined button used for secondary actions like exporting PDF
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

class _FullWidthImage extends StatelessWidget {
  final String imagePath;
  const _FullWidthImage({required this.imagePath});

  // Shows the plant photo at full width at the top of the screen
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 280),
      color: Colors.black,
      child: Image.file(
        File(imagePath),
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 200,
          color: AppTheme.bgGreen,
          child: const Center(child: Icon(Icons.broken_image_rounded, color: AppTheme.grey, size: 48)),
        ),
      ),
    );
  }
}

class _FullWidthInfoCard extends StatelessWidget {
  final String title, content, icon;
  final Color backgroundColor, borderColor, titleColor;

  const _FullWidthInfoCard({
    required this.title,
    required this.content,
    required this.backgroundColor,
    required this.borderColor,
    required this.titleColor,
    required this.icon,
  });

  // A colored card showing a titled section with icon and text content
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: Text(
              content,
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.7),
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final String statusText, statusIcon;
  final Color statusColor, statusBgColor;
  final double confidence, plantNetConfidence, openAIPlantConfidence,
      modelDiseaseConfidence, openAIDiseaseConfidence;
  final String plantNetLabel, openAIPlantLabel, modelDiseaseLabel, openAIDiseaseLabel;

  const _StatusHeader({
    required this.statusText,
    required this.statusIcon,
    required this.statusColor,
    required this.statusBgColor,
    required this.confidence,
    required this.plantNetConfidence,
    required this.plantNetLabel,
    required this.openAIPlantConfidence,
    required this.openAIPlantLabel,
    required this.modelDiseaseConfidence,
    required this.modelDiseaseLabel,
    required this.openAIDiseaseConfidence,
    required this.openAIDiseaseLabel,
  });

  // Bumps very low confidence values up to 25% so the bar is always visible
  double _display(double raw) => (raw > 0 && raw < 25) ? 25.0 : raw;

  // Returns true if the disease model label is not a healthy or fresh label
  bool get _tfliteIsDiseased {
    final label = modelDiseaseLabel.toLowerCase();
    if (label.isEmpty) return false;
    return !label.contains('healthy') &&
        !label.contains('fresh') &&
        !label.contains('سليم') &&
        !label.contains('طازج');
  }

  // Builds the status card showing the result icon, status text, and two confidence bars
  @override
  Widget build(BuildContext context) {
    final isFailed = statusColor == AppTheme.orange;
    final plantDisplay    = isFailed ? 0.0 : _display(plantNetConfidence);
    final diseaseDisplay  = isFailed ? 0.0 : _display(modelDiseaseConfidence);
    final diseaseBarColor = _tfliteIsDiseased ? AppTheme.red : AppTheme.primaryGreen;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(statusIcon, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(
            'نتيجة التشخيص',
            style: TextStyle(fontSize: 13, color: statusColor.withOpacity(0.7)),
          ),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 20),
          _ConfidenceBar(
            label: 'دقة تحديد الاسم العلمي للنبات',
            icon: '🌿',
            value: plantDisplay,
            barColor: AppTheme.primaryGreen,
            trackColor: statusColor.withOpacity(0.1),
            sublabel: isFailed ? '—' : (plantNetLabel.isNotEmpty ? plantNetLabel : '—'),
          ),
          const SizedBox(height: 14),
          Divider(color: statusColor.withOpacity(0.15)),
          const SizedBox(height: 14),
          _ConfidenceBar(
            label: 'دقة تشخيص المرض',
            icon: '🧬',
            value: diseaseDisplay,
            barColor: diseaseBarColor,
            trackColor: statusColor.withOpacity(0.1),
            sublabel: isFailed
                ? '—'
                : (_tfliteIsDiseased
                ? 'تم رصد علامات مرضية: $modelDiseaseLabel'
                : 'النبات سليم'),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  final String label, icon, sublabel;
  final double value;
  final Color barColor, trackColor;

  const _ConfidenceBar({
    required this.label,
    required this.icon,
    required this.value,
    required this.barColor,
    required this.trackColor,
    required this.sublabel,
  });

  // Builds a labeled progress bar showing a confidence percentage for plant name or disease
  @override
  Widget build(BuildContext context) {
    final fraction = (value / 100).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const Spacer(),
            Text(
              value > 0 ? '${value.toStringAsFixed(0)}%' : '—',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: trackColor,
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
        const SizedBox(height: 6),
        Text(
          sublabel,
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: barColor.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}