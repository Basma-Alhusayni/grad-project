import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/diagnosis_service.dart';
import '../widgets/common_widgets.dart';
import 'diagnosis_result_screen.dart';

class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({super.key});

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  File? _imageFile;
  bool _isAnalyzing = false;
  DiagnosisStep? _currentStep;
  int? _selectedCategoryIndex;
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, String>> _categories = [
    {'label': 'خضار\nوفواكه', 'emoji': '🥦'},
    {'label': 'سعف\nالنخل',   'emoji': '🌴'},
    {'label': 'ورق\nالنعناع', 'emoji': '🌿'},
    {'label': 'أخرى',         'emoji': '🔍'},
  ];

  // Shows a confirmation dialog when the user tries to exit the app
  Future<bool> _onWillPop() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'الخروج من التطبيق',
          style: TextStyle(color: AppTheme.darkGreen),
        ),
        content: const Text('هل تريد الخروج من التطبيق؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (shouldExit == true) SystemNavigator.pop();
    return false;
  }

  // Requests camera or gallery permission then lets the user pick a plant image
  Future<void> _pickImage(ImageSource source) async {
    PermissionStatus status;

    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      status = await Permission.photos.request();
      if (status.isDenied) status = await Permission.storage.request();
    }

    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera
                  ? 'يلزم الإذن للوصول للكاميرا'
                  : 'يلزم الإذن للوصول للصور',
            ),
            backgroundColor: AppTheme.red,
            action: SnackBarAction(
              label: 'الإعدادات',
              textColor: Colors.white,
              onPressed: openAppSettings,
            ),
          ),
        );
      }
      return;
    }

    try {
      final XFile? xfile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (xfile != null && mounted) {
        setState(() => _imageFile = File(xfile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  // Sends the selected image to the diagnosis service and navigates to the results screen
  Future<void> _analyzeImage() async {
    if (_imageFile == null) return;

    setState(() {
      _isAnalyzing = true;
      _currentStep = DiagnosisStep.identifyingPlant;
    });

    try {
      final result = await DiagnosisService.instance.analyze(
        imageFile: _imageFile!,
        onProgress: (step) {
          if (mounted) setState(() => _currentStep = step);
        },
      );

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _currentStep = null;
        });

        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, anim, __) =>
                DiagnosisResultScreen(result: result),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _currentStep = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التحليل: $e'),
            backgroundColor: AppTheme.red,
          ),
        );
      }
    }
  }

  // Builds the main diagnosis screen: category row, image picker card, and tips card
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  height: 80,
                  child: _CategoryRow(
                    categories: _categories,
                    selectedIndex: _selectedCategoryIndex,
                    onSelected: (index) {
                      setState(() => _selectedCategoryIndex = index);
                      _pickImage(ImageSource.camera);
                    },
                  ).animate().fadeIn(duration: 350.ms),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Expanded(
                            child: _imageFile == null
                                ? _buildPlaceholder()
                                : _buildImagePreview(),
                          ),
                          const SizedBox(height: 12),

                          if (_imageFile == null) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: GradientButton(
                                    label: 'الكاميرا',
                                    icon: Icons.camera_alt_rounded,
                                    onPressed: () =>
                                        _pickImage(ImageSource.camera),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 54,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _pickImage(ImageSource.gallery),
                                      icon: const Icon(
                                          Icons.photo_library_rounded,
                                          size: 20),
                                      label: const Text(
                                        'المعرض',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: AppTheme.primaryGreen,
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                        foregroundColor: AppTheme.primaryGreen,
                                        backgroundColor: Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 54,
                                    child: OutlinedButton.icon(
                                      onPressed: _isAnalyzing
                                          ? null
                                          : () => setState(
                                              () => _imageFile = null),
                                      icon: const Icon(Icons.refresh_rounded,
                                          size: 20),
                                      label: const Text(
                                        'إعادة التقاط',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: AppTheme.primaryGreen,
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                        foregroundColor: AppTheme.primaryGreen,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 54,
                                    child: ElevatedButton.icon(
                                      onPressed: _isAnalyzing
                                          ? null
                                          : _analyzeImage,
                                      icon: _isAnalyzing
                                          ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFF59E0B),
                                        ),
                                      )
                                          : const Icon(Icons.search_rounded,
                                          size: 20),
                                      label: Text(
                                        _isAnalyzing
                                            ? 'جاري التحليل...'
                                            : 'تحليل الصورة',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                        const Color(0xFFFFFBEB),
                                        foregroundColor:
                                        const Color(0xFFF59E0B),
                                        elevation: 0,
                                        side: const BorderSide(
                                          color: Color(0xFFF59E0B),
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                ),

                const SizedBox(height: 16),
                _TipsCard().animate().fadeIn(duration: 400.ms, delay: 200.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // A tappable placeholder shown before the user picks an image
  Widget _buildPlaceholder() {
    return GestureDetector(
      onTap: () => _pickImage(ImageSource.gallery),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.bgGreen, AppTheme.bgEmerald],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryGreen.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 56,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'اضغط لاختيار صورة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'أو استخدم الكاميرا لالتقاط صورة جديدة',
              style: TextStyle(fontSize: 12, color: AppTheme.grey),
            ),
          ],
        ),
      ),
    );
  }

  // Shows the selected image with a loading overlay while analysis is running
  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            _imageFile!,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        if (_isAnalyzing)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 3),
                  const SizedBox(height: 12),
                  Text(
                    _currentStep?.labelAr ?? 'جاري التحليل...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final List<Map<String, String>> categories;
  final int? selectedIndex;
  final void Function(int index) onSelected;

  const _CategoryRow({
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  });

  // Builds a row of plant category buttons that highlight when selected
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(categories.length, (i) {
        final isSelected = selectedIndex == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryGreen.withOpacity(0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : AppTheme.primaryGreen.withOpacity(0.25),
                  width: isSelected ? 2 : 1.2,
                ),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    categories[i]['emoji']!,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    categories[i]['label']!.replaceAll('\n', ' '),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.darkGreen
                          : AppTheme.primaryGreen,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _TipsCard extends StatelessWidget {

  // A blue card showing photography tips to help the user get better diagnosis results
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '💡 نصائح للحصول على أفضل النتائج',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppTheme.blue,
            ),
          ),
          SizedBox(height: 8),
          _Tip('تأكد من وضوح الصورة والإضاءة الجيدة'),
          _Tip('صوّر الجزء المصاب من النبات بوضوح'),
          _Tip('تجنب الظلال والانعكاسات الضوئية'),
          _Tip('اقترب من النبات لالتقاط تفاصيل أوضح'),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final String text;
  const _Tip(this.text);

  // A single bullet point tip row
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
                color: AppTheme.blue, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF1D4ED8)),
            ),
          ),
        ],
      ),
    );
  }
}