import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ImageUploadService {
  static const String apiKey = "dc385fc16a12821bcedffb37965ec875";

  static Future<String?> uploadImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse("https://api.imgbb.com/1/upload?key=$apiKey"),
        body: {
          "image": base64Image,
        },
      );

      final data = jsonDecode(response.body);

      if (data["success"] == true) {
        return data["data"]["url"]; // رابط الصورة
      } else {
        return null;
      }
    } catch (e) {
      print("Upload error: $e");
      return null;
    }
  }
}