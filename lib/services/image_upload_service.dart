import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ImageUploadService {
  // 💡 استبدلي هذه القيم ببيانات حسابك في Cloudinary
  static const String cloudName = "dicojx5rg";
  static const String uploadPreset = "bioshield_preset";

  static Future<String?> uploadImage(File imageFile) async {
    try {
      final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

      // إنشاء طلب الرفع
      var request = http.MultipartRequest("POST", url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonResponse = jsonDecode(responseString);

      if (response.statusCode == 200) {
        return jsonResponse["secure_url"]; // رابط الصورة المشفر (HTTPS)
      } else {
        print("Cloudinary Error: ${jsonResponse["error"]["message"]}");
        return null;
      }
    } catch (e) {
      print("Upload execution error: $e");
      return null;
    }
  }
}