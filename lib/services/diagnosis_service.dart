import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/diagnosis_result.dart';
import 'tflite_service.dart';
import 'openai_service.dart';

typedef ProgressCallback = void Function(DiagnosisStep step);

enum DiagnosisStep {
  identifyingPlant,
  checkingDisease,
  fetchingTreatment,
  done,
}

extension DiagnosisStepLabel on DiagnosisStep {
  String get labelAr {
    switch (this) {
      case DiagnosisStep.identifyingPlant:  return 'جاري تحديد نوع النبات...';
      case DiagnosisStep.checkingDisease:   return 'جاري فحص الحالة الصحية...';
      case DiagnosisStep.fetchingTreatment: return 'جاري الحصول على توصيات العلاج...';
      case DiagnosisStep.done:              return 'اكتمل التحليل!';
    }
  }

  String get icon {
    switch (this) {
      case DiagnosisStep.identifyingPlant:  return '🔍';
      case DiagnosisStep.checkingDisease:   return '🧬';
      case DiagnosisStep.fetchingTreatment: return '💊';
      case DiagnosisStep.done:              return '✅';
    }
  }
}

class DiagnosisService {
  static DiagnosisService? _instance;
  static DiagnosisService get instance => _instance ??= DiagnosisService._();
  DiagnosisService._();

