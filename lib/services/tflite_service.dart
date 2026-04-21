import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/diagnosis_result.dart';

class TFLiteService {
  static TFLiteService? _instance;
  static TFLiteService get instance => _instance ??= TFLiteService._();
  TFLiteService._();

  Interpreter? _plantNetInterpreter;
  Interpreter? _fruitVegInterpreter;
  Interpreter? _mintInterpreter;
  Interpreter? _palmInterpreter;

  List<String> _plantNetLabels = [];
  bool _isInitialized = false;

  static const List<String> fruitVegLabels = [
    'Apple___Apple_scab',
    'Apple___Black_rot',
    'Apple___Cedar_apple_rust',
    'Apple___healthy',
    'Background_without_leaves',
    'Blueberry___healthy',
    'Cherry___Powdery_mildew',
    'Cherry___healthy',
    'Corn___Cercospora_leaf_spot Gray_leaf_spot',
    'Corn___Common_rust',
    'Corn___Northern_Leaf_Blight',
    'Corn___healthy',
    'Grape___Black_rot',
    'Grape___Esca_(Black_Measles)',
    'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)',
    'Grape___healthy',
    'Orange___Haunglongbing_(Citrus_greening)',
    'Peach___Bacterial_spot',
    'Peach___healthy',
    'Pepper,_bell___Bacterial_spot',
    'Pepper,_bell___healthy',
    'Potato___Early_blight',
    'Potato___Late_blight',
    'Potato___healthy',
    'Raspberry___healthy',
    'Soybean___healthy',
    'Squash___Powdery_mildew',
    'Strawberry___Leaf_scorch',
    'Strawberry___healthy',
    'Tomato___Bacterial_spot',
    'Tomato___Early_blight',
    'Tomato___Late_blight',
    'Tomato___Leaf_Mold',
    'Tomato___Septoria_leaf_spot',
    'Tomato___Spider_mites Two-spotted_spider_mite',
    'Tomato___Target_Spot',
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
    'Tomato___Tomato_mosaic_virus',
    'Tomato___healthy',
  ];

  static const List<String> palmLabels = [
    'Potassium_Deficiency',
    'Manganese_Deficiency',
    'Magnesium_Deficiency',
    'Black_Scorch',
    'Leaf_Spots',
    'Fusarium_Wilt',
    'Rachis_Blight',
    'Parlatoria_Blanchardi',
    'healthy',
  ];

  // ── UPDATED: new mint model classes ─────────────────────────────────────────
  static const List<String> mintLabels = ['Dried', 'Fresh', 'Spoiled', 'Sunlight'];

