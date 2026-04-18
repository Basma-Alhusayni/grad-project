import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class OpenAIService {
  static const String _apiKey = '';
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _model   = 'gpt-4o-mini';
  static const Duration _timeout = Duration(seconds: 20);

  static OpenAIService? _instance;
  static OpenAIService get instance => _instance ??= OpenAIService._();
  OpenAIService._();

  // ── Plant identification + category routing ──────────────────────────────────
  Future<Map<String, dynamic>> identifyPlantWithCategory(Uint8List imageBytes) async {
    const prompt =
        'Look at this plant image carefully. '
        'Return ONLY a JSON object, no markdown. '
        'Keys: '
        '"plantName": scientific name in English, '
        '"plantNameAr": common name in Arabic, '
        '"confidence": your certainty 0-100, '
        '"category": exactly one of these four strings — '
        '"palm" if this is a date palm or any palm tree leaf/frond, '
        '"mint" if this is mint or spearmint or peppermint, '
        '"vegetables" if this is any vegetable, fruit, or crop plant (tomato, potato, grape, corn, pepper, strawberry, apple, etc.), '
        '"other" if this is any other plant (flower, tree, cactus, grass, ornamental, etc.) OR if no plant is visible at all. '
        'Be strict — only use "vegetables" for actual vegetables, fruits, and crops. '
        'Do not default to "vegetables" for unknown plants — use "other" instead.';

    try {
      final compressed = _compressImage(imageBytes);
      final b64        = base64Encode(compressed);

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model, 'max_tokens': 150, 'temperature': 0,
          'messages': [
            {'role': 'user', 'content': [
              {'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$b64', 'detail': 'low'}},
              {'type': 'text', 'text': prompt},
            ]},
          ],
        }),
      ).timeout(_timeout, onTimeout: () => _timeoutResponse());

      debugPrint('📡 OpenAI identifyPlantWithCategory → ${response.statusCode}');

      if (response.statusCode == 200) {
        final parsed = _extractJson(response.body);
        if (parsed != null) {
          final category = parsed['category']?.toString().toLowerCase().trim() ?? 'other';
          debugPrint('🗂️  OpenAI category: $category');
          return {
            'plantName':   parsed['plantName']?.toString()   ?? 'Plant',
            'plantNameAr': parsed['plantNameAr']?.toString() ?? 'نبات',
            'confidence':  _toDouble(parsed['confidence'], 70.0).toStringAsFixed(0),
            'category':    category,
          };
        }
      }
    } on TimeoutException {
      rethrow;
    } catch (e) {
      debugPrint('❌ identifyPlantWithCategory: $e');
    }

    return {
      'plantName':   'Plant',
      'plantNameAr': 'نبات',
      'confidence':  '0',
      'category':    'other',
    };
  }

  // ── Full vision diagnosis ────────────────────────────────────────────────────
  Future<Map<String, String>> diagnoseFromImage(Uint8List imageBytes) async {
    const prompt =
        'You are an expert plant pathologist. Carefully examine this plant image and provide a comprehensive diagnosis. '
        'Return ONLY a JSON object, no markdown, no extra text. '
        'CRITICAL RULE: If you see ANY signs of disease, rot, mold, spots, wilting, discoloration, or damage — set h=false. Only set h=true if the plant is 100% healthy. '
        'JSON keys: '
        'n = scientific plant name in English, '
        'a = common plant name in Arabic, '
        'h = true or false (health status), '
        'dn = disease/condition name in English, 2-4 words max (e.g. "Botrytis Gray Mold", "Powdery Mildew", "Healthy"), '
        'd = diagnosis in Arabic: 2-3 sentences describing what you see and what disease or condition is present, '
        't = disease type in Arabic (سليم / فطري / بكتيري / فيروسي / حشري / فسيولوجي), '
        'i = detailed Arabic information: explain the disease causes, how it spreads, affected parts, and impact on the plant (4-5 sentences), '
        'r = Arabic treatment plan: numbered list of 4-6 specific actionable steps including chemical and organic options, '
        'p = Arabic prevention: 3-4 specific prevention measures for the future, '
        'c = your confidence percentage 0-100.';

    try {
      final compressed = _compressImage(imageBytes);
      final b64        = base64Encode(compressed);
      debugPrint('📸 ${compressed.length ~/ 1024}KB → OpenAI');

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model':       _model,
          'max_tokens':  900,
          'temperature': 0,
          'messages': [
            {'role': 'user', 'content': [
              {'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$b64', 'detail': 'low'}},
              {'type': 'text', 'text': prompt},
            ]},
          ],
        }),
      ).timeout(_timeout, onTimeout: () => _timeoutResponse());

      debugPrint('📡 OpenAI diagnose → ${response.statusCode}');

      if (response.statusCode == 200) {
        final parsed = _extractJson(response.body);
        if (parsed != null) {
          final isHealthy  = parsed['h'] == true;
          final confidence = _toDouble(parsed['c'], 75.0);
          debugPrint('✅ ${parsed['a']} | healthy=$isHealthy | conf=$confidence');
          return {
            'plantName':   parsed['n']?.toString()  ?? 'Plant',
            'plantNameAr': parsed['a']?.toString()  ?? 'نبات',
            'isHealthy':   isHealthy.toString(),
            'diseaseName': parsed['dn']?.toString() ?? '',
            'diagnosis':   parsed['d']?.toString()  ?? 'غير محدد',
            'diseaseType': parsed['t']?.toString()  ?? 'غير محدد',
            'details':     parsed['i']?.toString()  ?? '',
            'treatment':   parsed['r']?.toString()  ?? '',
            'prevention':  parsed['p']?.toString()  ?? '',
            'confidence':  confidence.toStringAsFixed(0),
          };
        }
      } else if (response.statusCode == 408) {
        throw TimeoutException();
      } else {
        debugPrint('❌ ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException {
      rethrow;
    } catch (e) {
      debugPrint('❌ diagnoseFromImage: $e');
    }
    return _visionFallback();
  }

  // ── Text enrichment ──────────────────────────────────────────────────────────
  Future<Map<String, String>> getPlantDiagnosisDetails({
    required String plantName,
    required String diseaseName,
    required String diseaseType,
    required bool isHealthy,
    required String plantTypeAr,
  }) async {
    final prompt = isHealthy
        ? 'You are a plant expert. Provide comprehensive Arabic care information for: '
        'Plant: $plantName, Category: $plantTypeAr, Status: Healthy. '
        'Return JSON only, no square brackets [] in values: '
        '{d: "2-3 Arabic sentences describing the healthy plant", '
        'i: "4-5 Arabic sentences about growing conditions and care", '
        'r: "Numbered Arabic care tips 1. 2. 3.", '
        'p: "Numbered Arabic prevention measures 1. 2. 3."}.'
        : 'You are a plant pathologist. Provide a comprehensive Arabic diagnosis for: '
        'Plant: $plantName, Disease: $diseaseName, Type: $diseaseType. '
        'Return JSON only, no square brackets [] in values: '
        '{d: "2-3 Arabic sentences describing the disease symptoms", '
        'i: "4-5 Arabic sentences explaining cause, spread, and impact", '
        'r: "Numbered Arabic treatment steps 1. 2. 3. with specific product names", '
        'p: "Numbered Arabic prevention measures 1. 2. 3."}.';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model':       _model,
          'max_tokens':  800,
          'temperature': 0,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      ).timeout(_timeout, onTimeout: () => _timeoutResponse());

      debugPrint('📡 OpenAI text → ${response.statusCode}');

      if (response.statusCode == 200) {
        final parsed = _extractJson(response.body);
        if (parsed != null) {
          return {
            'diagnosis':  parsed['d']?.toString() ?? '',
            'details':    parsed['i']?.toString() ?? '',
            'treatment':  parsed['r']?.toString() ?? '',
            'prevention': parsed['p']?.toString() ?? '',
          };
        }
      } else if (response.statusCode == 408) {
        throw TimeoutException();
      }
    } on TimeoutException {
      rethrow;
    } catch (e) {
      debugPrint('❌ getPlantDiagnosisDetails: $e');
    }
    return _textFallback(isHealthy, diseaseName);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  http.Response _timeoutResponse() {
    debugPrint('⏰ Request timed out after ${_timeout.inSeconds}s');
    return http.Response('{"timeout":true}', 408);
  }

  Uint8List _compressImage(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      img.Image resized = decoded;
      if (decoded.width > 256 || decoded.height > 256) {
        resized = img.copyResize(
          decoded,
          width:  decoded.width > decoded.height ? 256 : -1,
          height: decoded.height >= decoded.width ? 256 : -1,
        );
      }
      return Uint8List.fromList(img.encodeJpg(resized, quality: 70));
    } catch (e) {
      return bytes;
    }
  }

  Map<String, dynamic>? _extractJson(String responseBody) {
    try {
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      var text   = (data['choices']?[0]?['message']?['content']
      as String? ?? '').trim();
      text = text
          .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final start = text.indexOf('{');
      final end   = text.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) return null;
      return jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ _extractJson: $e');
      return null;
    }
  }

  double _toDouble(dynamic val, double fallback) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? fallback;
  }

  Map<String, String> _visionFallback() => {
    'plantName': 'Plant', 'plantNameAr': 'نبات', 'isHealthy': 'false',
    'diagnosis': 'تعذّر الاتصال', 'diseaseType': 'غير محدد',
    'details': '', 'treatment': 'تواصل مع خبير زراعي.',
    'prevention': '', 'confidence': '0',
  };

  Map<String, String> _textFallback(bool isHealthy, String diseaseName) => {
    'diagnosis':  isHealthy ? 'النبات سليم' : 'مصاب بـ $diseaseName',
    'details':    '',
    'treatment':  isHealthy
        ? '• سقي منتظم\n• تسميد دوري\n• تشذيب الأوراق الميتة'
        : '• عزل النبات المصاب\n• إزالة الأجزاء المصابة\n• رش مبيد مناسب',
    'prevention': '• المراقبة الدورية\n• الحفاظ على نظافة البيئة',
  };
}

class TimeoutException implements Exception {}