  Future<DiagnosisResult> analyze({
    required File imageFile,
    ProgressCallback? onProgress,
  }) async {
    final imageBytes = await imageFile.readAsBytes();

    // ── STEP 1: Plant identification — PlantNet + OpenAI in parallel ──────────
    onProgress?.call(DiagnosisStep.identifyingPlant);

    String plantNamePlantNet   = 'نبات';
    String plantNameOpenAI     = 'نبات';
    String plantNameArOpenAI   = 'نبات';
    double plantNetConf        = 0.0;
    double openAIPlantConf     = 0.0;
    PlantType detectedType     = PlantType.vegetablesFruits;

    final plantResults = await Future.wait([
      TFLiteService.instance.identifyPlant(imageBytes).catchError((e) {
        debugPrint('⚠️ PlantNet failed: $e');
        return <String, dynamic>{};
      }),
      OpenAIService.instance.identifyPlantWithCategory(imageBytes).catchError((e) {
        debugPrint('⚠️ OpenAI plant ID failed: $e');
        return <String, dynamic>{};
      }),
    ]);

    final plantNetResult    = plantResults[0] as Map<String, dynamic>;
    final openAIPlantResult = plantResults[1] as Map<String, dynamic>;

    if (plantNetResult.isNotEmpty) {
      plantNamePlantNet = plantNetResult['plantName'] as String? ?? 'نبات';
      plantNetConf      = (plantNetResult['confidence'] as double?) ?? 0.0;
    }

    if (openAIPlantResult.isNotEmpty) {
      plantNameOpenAI   = openAIPlantResult['plantName']   as String? ?? 'نبات';
      plantNameArOpenAI = openAIPlantResult['plantNameAr'] as String? ?? 'نبات';
      openAIPlantConf   = double.tryParse(
          openAIPlantResult['confidence']?.toString() ?? '0') ?? 0.0;
    }

    final String finalPlantName   = openAIPlantConf >= plantNetConf
        ? plantNameOpenAI : plantNamePlantNet;
    final String finalPlantNameAr = openAIPlantConf >= plantNetConf
        ? plantNameArOpenAI : _translateToArabic(plantNamePlantNet);

    debugPrint('🌿 PlantNet: $plantNamePlantNet (${plantNetConf.toStringAsFixed(1)}%)');
    debugPrint('🌿 OpenAI:   $plantNameOpenAI (${openAIPlantConf.toStringAsFixed(1)}%)');

    // ── Check if plant is outside supported categories ────────────────────────
    final category = openAIPlantResult['category'] as String? ?? 'other';
    debugPrint('🗂️  Category: $category');

    if (category == 'other') {
      debugPrint('⛔ Plant not in supported categories — returning unsupported result');
      onProgress?.call(DiagnosisStep.done);
      return DiagnosisResult(
        plantName:               finalPlantName,
        plantNameAr:             finalPlantNameAr,
        diagnosis:               'هذا النبات ليس ضمن النباتات المدعومة حالياً',
        diseaseType:             'غير محدد',
        treatment:               'يمكنك التواصل مع خبير زراعي للحصول على تشخيص دقيق لهذا النبات.',
        details:                 'النماذج المدعومة حالياً هي: الخضار والفواكه، النعناع، والنخيل.',
        confidence:              0,
        status:                  DiagnosisStatus.failed,
        imagePath:               imageFile.path,
        timestamp:               DateTime.now(),
        plantNetConfidence:      plantNetConf,
        plantNetLabel:           plantNamePlantNet,
        openAIPlantConfidence:   openAIPlantConf,
        openAIPlantLabel:        plantNameOpenAI,
        modelDiseaseConfidence:  0,
        modelDiseaseLabel:       '',
        openAIDiseaseConfidence: 0,
        openAIDiseaseLabel:      '',
      );
    }

    detectedType = _categoryToPlantType(category);
    debugPrint('🗂️  Model selected: $detectedType');

    // ── STEP 2: Disease diagnosis — TFLite + OpenAI in parallel ──────────────
    onProgress?.call(DiagnosisStep.checkingDisease);

    bool   tfliteIsHealthy      = false;
    String tfliteDiseaseLabelAr = 'غير محدد';
    String tfliteDiseaseLabelEn = '';
    String tfliteDiseaseType    = 'غير محدد';
    double tfliteDiseaseConf    = 0.0;

    bool   openAIIsHealthy    = false;
    String openAIDiagnosis    = 'غير محدد';
    String openAIDiseaseLabel = '—';
    String openAIDiseaseType  = 'غير محدد';
    double openAIDiseaseConf  = 0.0;
    String openAIDetails      = '';
    String openAITreatment    = '';

    final diseaseResults = await Future.wait([
      TFLiteService.instance
          .diagnosePlant(imageBytes, detectedType)
          .catchError((e) {
        debugPrint('⚠️ TFLite disease failed: $e');
        return <String, dynamic>{};
      }),
      OpenAIService.instance.diagnoseFromImage(imageBytes).catchError((e) {
        debugPrint('⚠️ OpenAI vision failed: $e');
        return <String, dynamic>{};
      }),
    ]);

    final tfliteResult = diseaseResults[0] as Map<String, dynamic>;
    final openAIVision = diseaseResults[1] as Map<String, dynamic>;

    if (tfliteResult.isNotEmpty) {
      tfliteIsHealthy      = tfliteResult['isHealthy']   as bool?   ?? false;
      tfliteDiseaseLabelAr = tfliteResult['labelAr']     as String? ?? 'غير محدد';
      tfliteDiseaseLabelEn = tfliteResult['labelEn']     as String? ?? '';
      tfliteDiseaseType    = tfliteResult['diseaseType'] as String? ?? 'غير محدد';
      tfliteDiseaseConf    = (tfliteResult['confidence'] as double?) ?? 0.0;

      if (tfliteResult['label'] == 'Background_without_leaves') {
        tfliteDiseaseConf    = 0.0;
        tfliteDiseaseLabelAr = 'لم يُكتشف نبات';
        tfliteDiseaseLabelEn = 'No plant';
      }
      debugPrint('🔬 TFLite: $tfliteDiseaseLabelAr (${tfliteDiseaseConf.toStringAsFixed(1)}%)');
    }

    if (openAIVision.isNotEmpty) {
      openAIIsHealthy   = openAIVision['isHealthy'] == 'true';
      openAIDiagnosis   = openAIVision['diagnosis']  as String? ?? 'غير محدد';
      openAIDiseaseType = openAIVision['diseaseType'] as String? ?? 'غير محدد';

      final rawDiseaseName = openAIVision['diseaseName'] as String? ?? '';
      final hasArabic = rawDiseaseName.runes.any((r) => r >= 0x0600 && r <= 0x06FF);
      if (rawDiseaseName.isNotEmpty && hasArabic) {
        openAIDiseaseLabel = rawDiseaseName;
      } else if (openAIDiseaseType == 'سليم') {
        openAIDiseaseLabel = 'سليم';
      } else if (openAIDiseaseType.isNotEmpty && openAIDiseaseType != 'غير محدد') {
        openAIDiseaseLabel = openAIDiseaseType;
      } else {
        openAIDiseaseLabel = '—';
      }

      openAIDiseaseConf = double.tryParse(
          openAIVision['confidence']?.toString() ?? '0') ?? 0.0;
      openAIDetails   = _stripBrackets(openAIVision['details']   as String? ?? '');
      openAITreatment = _stripBrackets(openAIVision['treatment'] as String? ?? '');

      // Sanity check: OpenAI says healthy but diagnosis text mentions disease
      const diseaseKeywords = [
        'مرض', 'إصابة', 'عفن', 'فطر', 'بكتيريا', 'فيروس', 'تلف', 'ضرر',
        'بقع', 'لفحة', 'اصفرار', 'ذبول', 'rot', 'blight', 'mold', 'spot',
        'disease', 'infection', 'fungal', 'bacterial', 'virus', 'damage',
      ];
      if (openAIIsHealthy && openAIDiseaseType != 'سليم') {
        final diagLower = openAIDiagnosis.toLowerCase();
        for (final kw in diseaseKeywords) {
          if (diagLower.contains(kw.toLowerCase())) {
            openAIIsHealthy = false;
            debugPrint('⚠️ OpenAI healthy override → DISEASED (keyword: $kw)');
            break;
          }
        }
      }
      debugPrint('🤖 OpenAI: healthy=$openAIIsHealthy | type=$openAIDiseaseType (${openAIDiseaseConf.toStringAsFixed(1)}%)');
    }

    onProgress?.call(DiagnosisStep.fetchingTreatment);

    // ── STEP 3: Weighted majority vote ────────────────────────────────────────
    final healthyScore  = (tfliteIsHealthy  ? tfliteDiseaseConf : 0.0)
        + (openAIIsHealthy  ? openAIDiseaseConf : 0.0);
    final diseasedScore = (!tfliteIsHealthy ? tfliteDiseaseConf : 0.0)
        + (!openAIIsHealthy ? openAIDiseaseConf : 0.0);
    final bool finalIsHealthy = healthyScore > diseasedScore;

    debugPrint('📊 Healthy: $healthyScore | Diseased: $diseasedScore → ${finalIsHealthy ? "HEALTHY" : "DISEASED"}');

    final String finalDiseaseType = tfliteDiseaseConf >= openAIDiseaseConf
        ? tfliteDiseaseType : openAIDiseaseType;
    final String finalDiagnosis   = openAIDiagnosis.isNotEmpty
        ? openAIDiagnosis
        : (finalIsHealthy ? 'النبات سليم وبصحة جيدة' : tfliteDiseaseLabelAr);

    String treatment = openAITreatment;
    if (treatment.isEmpty) {
      try {
        final textResult = await OpenAIService.instance.getPlantDiagnosisDetails(
          plantName:   finalPlantName,
          diseaseName: tfliteDiseaseLabelEn.isNotEmpty
              ? tfliteDiseaseLabelEn : openAIDiagnosis,
          diseaseType: finalDiseaseType,
          isHealthy:   finalIsHealthy,
          plantTypeAr: detectedType.labelAr,
        );
        treatment = textResult['treatment'] ?? '';
      } catch (e) {
        debugPrint('⚠️ Text details failed: $e');
      }
    }

    onProgress?.call(DiagnosisStep.done);

    final allScores = [
      if (plantNetConf > 0) plantNetConf,
      if (openAIPlantConf > 0) openAIPlantConf,
      if (tfliteDiseaseConf > 0) tfliteDiseaseConf,
      if (openAIDiseaseConf > 0) openAIDiseaseConf,
    ];
    final combined = allScores.isEmpty
        ? 0.0
        : allScores.reduce((a, b) => a + b) / allScores.length;

    final status = combined < 15
        ? DiagnosisStatus.failed
        : finalIsHealthy
        ? DiagnosisStatus.healthy
        : DiagnosisStatus.diseased;

    return DiagnosisResult(
      plantName:               finalPlantName,
      plantNameAr:             finalPlantNameAr,
      diagnosis:               finalDiagnosis,
      diseaseType:             finalIsHealthy ? 'سليم' : finalDiseaseType,
      treatment:               treatment,
      details:                 openAIDetails,
      confidence:              combined.clamp(0.0, 100.0),
      status:                  status,
      imagePath:               imageFile.path,
      timestamp:               DateTime.now(),
      plantNetConfidence:      plantNetConf,
      plantNetLabel:           plantNamePlantNet,
      openAIPlantConfidence:   openAIPlantConf,
      openAIPlantLabel:        plantNameOpenAI,
      modelDiseaseConfidence:  tfliteDiseaseConf,
      modelDiseaseLabel:       tfliteDiseaseLabelAr.isNotEmpty
          ? tfliteDiseaseLabelAr : tfliteDiseaseLabelEn,
      openAIDiseaseConfidence: openAIDiseaseConf,
      openAIDiseaseLabel:      openAIDiseaseLabel,
    );
  }