  static const Map<String, Map<String, String>> diseaseTranslations = {
    'Apple___Apple_scab':             {'ar': 'جرب التفاح',                          'type': 'فطري',     'en': 'Apple Scab'},
    'Apple___Black_rot':              {'ar': 'العفن الأسود للتفاح',                 'type': 'فطري',     'en': 'Black Rot (Apple)'},
    'Apple___Cedar_apple_rust':       {'ar': 'صدأ التفاح',                          'type': 'فطري',     'en': 'Cedar Apple Rust'},
    'Apple___healthy':                {'ar': 'تفاح سليم',                           'type': 'سليم',     'en': 'Healthy'},
    'Background_without_leaves':      {'ar': 'خلفية بدون أوراق',                    'type': 'غير محدد', 'en': 'Background'},
    'Blueberry___healthy':            {'ar': 'توت أزرق سليم',                       'type': 'سليم',     'en': 'Healthy'},
    'Cherry___Powdery_mildew':        {'ar': 'البياض الدقيقي للكرز',                'type': 'فطري',     'en': 'Powdery Mildew (Cherry)'},
    'Cherry___healthy':               {'ar': 'كرز سليم',                            'type': 'سليم',     'en': 'Healthy'},
    'Corn___Cercospora_leaf_spot Gray_leaf_spot': {'ar': 'تبقع أوراق الذرة الرمادي','type': 'فطري',     'en': 'Gray Leaf Spot (Corn)'},
    'Corn___Common_rust':             {'ar': 'الصدأ الشائع للذرة',                  'type': 'فطري',     'en': 'Common Rust (Corn)'},
    'Corn___Northern_Leaf_Blight':    {'ar': 'لفحة أوراق الذرة الشمالية',           'type': 'فطري',     'en': 'Northern Leaf Blight'},
    'Corn___healthy':                 {'ar': 'ذرة سليمة',                           'type': 'سليم',     'en': 'Healthy'},
    'Grape___Black_rot':              {'ar': 'العفن الأسود للعنب',                   'type': 'فطري',     'en': 'Black Rot (Grape)'},
    'Grape___Esca_(Black_Measles)':   {'ar': 'مرض إيسكا (الحصبة السوداء) للعنب',   'type': 'فطري',     'en': 'Esca Black Measles (Grape)'},
    'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)': {'ar': 'لفحة أوراق العنب',       'type': 'فطري',     'en': 'Leaf Blight (Grape)'},
    'Grape___healthy':                {'ar': 'عنب سليم',                            'type': 'سليم',     'en': 'Healthy'},
    'Orange___Haunglongbing_(Citrus_greening)': {'ar': 'اخضرار الحمضيات',           'type': 'بكتيري',   'en': 'Citrus Greening'},
    'Peach___Bacterial_spot':         {'ar': 'التبقع البكتيري للخوخ',               'type': 'بكتيري',   'en': 'Bacterial Spot (Peach)'},
    'Peach___healthy':                {'ar': 'خوخ سليم',                            'type': 'سليم',     'en': 'Healthy'},
    'Pepper,_bell___Bacterial_spot':  {'ar': 'التبقع البكتيري للفلفل',              'type': 'بكتيري',   'en': 'Bacterial Spot (Pepper)'},
    'Pepper,_bell___healthy':         {'ar': 'فلفل سليم',                           'type': 'سليم',     'en': 'Healthy'},
    'Potato___Early_blight':          {'ar': 'اللفحة المبكرة للبطاطا',              'type': 'فطري',     'en': 'Early Blight (Potato)'},
    'Potato___Late_blight':           {'ar': 'اللفحة المتأخرة للبطاطا',             'type': 'فطري',     'en': 'Late Blight (Potato)'},
    'Potato___healthy':               {'ar': 'بطاطا سليمة',                         'type': 'سليم',     'en': 'Healthy'},
    'Raspberry___healthy':            {'ar': 'توت العليق سليم',                     'type': 'سليم',     'en': 'Healthy'},
    'Soybean___healthy':              {'ar': 'فول الصويا سليم',                     'type': 'سليم',     'en': 'Healthy'},
    'Squash___Powdery_mildew':        {'ar': 'البياض الدقيقي للقرع',                'type': 'فطري',     'en': 'Powdery Mildew (Squash)'},
    'Strawberry___Leaf_scorch':       {'ar': 'احتراق أوراق الفراولة',               'type': 'فطري',     'en': 'Leaf Scorch (Strawberry)'},
    'Strawberry___healthy':           {'ar': 'فراولة سليمة',                        'type': 'سليم',     'en': 'Healthy'},
    'Tomato___Bacterial_spot':        {'ar': 'التبقع البكتيري للطماطم',             'type': 'بكتيري',   'en': 'Bacterial Spot (Tomato)'},
    'Tomato___Early_blight':          {'ar': 'اللفحة المبكرة للطماطم',              'type': 'فطري',     'en': 'Early Blight (Tomato)'},
    'Tomato___Late_blight':           {'ar': 'اللفحة المتأخرة للطماطم',             'type': 'فطري',     'en': 'Late Blight (Tomato)'},
    'Tomato___Leaf_Mold':             {'ar': 'عفن أوراق الطماطم',                   'type': 'فطري',     'en': 'Leaf Mold (Tomato)'},
    'Tomato___Septoria_leaf_spot':    {'ar': 'تبقع سبتوريا للطماطم',               'type': 'فطري',     'en': 'Septoria Leaf Spot'},
    'Tomato___Spider_mites Two-spotted_spider_mite': {'ar': 'حلم العنكبوت على الطماطم', 'type': 'حشري', 'en': 'Spider Mites'},
    'Tomato___Target_Spot':           {'ar': 'التبقع المستهدف للطماطم',             'type': 'فطري',     'en': 'Target Spot'},
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus': {'ar': 'فيروس تجعد الأوراق الصفراء', 'type': 'فيروسي',   'en': 'Yellow Leaf Curl Virus'},
    'Tomato___Tomato_mosaic_virus':   {'ar': 'فيروس موزاييك الطماطم',              'type': 'فيروسي',   'en': 'Mosaic Virus'},
    'Tomato___healthy':               {'ar': 'طماطم سليمة',                         'type': 'سليم',     'en': 'Healthy'},
    'Potassium_Deficiency':           {'ar': 'نقص البوتاسيوم',                      'type': 'فسيولوجي', 'en': 'Potassium Deficiency'},
    'Manganese_Deficiency':           {'ar': 'نقص المنغنيز',                        'type': 'فسيولوجي', 'en': 'Manganese Deficiency'},
    'Magnesium_Deficiency':           {'ar': 'نقص المغنيسيوم',                      'type': 'فسيولوجي', 'en': 'Magnesium Deficiency'},
    'Black_Scorch':                   {'ar': 'الحرق الأسود',                        'type': 'فطري',     'en': 'Black Scorch'},
    'Leaf_Spots':                     {'ar': 'تبقع الأوراق',                        'type': 'فطري',     'en': 'Leaf Spots'},
    'Fusarium_Wilt':                  {'ar': 'ذبول الفيوزاريوم',                    'type': 'فطري',     'en': 'Fusarium Wilt'},
    'Rachis_Blight':                  {'ar': 'لفحة العرجون',                        'type': 'فطري',     'en': 'Rachis Blight'},
    'Parlatoria_Blanchardi':          {'ar': 'حشرة البارلاتوريا (الدرع الأبيض)',    'type': 'حشري',     'en': 'Parlatoria Blanchardi'},
    'healthy':                        {'ar': 'نبات سليم',                           'type': 'سليم',     'en': 'Healthy'},
    // ── UPDATED: new mint model translations (replaced 'unhealthy') ────────────
    'Dried':    {'ar': 'نعناع مجفف / جاف',      'type': 'فسيولوجي', 'en': 'Dried'},
    'Fresh':    {'ar': 'نعناع طازج وسليم',       'type': 'سليم',     'en': 'Fresh'},
    'Spoiled':  {'ar': 'نعناع فاسد / تالف',      'type': 'فطري',     'en': 'Spoiled'},
    'Sunlight': {'ar': 'حرق شمسي / إجهاد ضوئي', 'type': 'فسيولوجي', 'en': 'Sunlight Stress'},
  };

  // ── Initialisation ───────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _plantNetInterpreter = await _safeLoad('assets/models/plantnet_model.tflite');
      _fruitVegInterpreter = await _safeLoad('assets/models/plantvillage.tflite');
      _mintInterpreter     = await _safeLoad('assets/models/mint_model.tflite');
      _palmInterpreter     = await _safeLoad('assets/models/palm_model.tflite');

      final raw = await rootBundle.loadString('assets/models/plantnet_labels_array.json');
      _plantNetLabels = List<String>.from(jsonDecode(raw) as List);

      debugPrint('✅ TFLite initialized. PlantNet labels: ${_plantNetLabels.length}');
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ TFLite init error: $e');
    }
  }

  Future<Interpreter?> _safeLoad(String asset) async {
    try {
      final interp   = await Interpreter.fromAsset(asset);
      final inShape  = interp.getInputTensor(0).shape;
      final outShape = interp.getOutputTensor(0).shape;
      debugPrint('✅ Loaded $asset | input: $inShape | output: $outShape');
      return interp;
    } catch (e) {
      debugPrint('❌ Failed to load $asset: $e');
      return null;
    }
  }

  // ── Plant identification (PlantNet) ──────────────────────────────────────────
  Future<Map<String, dynamic>> identifyPlant(Uint8List imageBytes) async {
    await initialize();
    if (_plantNetInterpreter == null || _plantNetLabels.isEmpty) {
      debugPrint('⚠️ PlantNet not available');
      return {'plantName': 'نبات', 'confidence': 60.0};
    }
    try {
      final input      = _preprocessImageNet(imageBytes, 224, 224);
      final outputSize = _plantNetInterpreter!.getOutputTensor(0).shape[1];
      final output     = [List<double>.filled(outputSize, 0.0)];
      _plantNetInterpreter!.run(input, output);

      final scores    = List<double>.from(output[0]);
      final softmaxed = _softmax(scores);
      final topIndex  = _argmax(softmaxed);
      final confidence = softmaxed[topIndex] * 100;
      final plantName  = topIndex < _plantNetLabels.length
          ? _plantNetLabels[topIndex]
          : 'نبات';

      debugPrint('🌿 PlantNet → [$topIndex] $plantName (${confidence.toStringAsFixed(1)}%)');
      return {
        'plantName':  plantName,
        'confidence': confidence.clamp(0.0, 100.0),
      };
    } catch (e) {
      debugPrint('❌ identifyPlant error: $e');
      return {'plantName': 'نبات', 'confidence': 60.0};
    }
  }

  // ── Disease diagnosis ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> diagnosePlant(
      Uint8List imageBytes,
      PlantType plantType,
      ) async {
    await initialize();

    Interpreter? interpreter;
    List<String> labels;

    switch (plantType) {
      case PlantType.vegetablesFruits:
        interpreter = _fruitVegInterpreter;
        labels      = fruitVegLabels;
        break;
      case PlantType.mint:
        interpreter = _mintInterpreter;
        labels      = mintLabels;
        break;
      case PlantType.palm:
        interpreter = _palmInterpreter;
        labels      = palmLabels;
        break;
    }

    if (interpreter == null) {
      debugPrint('⚠️ Disease model not available for $plantType');
      return _failedDisease();
    }

    try {
      final inputShape = interpreter.getInputTensor(0).shape;
      debugPrint('📐 Model input shape: $inputShape');

      // ── Smart preprocessing based on input shape ──────────────────────────
      // [1, N] → flat grayscale (e.g. mint_model with 784 = 28x28)
      // [1, H, W, 3] → image tensor
      late dynamic input;
      if (inputShape.length == 2) {
        final flatSize = inputShape[1];
        final side     = math.sqrt(flatSize).round();
        debugPrint('📐 Flat input detected: ${side}x$side grayscale');
        input = _preprocessFlat(imageBytes, side);
      } else {
        final inputH = inputShape[1];
        final inputW = inputShape[2];
        if (plantType == PlantType.vegetablesFruits) {
          input = _preprocessRaw(imageBytes, inputW, inputH);
        } else {
          input = _preprocessSimple(imageBytes, inputW, inputH);
        }
      }

      final outputShape = interpreter.getOutputTensor(0).shape;
      final outputSize  = outputShape[1];
      debugPrint('📐 Model output shape: $outputShape | classes: $outputSize');

      final output = [List<double>.filled(outputSize, 0.0)];
      interpreter.run(input, output);

      final scores = List<double>.from(output[0]);
      final maxRaw = scores.reduce((a, b) => a > b ? a : b);
      final minRaw = scores.reduce((a, b) => a < b ? a : b);
      debugPrint('📊 Raw scores — max: $maxRaw | min: $minRaw');

      final softmaxed = _softmax(scores);

      final indexed = softmaxed.asMap().entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (int i = 0; i < 3 && i < indexed.length; i++) {
        final idx = indexed[i].key;
        final lbl = idx < labels.length ? labels[idx] : 'idx_$idx';
        debugPrint('  Top${i + 1}: [$idx] $lbl (${(indexed[i].value * 100).toStringAsFixed(1)}%)');
      }

      // Skip Background_without_leaves — pick the next best prediction
      const backgroundLabel = 'Background_without_leaves';
      MapEntry<int, double> chosen = indexed[0];
      for (final entry in indexed) {
        final lbl = entry.key < labels.length ? labels[entry.key] : '';
        if (lbl != backgroundLabel) {
          chosen = entry;
          break;
        }
      }

      final topIndex   = chosen.key;
      final confidence = chosen.value * 100;
      final label      = topIndex < labels.length ? labels[topIndex] : 'unknown';

      if (label != (indexed[0].key < labels.length ? labels[indexed[0].key] : '')) {
        debugPrint('⏭️ Skipped Background_without_leaves → using: $label');
      }

      final translation = diseaseTranslations[label];

      // ── UPDATED: isHealthy logic covers new mint classes ──────────────────
      final isHealthy = label == 'Fresh' ||
          (label.contains('healthy') && !label.contains('Background'));

      debugPrint('🔬 Disease → [$topIndex] $label (${confidence.toStringAsFixed(1)}%)');

      return {
        'label':       label,
        'labelAr':     translation?['ar']   ?? label,
        'diseaseType': translation?['type'] ?? 'غير محدد',
        'confidence':  confidence.clamp(0.0, 100.0),
        'isHealthy':   isHealthy,
        'labelEn':     translation?['en']   ?? label,
      };
    } catch (e) {
      debugPrint('❌ diagnosePlant error: $e');
      return _failedDisease();
    }
  }

  Map<String, dynamic> _failedDisease() => {
    'label':       'unknown',
    'labelAr':     'تعذّر التشخيص',
    'diseaseType': 'غير محدد',
    'confidence':  0.0,
    'isHealthy':   false,
    'labelEn':     'Unknown',
  };

  // ── Preprocessing ────────────────────────────────────────────────────────────

  /// ImageNet normalisation — for PlantNet
  List<List<List<List<double>>>> _preprocessImageNet(
      Uint8List bytes, int w, int h) {
    final image   = img.decodeImage(bytes)!;
    final resized = img.copyResize(image, width: w, height: h);
    const meanR = 0.485; const stdR = 0.229;
    const meanG = 0.456; const stdG = 0.224;
    const meanB = 0.406; const stdB = 0.225;
    return List.generate(1, (_) =>
        List.generate(h, (y) =>
            List.generate(w, (x) {
              final p = resized.getPixel(x, y);
              return [
                (p.r / 255.0 - meanR) / stdR,
                (p.g / 255.0 - meanG) / stdG,
                (p.b / 255.0 - meanB) / stdB,
              ];
            })));
  }

  /// Raw 0-255 — for plantvillage.tflite which has built-in Rescaling(1./255)
  List<List<List<List<double>>>> _preprocessRaw(
      Uint8List bytes, int w, int h) {
    final image   = img.decodeImage(bytes)!;
    final resized = img.copyResize(image, width: w, height: h);
    return List.generate(1, (_) =>
        List.generate(h, (y) =>
            List.generate(w, (x) {
              final p = resized.getPixel(x, y);
              return [p.r.toDouble(), p.g.toDouble(), p.b.toDouble()];
            })));
  }

  /// /255 normalisation — for palm model
  List<List<List<List<double>>>> _preprocessSimple(
      Uint8List bytes, int w, int h) {
    final image   = img.decodeImage(bytes)!;
    final resized = img.copyResize(image, width: w, height: h);
    return List.generate(1, (_) =>
        List.generate(h, (y) =>
            List.generate(w, (x) {
              final p = resized.getPixel(x, y);
              return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
            })));
  }

  /// Flat grayscale — for models with input shape [1, N] e.g. [1, 784]
  List<List<double>> _preprocessFlat(Uint8List bytes, int side) {
    final image   = img.decodeImage(bytes)!;
    final resized = img.copyResize(image, width: side, height: side);
    final flat    = <double>[];
    for (int y = 0; y < side; y++) {
      for (int x = 0; x < side; x++) {
        final p    = resized.getPixel(x, y);
        final gray = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) / 255.0;
        flat.add(gray);
      }
    }
    return [flat];
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  List<double> _softmax(List<double> scores) {
    if (scores.isEmpty) return [];
    final maxVal = scores.reduce(math.max);
    final exps   = scores.map((s) => math.exp(s - maxVal)).toList();
    final sum    = exps.reduce((a, b) => a + b);
    return sum == 0 ? exps : exps.map((e) => e / sum).toList();
  }

  int _argmax(List<double> list) {
    if (list.isEmpty) return 0;
    int maxIdx = 0;
    for (int i = 1; i < list.length; i++) {
      if (list[i] > list[maxIdx]) maxIdx = i;
    }
    return maxIdx;
  }

  void dispose() {
    _plantNetInterpreter?.close();
    _fruitVegInterpreter?.close();
    _mintInterpreter?.close();
    _palmInterpreter?.close();
  }
}