  // ── Map OpenAI category string → PlantType ────────────────────────────────
  PlantType _categoryToPlantType(String category) {
    switch (category.toLowerCase().trim()) {
      case 'palm':       return PlantType.palm;
      case 'mint':       return PlantType.mint;
      case 'vegetables': return PlantType.vegetablesFruits;
      default:           return PlantType.vegetablesFruits; // safe fallback
    }
  }

  String _stripBrackets(String text) =>
      text.replaceAll('[', '').replaceAll(']', '').trim();

  String _translateToArabic(String scientificName) {
    final name = scientificName.toLowerCase();
    const Map<String, String> genusMap = {
      'helianthus':   'عباد الشمس',  'solanum':      'باذنجان/طماطم',
      'lycopersicon': 'طماطم',        'capsicum':     'فلفل',
      'mangifera':    'مانجو',        'citrus':       'حمضيات',
      'rosa':         'وردة',         'mentha':       'نعناع',
      'ocimum':       'ريحان',        'allium':       'بصل/ثوم',
      'cucumis':      'خيار/شمام',    'cucurbita':    'قرع',
      'phaseolus':    'فاصوليا',      'lactuca':      'خس',
      'brassica':     'خضروات',       'phoenix':      'نخيل التمر',
      'ziziphus':     'نبق',          'acacia':       'سنط',
    };
    for (final e in genusMap.entries) {
      if (name.contains(e.key)) return e.value;
    }
    return scientificName.replaceAll(RegExp(r'\s+[A-Z][a-z]*\..*$'), '').trim();
  }
}